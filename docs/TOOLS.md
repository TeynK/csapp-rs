# 명령어와 디버깅

매일 쓰는 cargo 명령과 디버깅 방법을 모았다. 명령은 저장소 루트에서 실행한다. 예시의 패키지 이름(`wc-lite`)은 그날 패키지로 바꾼다.

## 한눈에 보기

| 할 일 | 명령 |
|---|---|
| 빌드 | `cargo build -q -p wc-lite` |
| 실행 | `cargo run -q -p wc-lite -- -l a.txt` (`--` 뒤가 프로그램 인자) |
| 테스트 | `cargo test -p wc-lite` |
| 완료 기준 | `./days/d00-wc-lite/check.sh` |
| 커밋 전 점검 | `cargo fmt` → `cargo clippy -q --workspace` (경고 0) |
| 오류 코드 설명 | `rustc --explain E0507` |
| 측정 | `cargo build -q --release -p wc-lite` 후 `target/release/wc-lite` |

---

## 1. cargo 명령

### 빌드와 실행
```sh
cargo build -q -p wc-lite            # debug 빌드 → target/debug/wc-lite
cargo build -q --release -p wc-lite  # release 빌드 → target/release/wc-lite (측정은 항상 이쪽)
cargo run -q -p wc-lite -- -l a.txt  # 빌드 후 실행. -- 뒤는 프로그램에 넘어가는 인자
cargo check -p wc-lite               # 컴파일 오류만 확인 (실행 파일을 안 만들어 빠름)
```
- `-p 이름`: 워크스페이스에서 그 패키지만. 빼면 `days/*` 전부를 빌드한다.
- `-q`: cargo의 진행 메시지를 숨긴다. 컴파일 오류와 경고는 그대로 나온다.
- 같은 바이너리를 여러 번 돌릴 때는 빌드를 한 번 하고 `X=target/debug/wc-lite`로 직접 부르는 게 빠르다.

### 테스트
```sh
cargo test -p wc-lite                     # 전부
cargo test -p wc-lite add_assign          # 이름에 add_assign이 든 테스트만
cargo test -p wc-lite counts::            # counts 모듈의 테스트만
cargo test -p wc-lite -- --nocapture      # 테스트 안의 println!/dbg! 출력도 보기
```
- `--` 앞은 cargo의 옵션, 뒤는 테스트 실행기의 옵션이다.
- 통과한 테스트의 출력은 기본으로 숨겨진다. 보려면 `--nocapture`를 쓴다.

### 커밋 전 점검 (RULES.md)
```sh
cargo fmt                                 # 저장소 전체 서식 맞추기
cargo fmt --check                         # 고치지 않고 다른 곳만 보기
cargo clippy -q --workspace               # 린트. 경고 0이 기준
cargo clippy -q -p wc-lite                # 그날 패키지만
```

### 문서와 오류 설명
```sh
rustc --explain E0308                     # 오류 코드의 설명과 예시
cargo doc --open -p wc-lite               # 내 코드의 문서(/// 주석)를 브라우저로
rustup doc --std                          # std 문서를 오프라인으로
```
std 함수가 정확히 무엇을 하는지(예: `u8::is_ascii_whitespace`가 어떤 바이트를 공백으로 보는지)는 추측하지 말고 문서에서 확인한다.

---

## 2. 디버깅

권하는 순서: check.sh FAIL 읽기 → 그 인자로 재현 → 의심 함수에 `dbg!`나 단위 테스트 → 그래도 모르면 디버거.

### 2-1. check.sh의 FAIL 읽기
형식 예(실제 값은 그때그때 다르다):
```
FAIL hello nofile
       stdout 기대=' 1  2 13 hello| 1  2 13 total|' 실제='1 2 13 hello|'
```
- 줄 바꿈은 `|`로 보인다.
- stdout, stderr, 종료 코드 가운데 다른 쪽만 나온다.
- 이름 줄(`hello nofile`)이 곧 재현할 인자다.

### 2-2. 진짜 도구와 바로 비교
```sh
X=target/debug/wc-lite
diff <(LC_ALL=C wc -l a.txt b.txt) <($X -l a.txt b.txt)   # 다른 줄만
$X a.txt b.txt | cat -A                                   # 공백·탭(^I)·줄 끝($)을 보이게
$X a.txt b.txt | sed 's/ /·/g'                            # 공백 개수 세기
$X nofile; echo "exit=$?"                                 # 종료 코드
$X nofile 2>/dev/null                                     # stdout만
$X nofile 2>&1 >/dev/null                                 # stderr만
```

### 2-3. `dbg!`
```rust
let w = dbg!(calculate_width(&paths, n));   // 값을 찍고 그 값을 돌려준다
dbg!(&opts, line_flag);                     // 여러 개를 한 번에
```
- 출력: `[src/main.rs:120:13] calculate_width(&paths, n) = 2` (파일:줄, 식, 값)
- 표준 에러로 나간다. **확인이 끝나면 지운다.** 남겨 두면 check.sh의 stderr 비교가 전부 FAIL이 된다.
- 계속 쓸 값은 `&`를 붙여 넣는다. 그대로 넣으면 move된다.
- 구조체를 찍으려면 `#[derive(Debug)]`가 필요하다. `{:#?}`는 여러 줄로 보기 좋게 찍는다.
- 남은 `dbg!` 찾기: `cargo clippy -q -p wc-lite -- -W clippy::dbg_macro`

