# D3 리뷰

## 2026-10-30 · 1차 (커밋 b1292cb)

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | △ | check.sh OK 55 · FAIL 0, `cargo test` 4개 통과, ls·true 트레이스의 `instr`가 lackey의 `guest instrs`와 같음. 단, UTF-8이 아닌 파일 이름을 E1(usage)로 거절함(아래 필수 1) |
| 견고성 | ○ | 추가 입력 9개(UTF-8이 아닌 경로 둘, 빈 인자, 쉼표 없는 줄, 탭 구분, 크기 `00`, NUL 바이트 줄, 2MB짜리 한 줄)에서 패닉 없음, 종료 코드 맞음 |
| 구조 | ○ | `trace::parse_line`(줄의 뜻) / `CliError::Parse`(경로·줄 번호) / `parse_path` / `summarize` / `dump(out)` / `Summary::count`. 다만 `run`·`summarize`가 `Box<dyn Error>`라 `dump`의 쓰기 오류가 `CliError::Write`를 거치지 않음 |
| 성능 | ○ | `BufReader`로 줄씩 읽고 루프 안에서 바로 셈(Vec 없음): `ls` 트레이스 9.3MB에 최대 RSS 2048KB. release 0.083초, debug 0.738초(참조 구현 0.063초, 0.73초). `to_owned()`는 오류 경로에서만. Intel N150, 6.8.0-147-generic |
| 이름 | △ | `summarize`·`dump`·`MissingComma`·`InvalidOperation`은 좋음. `count(other)`(범위도 갱신하고, 인자는 "다른 것"이 아니라 접근), `size_s`, `line_i_is_worked`, `CliError`의 `error` 필드 |
| 관용구 | ○ | `let-else`, `match`로 `&str` → `Op`, 비용에 따라 `ok_or`/`ok_or_else`, `map_err`로 맥락 감싸기, `if let`, 테스트에서 `Result` 통째 비교. clippy 0, fmt 통과. 작은 것: `\'` 이스케이프, `core::fmt`와 `std::fmt` 혼용, `Summary` 손 초기화, `0x100u64` |
| 규칙 준수 | △ | check.sh 통과 뒤 커밋하고 루트 README `완료`를 같이 커밋(D1과 대조됨). 커밋 메시지에 기능 번호 없음, 기록의 `- 예측: - 예측:` 중복, 워크스페이스 clippy 경고 1(`d00-wc-lite/src/counts.rs:22`, D1부터 세 번째 리뷰) |

### 반드시 고칠 것
- UTF-8이 아닌 파일 이름을 받지 못한다. `parse_path`가 `arg.to_str()`이 `None`이면 `_ => Usage`로 보낸다. 재현: `printf ' L 10,1\n' > $'caf\xe9.trace'; target/debug/trace-parse $'caf\xe9.trace'` → `trace-parse: usage: …`, 종료 코드 1. 명세 E1은 인자 없음·경로 둘 이상·`-`로 시작하는 인자뿐이고, `args_os`를 쓰는 이유가 이런 경로다. `-`로 시작하는지는 바이트로 본다(`arg.as_encoded_bytes().starts_with(b"-")`)
- 테스트: 명세는 건너뛸 줄로 "`==` 줄과 빈 줄"을 요구했다. `skipped_line`은 `==` 줄만 본다. 빈 줄(`""`)도 `Ok(None)`인지 넣는다

### 원칙
- 2-2: `run`·`summarize`가 `Box<dyn Error>`를 돌려줘 오류 종류가 사라지고, `dump`의 `io::Error`가 `CliError::Write` 없이 올라간다(D1 리뷰 2-3과 같은 구조, 두 번째). 둘 다 `Result<_, CliError>`로, `dump(…).map_err(CliError::Write)?`
- 4-1: `Summary::count(&mut self, other: Access)`: 개수와 범위를 함께 갱신하니 `record`/`add`, 인자는 `access`
- 4-2: `size_s` → `size_text`처럼 무엇인지 드러나게
- 4-4 (선택): 오류를 감싼 필드는 std 관례(`Error::source`)대로 `source`
- 6-2: 테스트의 데이터 줄이 `"L  2ab,10"`(앞 공백 없음)이라 lackey의 ` L …` 모양을 단위 테스트가 보지 않는다(check.sh는 봄)

### 개념 정정
- 기록 "메모리 접근이 통상 2~3배가량 이루어진다": 방향과 범위가 흐리다. 잰 것은 "명령어(`I`)가 데이터 접근의 2.82배"(ls), 즉 데이터 접근이 명령 2.8개에 한 번꼴(약 35%)이다. `I`도 L1i를 거치는 메모리 접근이라, 명령 하나마다 메모리 접근이 최소 한 번 있고 데이터 접근이 그 위에 약 0.35번 더해진다. `/bin/true`는 3.16배였으니 "통상"이 아니라 이 두 프로그램, 이 컴파일러에서 잰 값이다
- 예측 ①의 근거 "L·S·M은 늘 I와 함께"로 알 수 있는 것은 "instr ≥ 데이터 접근"(1배 이상)까지다. 몇 배인지는 메모리 피연산자를 가진 명령의 비율이 정한다
- 결과의 주소 범위 0x108040~0x1fff000feb는 valgrind 아래의 배치다. valgrind 아래에서 실행 파일은 0x108000, ld.so는 0x4000000에 올라가고(`valgrind --tool=none cat /proc/self/maps`), 그냥 실행하면 PIE는 0x5…, 스택은 0x7ffe… 근처다(같은 머신에서 확인). 관찰 도구가 관찰 대상의 주소를 바꾼다

### 퀴즈
- 2.5 / 5 (○ 1, △ 3, ✕ 1)
  - △ 0x200 간격의 L1d: 세트 8개는 맞음(D2 브리핑·D2 리뷰·D3 브리핑에 이어 처음으로 세트 수를 맞힘). 용량을 못 구함: 세트 하나가 8줄 × 64B = 512B라 8세트 × 512B = 4KiB. D2의 `-S 64`(512바이트 간격)와 같은 답
  - △ `parse_line`이 줄 번호를 받으면: "인자가 는다"는 맞음. 핵심은 줄 번호가 이 함수가 모르는 맥락이라는 것. D7처럼 메모리에서 만든 트레이스나 표준 입력에는 파일 경로가 없고, 테스트마다 가짜 줄 번호를 넣어야 한다. 맥락은 줄을 세는 쪽이 붙인다(2-3)
  - ○ `Option::min`만 쓰면 `None < Some(_)`이라 계속 `None` → `min -` (scratchpad에서 확인)
  - △ 블록 1, 5, 1, 2, 5: 모두 miss는 맞음. 둘째(5)는 conflict가 아니라 cold: 처음 보는 블록이면 무언가를 쫓아내더라도 cold다(개념 문서 6절 ` L 110,1`과 같음). 나머지 넷(cold, conflict, cold, conflict)은 맞음
  - ✕ `I  048dfac0,1` + ` L 1ffefffea8,8`: 1바이트 명령은 `ret`(0xc3). 스택에서 복귀 주소 8바이트를 읽고(L) 그 주소로 뛴다. 다음 I의 `04890b74`는 `call` 바로 다음 명령이다(개념 문서 5절, objdump로 확인)
