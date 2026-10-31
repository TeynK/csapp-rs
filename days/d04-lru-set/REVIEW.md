# D4 리뷰

## 2026-10-31 · 1차 (커밋 전, 작업 트리)

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | ○ | check.sh OK 60 · FAIL 0(2.27초), `cargo test` 3개 통과. 추가 입력 `-E 3 1 2 3 1 4 1`(4가 2를 쫓아내고 1은 hit)도 맞음 |
| 견고성 | ○ | 추가 입력(`-E 2 -E`, `-E ' 2' 1`, `-E 0 5`, 닫힌 파이프 `| head -n 1`)에서 패닉 없음, 종료 코드 1과 맥락 있는 메시지 |
| 구조 | ○ | 명세대로 lib(`pub mod set;`) + bin. `run`이 `Result<(), CliError>`(D3 리뷰 2-2 반영), 인자를 모두 검사한 뒤 시뮬레이션. `dump`가 접근과 출력을 함께 함 |
| 성능 | △ | 접근마다 O(E)(`position` 두 번 + `remove(0)`). release에서 태그 10만 개가 E = 8은 0.07초, 1024는 0.18초, 65536은 7.7초. 태그마다 `ok_or`가 오류 문자열을 미리 만든다(5-1, D2 퀴즈와 같은 것) |
| 이름 | △ | `lru_list`·`victim`은 좋음. 줄 하나를 `idx`로 부름, `InvalidLine`(줄 수가 아니라 줄로 읽힘), `evic_count`, 출력만 하지 않는 `dump` |
| 관용구 | ○ | `as_deref() != Some(OsStr::new("-E"))`, `let-else`, `to_str → and_then → filter → ok_or_else` 사슬, `collect::<Result<Vec<_>, _>>()`, `Option<u64>`로 valid와 tag를 하나로. 작은 것: `position(..).is_some()`, `&Vec<u64>`, `*tag`, `assert_eq!(…, true)`, `};`, `core::fmt`와 `std::fmt` 혼용(D3에 이어 두 번째) |
| 규칙 준수 | △ | 워크스페이스 clippy 0(wc-lite도 고침, D1 뒤 처음), fmt 통과. 단, 공개 항목에 `///` 문서 주석이 없음(명세), D4·D3·wc-lite 모두 아직 커밋 전, 기록의 결과·배운 것·숫자 세 개가 비어 있음 |

### 반드시 고칠 것
- 명세 "공개 항목에 `///` 문서 주석": `Outcome`의 variant 주석이 `//`라 문서가 아니고, `CacheSet`·`new`·`access`·`contains`에는 주석이 없다. 확인: `cargo doc -p lru-set --open`. `new`는 `lines`가 0이면 패닉한다는 것도 적는다(pedantic의 `# Panics`)
- 명세 테스트 요구 2·3:
  - 2(`lru_hit`)는 `contains`를 방금 쓴 태그에만 불러서, `contains`가 순서를 바꾸지 않는지 보지 않는다. 가장 오래된 태그에 `contains`를 부른 뒤에도 그 태그가 쫓겨나는지 본다
  - 3(`only_cold_miss`)은 줄 6개에 태그 4개다. 명세는 "서로 다른 태그 E개"(마지막 빈 줄까지 채우는 n = E 경계)

### 원칙
- 5-1: `ok_or(CliError::InvalidTag(a.to_string_lossy().into_owned()))`는 인자가 정상이어도 태그마다 `String`을 만든다. `ok_or_else(|| …)`로(D2 리뷰 퀴즈 ✕와 같은 지연 평가)
- 3-1: `dump`의 `tags: &Vec<u64>` → `&[u64]`
- 4-1: `position(|&idx| …)`의 인자는 번호가 아니라 줄 하나. `dump`는 접근까지 하므로 `simulate` 같은 이름이나, 접근과 출력을 나누기. `InvalidLine` → `InvalidLines`/`BadLineCount`
- 4-2: `evic_count` → `evictions`
- 2-5: `expect("impossible to exist None")`는 왜 실패할 수 없는지를 말하지 않는다. "빈 줄이 없으니 모든 줄이 Some"처럼 불변식을
- 4-3: `use core::fmt`와 `std::fmt::Formatter`를 섞어 씀(D3 리뷰에 이어 두 번째)

### 개념 정정
- 예측 1의 근거 "처음 2번 콜드미스": cold miss는 그 블록을 **처음 참조**한 miss다. 블록 0, 4, 8은 모두 첫 바퀴에 처음 나오므로 cold다. 무언가를 쫓아내더라도 처음 보는 블록이면 cold다(D3 리뷰 퀴즈의 "블록 5"와 같은 오해, 두 번째)
- `Outcome` 주석 "victim은 쫓겨난 줄": victim은 쫓겨난 줄의 **태그**다
- 참고(오해는 아님): `size_of::<Option<u64>>()`는 16이다(이 머신). u64는 모든 비트 패턴이 쓰여서 `None`을 표시할 빈 값이 없어 태그 칸이 따로 붙는다. C로 `bool valid; uint64_t tag;`를 짜도 정렬 때문에 16바이트다. `Option<&u64>`는 8(널 포인터를 `None`으로 씀)

### 예측 확인 (2026-10-31, 학습자 코드 release로 튜터가 실행)
- 예측 1: (8,1) 21, (4,2) 30, (2,4) 3, (1,8) 3 miss → 고른 (나) 맞음. 근거의 "처음 2번 콜드"는 틀림(cold 3)
- 예측 2: 보기를 고르지 못함("감이 안 옴"). 8-way(S = 64) miss 4380(hit 97.45%), 직접 사상(S = 512) miss 7944(95.37%), 1.81배 → (다). 참조 구현의 값과 같음

### 퀴즈
- 3.5 / 6 (○ 2, △ 3, ✕ 1)
  - ○ `ok_or` 할당: 정상 입력에서 태그마다, `ok_or_else`면 0번. 개수는 `seq 0 19999`가 20000개라 20000(답 19999)
  - ○ `-E 3 1 2 3 1 4` 뒤 `[3, 1, 4]`, 그다음 1은 hit이고 `[3, 4, 1]`
  - △ `size_of::<Option<u64>>()` = 16은 맞음. 이유(u64에 남는 비트 패턴이 없어 판별 칸 + 8바이트 정렬)와 `Option<&u64>` = 8(널 = None)은 못 함
  - ✕ BrokenPipe arm: 모름. SIGPIPE(C는 141로 죽음, `yes | head`로 확인)와 Rust의 EPIPE → `ErrorKind::BrokenPipe`, `Err(CliError::Write(e)) if e.kind() == io::ErrorKind::BrokenPipe`, D3의 `Box<dyn Error>`에서는 종류를 못 꺼낸다는 것을 설명함. 같은 arm을 작은 프로그램으로 확인(`| head -n 1`에서 종료 코드 0)
  - △ `contains`에서 `remove`: `&self`라 안 된다는 방향은 맞음, 오류 번호 E0596은 모름
  - △ 완전 연관 3, 1, 3, 5, 7, 1, 9: hit 2는 맞음. "cold 4, evict miss 1"로 답함 → cold 5, capacity 0. 쫓아냈는지가 아니라 처음 보는 블록인지로 가른다. **같은 오해 세 번째**(D3 퀴즈 블록 5, D4 예측 1 근거). D6 3C 전에 다시 묻는다