### 2-4. 단위 테스트로 좁히기
의심 가는 함수 하나에 입력 하나를 넣는 테스트를 쓴다. 프로그램 전체를 돌리는 것보다 원인이 빨리 좁혀지고, 고친 뒤에도 남는다(PRINCIPLES 6-1).
```rust
#[test]
fn trailing_word_without_newline() {
    let c = Counts::from_bytes(b"one two");
    assert_eq!((c.lines, c.words, c.bytes), (0, 2, 7));
}
```
구조체를 `assert_eq!`로 통째로 비교하려면 `#[derive(Debug, PartialEq)]`가 필요하다.

### 2-5. 디버거
**VS Code (CodeLLDB, 설치되어 있음)**
1. 줄 번호 왼쪽을 클릭해 중단점을 둔다.
2. rust-analyzer가 `fn main`과 `#[test]` 위에 띄우는 `Debug`를 누른다.
3. F10 다음 줄, F11 함수 안으로, F5 계속. 왼쪽 변수 창에서 `Vec`·`Option`을 펼쳐 본다.
4. 인자를 주려면 `.vscode/launch.json`의 `"args": ["-l", "a.txt"]`에 넣는다.

**터미널 (rust-gdb)**
`rust-gdb`는 있지만 `gdb` 본체가 없다. 처음 한 번 `sudo apt install gdb`를 한다.
```sh
cargo build -q -p wc-lite
rust-gdb --args target/debug/wc-lite -l a.txt b.txt
(gdb) break main.rs:120      # 중단점
(gdb) run
(gdb) p width                # 변수 보기
(gdb) next / step / finish   # 다음 줄 / 함수 안으로 / 함수 끝까지
(gdb) bt                     # 호출 스택
```
3장에서 쓰던 gdb 그대로다. `rust-gdb`는 `Vec`·`String`을 읽기 좋게 보여 주는 설정만 얹은 것이다. 디버거는 debug 빌드로 쓴다. release는 최적화로 변수가 사라져 보인다.

### 2-6. 증상별 도구
| 증상 | 도구 |
|---|---|
| 패닉 | `RUST_BACKTRACE=1 $X …`로 호출 경로 보기 |
| 컴파일 오류 | 첫 `error[E….]`부터 읽기. 위치보다 앞줄이 원인일 때가 많다. `rustc --explain` |
| 경고 속에 숨은 실수 | `cargo clippy -q -p 패키지` |
| 출력이 사라짐, 종료 코드가 이상함 | `$X … > /dev/full; echo $?` (쓰기 실패), `echo $?` |
| 시스템 콜이 궁금함 | `strace -e trace=openat,read,write,statx $X …` |
| 시스템 콜 횟수 | `strace -c $X … > /dev/null` |

잡은 버그는 `BUGS.md`에 한 줄 남긴다: `날짜 · Dn · 증상 → 원인 → 교훈`

---

## 3. 측정 (5장 복습, PRINCIPLES 5-3)
```sh
cargo build -q --release -p wc-lite
time target/release/wc-lite big.bin                     # 전체 시간
/usr/bin/time -v target/release/wc-lite big.bin         # 최대 메모리: "Maximum resident set size"
strace -c -e trace=read,write target/release/wc-lite big.bin > /dev/null
```
- 측정은 항상 `--release`로 한다.
- 잰 날은 기록에 환경을 적는다: `lscpu | grep 'Model name'`, `uname -r`
- 1MB가 넘는 테스트 파일은 `scratch/`에 둔다(커밋 안 됨). 희소 파일: `truncate -s 100M scratch/big.bin`

---

## 4. 이 머신의 도구 상태

2026-10-18 확인. CURRICULUM.md "도구"에 있는데 아직 없는 것은 그날이 오기 전에 설치한다.

| 도구 | 상태 | 쓰는 날 |
|---|---|---|
| rustfmt, clippy, rust-src | 있음 | 매일 |
| CodeLLDB, rust-analyzer (VS Code) | 있음 | 매일 |
| rust-gdb, rust-lldb | 있음 (`gdb` 본체 없음) | 필요할 때 |
| strace, perf, readelf, objdump, nm | 있음 | 2주차~ |
| nightly 툴체인 (Miri, ASan) | 없음: `rustup toolchain install nightly --component miri` | 6주차 |
| cargo-show-asm (`cargo asm`) | 없음: `cargo install cargo-show-asm` | D7~ |
| gdb | 없음: `sudo apt install gdb` | 필요할 때 |
| valgrind (lackey) | 없음: `sudo apt install valgrind` | D3 |
| ltrace | 없음: `sudo apt install ltrace` | 2주차 |
| hyperfine | 없음: `sudo apt install hyperfine` | 측정하는 날 |
