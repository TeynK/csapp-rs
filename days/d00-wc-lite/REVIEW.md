# D0-일 리뷰

## 2026-10-18 · 1차

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | ○ | check.sh 동작 검사 65개 전부 통과. 추가 입력(FIFO, `-` 파일, `''`)도 GNU wc와 같음 |
| 견고성 | ○ | 추가 입력에서 패닉 없음. `/dev/full` 수정 후 종료 코드 1 |
| 구조 | △ | 파일 줄과 total 줄의 출력 코드가 그대로 중복. `dump`가 읽기·폭·출력을 다 함 |
| 성능 | ○ | 100MB에서 0.18~0.21초(GNU 0.32~0.35초). 메모리는 파일 크기만큼(99MB, GNU 2MB). `fs::read`는 명세가 허용 |
| 이름 | △ | `pathes`, `count_flag`(실제는 바이트), `flag` 두 곳, `sum`을 자릿수로 재사용, `word_flag` |
| 관용구 | △ | clippy 기본 경고 7개, `&Vec<PathBuf>`·`&PathBuf` 인자, `while let` + `next()` |
| 규칙 준수 | ✕ | counts 테스트 3개가 `Counts`를 검사하지 않음, `Box<dyn Error>` 제약 미준수, clippy 경고 0 아님, 커밋 없음, README 기록 비어 있음 |

측정 환경: Intel(R) N150, 6.8.0-147-generic, `--release`, 10⁸바이트 희소 파일과 텍스트 파일

### 반드시 고칠 것
- 6-2 위반: `counts::tests`의 `sanity`·`test2`·`test3`는 `Counts`를 부르지 않는다. 아침의 `add_assign` 버그(`bytes += rhs.words`)를 다시 넣어도 통과한다. 빈 입력, 마지막 `\n` 없음, 공백 6종(`\v`), 그 밖의 바이트, `+=`를 검사한다. check.sh에 "from_bytes를 3번 이상 부름" 검사를 추가함(지금 FAIL 1)
- 명세 제약: 치명적 오류를 `Box<dyn Error>`로 올리지 않았다. `CliError`에 `Debug`와 `std::error::Error`를 붙이고 `run`이 `Result<bool, Box<dyn Error>>`를 돌려주게 해 보고, 무엇이 달라지는지 README 배운 것에 적는다
- RULES: `cargo clippy -q -p wc-lite` 경고 7개 → 0

### 원칙
- 6-1, 6-2: 테스트가 동작을 검사하지 않음
- 3-1: `&Vec<PathBuf>` → `&[PathBuf]`, `&PathBuf` → `&Path`
- 4-1: `flag`(main의 실패 여부, 폭 계산의 장치 표시), `sum`에 자릿수 대입
- 4-3: `count_flag`/`-c`는 바이트인데 `count`라는 이름. `word_flag` → `in_word`
- 2-3 (선택): 모르는 옵션 메시지가 `-`를 뗀 값을 보인다 (`--lines` → `unknown option: -lines`, `-lwcx` → `unknown option: lwcx`)

### 개념 정정
- 없음. README 기록(예측·결과·배운 것)이 비어 있어 확인하지 못함

### 퀴즈
- 2 / 5 (△ 1)
  - ○ 인덱스에서 move 불가(E0507)와 `&`로 빌리기, F2 바이트 부류(`a\x01 b` → 2단어)
  - △ `fs::metadata`가 권한 없는 파일에 성공하는 이유(결론은 맞음, 이유: 열지 않고 inode를 보며 필요한 건 디렉터리의 x 권한)
  - ✕ `u64::from(usize)`가 없는 이유(플랫폼마다 usize 크기가 달라 손실 없는 변환이 보장되지 않음 → `try_from`/`as`), 파일 루프의 `?`가 run을 끝내 뒤 파일과 total 줄이 사라짐(질문을 오류 종류 문제로 읽음)

## 2026-10-18 · 2차

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | ○ | check.sh OK 68 · FAIL 0 |
| 견고성 | ○ | 1차와 같음 |
| 구조 | △ | 출력 중복은 그대로 (선택 항목) |
| 성능 | ○ | 1차와 같음 |
| 이름 | △ | 1차 지적 그대로, 테스트 이름 `t1`~`t3` |
| 관용구 | △ | clippy 기본 경고 7 → 1 (counts.rs:22 접을 수 있는 `if`) |
| 규칙 준수 | △ | `Box<dyn Error>` 반영, 테스트가 `from_bytes`를 검사함. 공백 6종 테스트 없음, `cargo fmt --check` 실패, 커밋 없음, 기록 일부 |

### 1차 필수 반영
- ○ `Box<dyn Error>`: `#[derive(Debug)]` + `impl Error for CliError {}`, `?`의 자동 변환, 마지막 줄 `Ok(flag)`
- △ 테스트: 빈 입력, 마지막 `\n` 없음, 단어 하나는 검사. 명세의 공백 6종(`\v`)은 없음. `add_assign` 버그와 `is_ascii_whitespace` 버그는 여전히 단위 테스트로 못 잡음
- △ clippy: 7 → 1

### 반드시 고칠 것
- 공백 6종 테스트 (명세 제약)
- clippy 1개, `cargo fmt`
- README 기록, 루트 README 상태, 커밋

### 원칙
- 4-1: 테스트 이름 `t1`~`t3`은 무엇을 검사하는지 말하지 않는다
- 6-2: 공백 6종, `+=` 미검사

### 예측 2 실행 결과 (튜터가 실행)
- `printf 'one\vtwo\n'`: GNU `LC_ALL=C wc -w` 2, wc-lite 2, `is_ascii_whitespace`로 나누면 1 (`b'\x0b'.is_ascii_whitespace()`는 `false`)
