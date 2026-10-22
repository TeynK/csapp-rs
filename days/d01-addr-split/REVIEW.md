# D1 리뷰

## 2026-10-22 · 1차

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | ✕ | 커밋 f3ba377에서 check.sh OK 38 · FAIL 22, `cargo test` 4개 모두 실패. `geometry.rs:28`이 시프트 결과를 버림. 그 전 상태에서는 FAIL 0이었음 |
| 견고성 | ○ | 추가 입력(`-`, `--`, s = b = u32 최댓값, `-m 4294967296`, `0x`, `-m` 값 없음, `/dev/full`, `-\xff`)에서 패닉 없음, 종료 코드 1 |
| 구조 | ○ | `parse_args` / `parse_value<T>` / `parse_address` / `dump` / `format_bits`로 단계 분리. main은 조립만 하고(1-1), 출력은 인자로 받음(1-2) |
| 성능 | ○ | `BufWriter` + 끝에서 `flush`(5-2). 측정은 안 함(필요 없음) |
| 이름 | △ | `set_bits`·`lines_per_set`·`addr_bits`·`format_bits`는 좋음. `ret`, `case`, `Some(bits)`(실제는 2^n), `large_one_bits` |
| 관용구 | △ | clippy 기본 경고 2(`needless_late_init`, `from_str_radix_10`), `(opt)` 같은 괄호, `as u64` 대신 `u64::from`, `run`의 `Result<bool, _>`, `checked_add` 결과 `match`의 두 arm 중복 |
| 규칙 준수 | ✕ | 실패하는 상태로 "complete" 커밋하고 루트 README를 `완료`로 바꿈. clippy 경고 2. D1 커밋에 wc-lite 공백 변경이 섞여 `cargo fmt --check`(워크스페이스) 실패. 기록의 막힌 시간이 숫자가 아님 |

### 반드시 고칠 것
- 틀린 결과: `geometry.rs:28` `addr.checked_shr(slice_bits).unwrap_or_default();`가 계산한 값을 `*addr`에 넣지 않고 버린다. 그래서 set과 tag가 시프트되지 않은 주소에서 나온다. 재현 `cargo test -p addr-split` → `no_set_bits`: left `tag: 171`, right `tag: 10`. clippy 지적을 반영하며 생긴 회귀로 보임
- 회귀 방지: 고친 뒤 check.sh와 `cargo test`를 다시 돌리고 커밋. 루트 README 상태는 그때 `완료`
- RULES: clippy 경고 0, `days/d00-wc-lite/src/main.rs:47` 줄 끝 공백 되돌리기(따로 커밋)

### 원칙
- 6-1, 6-2: 테스트는 있었고 버그를 잡았지만, 커밋 전에 돌리지 않았다. `large_one_bits`는 주소 `0xab`라 63번 비트 경계를 검사하지 못함
- 3-5: `checked_add` 결과 `match`에서 `None`과 `Some(sum) if sum > …`가 같은 오류를 따로 만든다
- 4-1: `ret`, `case`, `Some(bits)`
- 2-3 (선택): `dump`의 쓰기 오류는 `CliError::Write`를 거치지 않아 메시지에 `write error:`가 없다(flush만 거친다)

### 개념 정정
- README 결과 "정답": 예측 1의 bits 줄 `1110001|101|00`은 tag가 7비트다. 명세는 tag를 t = 8비트로 0을 채워 `01110001|101|00`. 값(0x71, 0x5, 0x0)과 예측 2는 맞음

### 퀴즈
- 2 / 5 (○ 1, △ 2, ✕ 2)
  - ○ 폭 0이어도 `0` 한 글자, 폭 변수가 u32면 E0308(`&usize` 기대)
  - △ `"-1".parse::<u64>()`: 오류는 맞음. 종류는 범위 밖이 아니라 `InvalidDigit`(부호 없는 타입에 `-`는 숫자 글자가 아님). C `strtoul`은 오류 없이 부호 없는 산술로 뒤집어 `ULONG_MAX`
  - △ `ok_or`/`map_err`: `map_err`의 클로저는 원래 오류를 인자로 받아 바꾸고, 실패할 때만 실행된다는 점이 빠짐
  - ✕ `Some(_)` arm을 빼면: `None`은 따로 있음. 가드 붙은 arm은 빠짐 검사에서 다룬 것으로 치지 않아 `Some(_)`이 안 다뤄짐(E0004)
  - ✕ 0 → 8 → 0: 0과 8은 둘 다 세트 0(tag 0과 1). E = 1이라 8이 블록 0을 쫓아내 conflict miss. E = 2면 둘 다 들어가 hit
