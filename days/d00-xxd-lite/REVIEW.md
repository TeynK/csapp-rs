# D0 리뷰

## 2026-10-17 · 1차

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | ✕ | 오프셋을 10진수(`{:08}`)로 출력. check.sh FAIL 15 (16바이트 넘는 파일, `-s 12` 등) |
| 견고성 | ○ | 오류 경로에 unwrap 없음, 추가 입력(`-s -l 4`, `--`, 비 UTF-8 경로, 파이프 닫힘)에서 패닉 없음 |
| 구조 | ○ | main → run → parse_args/parse_value/clamp_window/dumps, 입출력은 인자로 (1-1, 1-2) |
| 성능 | ○ | BufWriter + 마지막 flush, 루프 밖 버퍼 재사용 (5-1, 5-2). 측정은 안 함 |
| 이름 | △ | `dumps`는 복수형이 어색. 하는 일은 `dump` (4-4) |
| 관용구 | △ | 필드 이름 중복, `\|e\| CliError::Write(e)` 중복 클로저, 포맷 인자 인라인 안 함 |
| 규칙 준수 | ✕ | clippy 경고 5개, `cargo fmt --check` 실패, `hello.txt` 커밋, 루트 README가 `완료` |

### 반드시 고칠 것
- F2 위반: `dumps`의 오프셋 포맷이 10진수. 재현 `diff <(xxd -s 12 h) <(xxd-lite -s 12 h)` → `0000000c` vs `00000012`

### 원칙
- 6-2: 단위 테스트 없음 (check.sh만). 선택 과제로 parse_args 테스트 권장

### 개념 정정
- README 결과 2: "함수가 종료되면 소유권이 사라짐" → 소유권은 함수에 **넘기는 순간** 이동하고, 그 뒤 원래 변수를 쓰면 E0382

### 퀴즈
- 3 / 6
  - ○ let-else의 diverge, `&'static str`의 이유
  - △ `{:08x}` 대소문자(x는 소문자, X는 대문자), 이동 후 사용이 컴파일 오류(E0382)라는 점
  - ✕ BufWriter drop 시 flush 오류가 버려짐(`/dev/full` → 종료 코드 0), tuple variant가 함수라는 점
