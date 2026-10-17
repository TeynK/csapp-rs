# Rust 문법 노트

`PRINCIPLES.md` 7절(D0 예시)에 나온 문법을 열 묶음으로 정리했다.
묶음마다 "무엇인가 → C로 치면 → 앞으로 왜 자주 쓰나(다시 나오는 Day)" 순서다.
새 Day에서 새 문법을 만나면 여기에 덧붙인다.

## 한눈에 보기

| 묶음 | 문법 | 다시 나오는 곳 |
|---|---|---|
| 1. 데이터 모양 | `struct`, 데이터를 담는 `enum`, `const`, `#[derive]` | D3 `enum Op`, D9 오류 enum, D27 `enum JobState`, D49 상태 머신 |
| 2. 패턴 | `match`, 가드, `_`, 범위, `while let`, `let-else`, 구조 분해, `matches!` | 매일 |
| 3. 오류 도구 | `Result`, `Option`, `?`, `map_err`, `ok_or`, `expect`, `ExitCode` | 내일 wc-lite, D3, D13(`From` 구현), D15 |
| 4. 트레잇 | `impl Display for`, `&self`, `Self`, 인자 자리의 `impl Trait`, 트레잇 가져오기 | D4, D6, D10(`Iterator` 구현), D16(`Read`·`Write` 구현), D33(`Deref`) |
| 5. 클로저 | 이름 없는 함수, 값 캡처, 함수 이름을 값으로 | D10 `filter`·`map`, D50 `move` 클로저, D53 `wait_while` |
| 6. 반복자 | `next`, `skip`, `chunks`, `enumerate`, `map`, `collect` | D3 `lines`·`split`, D4 `position`·`min_by_key`, D10, D17, D44 |
| 7. 슬라이스·문자열·경로 | `&[u8]`, 범위, `b"…"`, `String`, `OsString`, `PathBuf`, `Cow` | D2, D7, D8, D15(`CString`), D16 |
| 8. 수명 표기 | `'static`, `'_`, 생략 규칙 | D9 `Elf<'a>`, D44, D47 `Request<'a>`, D50 `'static` 바운드 |
| 9. 매크로와 포맷 | `write!`, `writeln!`, `assert_eq!`, `debug_assert!`, `{:08x}` | D1 `{:#x}`·`{:b}`, D24 할당 없는 포맷, D39 불변식 검사 |
| 10. 모듈·속성·비트 | `use`, `mod tests`, `#[cfg(test)]`, `//!`·`///`, `>>`·`&`, `T::from` | 내일 `mod` 파일 분리, D1 시프트·마스크, D12 `wrapping_*`, D29 비트 필드 |

---

## 1. 데이터 모양: `struct` · `enum` · `const` · `derive`

### `struct`: 이름 붙은 필드 묶음
```rust
struct Options {
    start: usize,
    limit: usize,
    path: PathBuf,
}

let opts = Options { start, limit, path }; // 변수 이름과 필드 이름이 같으면 줄여 쓴다
let Options { start, limit, path } = opts; // 필드를 각각의 변수로 꺼낸다(분해)
```
- C의 `struct`와 같다. 다른 점은 필드가 기본으로 비공개(다른 모듈에서 못 봄)라는 것, 메서드를 `impl` 블록에 붙인다는 것이다.
- 분해하면 필드가 각 변수로 옮겨 가서, `opts`는 그 뒤로 못 쓴다.
- **자주 쓰는 이유**: 함수 인자가 많아지거나 "상태를 한 덩어리로" 들고 다닐 때마다 쓴다. D4 캐시 줄 `Line`, D6 캐시 구성, D27 잡 테이블.

### `enum`: 종류마다 다른 데이터를 담는다
```rust
enum CliError {
    Usage,                                           // 데이터 없음
    MissingValue(&'static str),                      // 이름 없는 필드 (튜플 모양)
    BadNumber { flag: &'static str, text: String },  // 이름 있는 필드 (구조체 모양)
}
```
- C의 `enum`은 정수 상수일 뿐이다. Rust의 enum은 C의 tagged union(태그 + union)을 언어가 관리해 주는 것에 가깝다. 지금 어떤 variant인지 컴파일러가 알고, `match`가 모든 variant를 다뤘는지 검사한다(빠뜨리면 `error[E0004]: non-exhaustive patterns`).
- `Option`과 `Result`도 표준 라이브러리에 있는 평범한 enum이다: `enum Option<T> { None, Some(T) }`.
- **자주 쓰는 이유**: "여러 경우 중 하나"는 시스템 코드 어디에나 있다. 트레이스 연산 종류(D3 `enum Op`), ELF 파일 종류(D8), 오류 종류(D9), 잡 상태(D27), 연결 상태 머신(D49).

### `const`: 컴파일할 때 정해지는 상수
```rust
const BYTES_PER_LINE: usize = 16;
```
- C의 `#define BYTES_PER_LINE 16`과 비슷하지만 타입이 있다. 매직 넘버에 이름을 붙인다. D5(디스크 모델), D29(const 배열로 표 만들기).

### `#[derive(Debug)]`: 트레잇 구현을 자동으로 만든다
- `{:?}`로 찍을 수 있게 `Debug` 구현을 컴파일러가 만들어 준다.
- `Result<_, CliError>`에 `.unwrap()`을 하려면 오류 타입이 `Debug`여야 한다(없으면 `error[E0277]: CliError doesn't implement Debug`). 테스트에서 필요하다.
- 자주 쓰는 derive: `Debug`, `Clone`, `Copy`, `PartialEq`, `Eq`, `Hash`, `Default`. `assert_eq!`로 비교하려면 `PartialEq`가 있어야 한다.

---

## 2. 패턴 매칭

### `match`: 값의 모양으로 가지치기
```rust
match arg.to_str() {                        // 값의 타입은 Option<&str>
    Some("-s") => { /* … */ }               // 안쪽 값까지 맞춰 본다
    Some(s) if s.starts_with('-') => { /* … */ } // 가드: 패턴 + 조건
    _ if path.is_some() => { /* … */ }      // 나머지 중 조건이 맞는 것
    _ => { /* … */ }                        // 진짜 나머지
}

ascii.push(match b {                        // match는 값을 돌려주는 식이다
    0x20..=0x7e => char::from(b),           // 범위 패턴 (끝 포함)
    _ => '.',
});
```
- C의 `switch`와 다른 점이 넷이다. 정수뿐 아니라 enum·문자열·튜플·중첩된 모양까지 맞출 수 있다. 빠진 경우가 있으면 컴파일 오류다. fallthrough가 없다. 식이라서 값을 돌려준다.
- 위에서부터 처음 맞는 arm 하나만 실행한다. 그래서 구체적인 것을 먼저 쓴다(PRINCIPLES 3-5).

### 참조를 `match`하면 필드도 참조로 묶인다
```rust
fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    match self {                                   // self의 타입은 &CliError
        Self::BadNumber { flag, text } => { /* … */ } // text는 &String (이동도 복사도 없음)
        // …
    }
}
```
- 빌린 값에서는 소유권을 빼 갈 수 없으니, 안쪽 필드도 자동으로 참조가 된다.

### `while let`: 패턴이 맞는 동안 반복
```rust
while let Some(arg) = args.next() {
    // 루프 안에서 args.next()를 한 번 더 불러 옵션 값을 꺼낼 수 있다
}
```
- `for arg in &mut args`로 돌면 루프가 반복자를 빌리고 있어서 안에서 `args.next()`를 부를 수 없다(`error[E0499]`). 다음 원소를 직접 당겨 와야 하면 `while let`이다.
- **자주 쓰는 이유**: 인자 파싱, 스택 비우기(`while let Some(x) = stack.pop()`), 큐 소비자(D53).

### `let-else`: 맞지 않으면 바로 빠져나간다
```rust
let Some(value) = value else {
    return Err(CliError::MissingValue(flag));
};
// 여기부터 value는 Option이 벗겨진 OsString
```
- `else` 블록은 반드시 빠져나가야 한다(`return`, `break`, `continue`, `panic!`). 그러지 않으면 `error[E0308]: else clause of let...else does not diverge`.
- **자주 쓰는 이유**: "없으면 오류"를 들여쓰기 없이 처리한다. 파서(D3, D8, D47)에서 줄마다 나온다.

### 구조 분해: 묶음을 풀어서 이름 붙이기
```rust
let (mut start, mut limit, mut path) = (0, usize::MAX, None); // 튜플
let (start, window) = clamp_window(&data, start, limit);       // 함수가 돌려준 튜플
for (j, &b) in chunk.iter().enumerate() { /* … */ }            // (번호, &u8)에서 u8 꺼내기
```
- `&b`는 "참조를 벗겨서 값을 꺼내라"는 패턴이다. `u8`은 복사가 싸니 값으로 받는 게 편하다.

### `matches!`: 패턴이 맞는지를 bool로
```rust
assert!(matches!(parse_args(args), Err(CliError::MissingValue("-s"))));
```
- `match`를 한 줄짜리 참·거짓 검사로 쓸 때다. 테스트와 `debug_assert!`에서 자주 쓴다.

---

## 3. 오류 도구: `Result` · `Option` · `?`

| 도구 | 뜻 | 예 |
|---|---|---|
| `Option<T>` | 값이 있거나(`Some`) 없거나(`None`). C의 NULL 대신 | `path: Option<PathBuf>` |
| `Result<T, E>` | 성공(`Ok`)이나 실패(`Err`). C의 `-1 + errno` 대신 | `Result<usize, CliError>` |
| `()` | 돌려줄 값이 없음(C의 `void`). `Ok(())`는 "성공, 값 없음" | `fn run() -> Result<(), CliError>` |
| `?` | `Err`면 그 오류를 돌려주며 함수를 끝낸다 | `parse_value("-s", args.next())?` |
| `map_err(f)` | 오류 쪽만 다른 값으로 바꾼다 (맥락 붙이기) | `.map_err(CliError::Write)?` |
| `ok_or(e)` | `Option`을 `Result`로 (`None`이면 `Err(e)`) | `path.ok_or(CliError::Usage)?` |
| `expect("이유")` | 실패하면 패닉. 실패할 수 없는 곳에만 | `write!(hex, …).expect("…")` |
| `io::Result<T>` | `Result<T, io::Error>`의 줄임 이름 | `fn dump(…) -> io::Result<()>` |
| `ExitCode` | `main`이 돌려주는 종료 코드. `SUCCESS`는 0, `FAILURE`는 1 | `fn main() -> ExitCode` |

- `.map_err(CliError::Write)`처럼 튜플 모양 variant의 이름을 함수처럼 넘길 수 있다. "값 하나를 받아 enum을 만드는 함수"이기도 하기 때문이다.
- **자주 쓰는 이유**: 시스템 콜은 모두 실패할 수 있고, Rust에서는 그 실패가 전부 `Result`로 돌아온다. 3주차에 직접 감싸는 libc 호출도 `io::Error::last_os_error()`로 `Result`를 만든다(D15).
- 내일 wc-lite에서는 `Box<dyn Error>`(어떤 오류든 담는 상자)를 써 본다. 종류로 나눠 처리할 일이 없을 때 편하고, 종류를 구분해야 하면 enum이 낫다(PRINCIPLES 2-2).

---

## 4. 트레잇: 타입에 공통 동작 붙이기

### `impl 트레잇 for 타입`
```rust
impl fmt::Display for CliError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: …"),
            // …
        }
    }
}
// 이제 println!("{e}")와 e.to_string()이 된다
```
- 트레잇은 "이 메서드들을 가진 타입"이라는 약속이다. C로 치면 함수 포인터 구조체(vtable)의 모양을 정해 두고 타입마다 그 표를 채우는 것과 비슷하다.
- `&self`는 빌려서 읽기만, `&mut self`는 빌려서 바꾸기, `self`는 가져가기다. C의 `const T *`, `T *`, 값 전달에 해당한다.
- `Self`는 지금 impl하는 타입(여기서는 `CliError`)의 별명이다.
- **자주 쓰는 이유**: std의 기능 대부분이 트레잇으로 열려 있다. `Display`를 붙이면 `{}`로 찍히고, `Iterator`를 붙이면 `for`로 돌고(D10, D17, D44), `Read`·`Write`를 붙이면 `io::copy`나 `BufWriter`와 조합된다(D16). `Drop`을 붙이면 자원 정리가 자동이 된다(D15 `Fd`).

### 인자 자리의 `impl Trait`: "이 트레잇을 가진 아무 타입"
```rust
fn parse_args(args: impl Iterator<Item = OsString>) -> Result<Options, CliError>
fn dump(bytes: &[u8], base: usize, out: &mut impl Write) -> io::Result<()>
```
- `Item = OsString`은 그 반복자가 내놓는 원소의 타입이다(연관 타입).
- 컴파일러가 실제로 쓰인 타입마다 함수를 따로 만든다(단형화). 그래서 함수 포인터를 거치는 비용이 없다. 실행 중에 표를 보고 고르는 방식(`dyn Trait`)은 내일 wc-lite의 `Box<dyn Error>`에서 처음 만난다.
- **자주 쓰는 이유**: 테스트에서 가짜를 넣을 수 있고(PRINCIPLES 1-2), 같은 코드를 파일·소켓·`Vec`에 똑같이 쓸 수 있다. 10장 RIO는 파일이든 소켓이든 같은 코드로 읽는다(D16, D46).

### 트레잇은 가져와야 메서드가 보인다
```rust
use std::fmt::Write as _; // 이름은 안 가져오고 메서드만 쓸 수 있게 한다
write!(hex, "{b:02x}")    // String에 쓰기: fmt::Write
writeln!(out, "…")?       // 바이트 출력에 쓰기: io::Write
```
- 트레잇의 메서드는 그 트레잇이 `use`로 들어와 있어야 부를 수 있다. 빼먹으면 `error[E0599]: cannot write into String`이 난다.
- `io::Write`(바이트를 받는 곳)와 `fmt::Write`(글자를 받는 곳)는 이름이 같다. 둘 다 쓰는 파일에서는 한쪽을 `as _`로 가져온다.

---

## 5. 클로저: 이름 없는 작은 함수
```rust
.map_err(|source| CliError::Read { path, source }) // 인자 하나, 바깥의 path를 가져다 쓴다
.map_err(|_| CliError::BadNumber { flag, text })   // 인자는 버리고(_) 바깥 값만 쓴다
.map(OsString::from)                                // 함수 이름을 클로저 자리에 그대로
```
- `|인자| 몸통` 꼴이다. C에는 없다. 함수 포인터와 "바깥 변수를 담은 구조체"를 한 번에 만든다고 보면 된다.
- 바깥 변수를 캡처한다. 읽기만 하면 빌리고, 값 자체가 필요하면 가져간다(move). 첫 줄은 `path`를 가져가므로, 그 뒤에 `path`를 쓰면 `error[E0382]`가 난다.
- **자주 쓰는 이유**: 반복자(`filter`, `map`, `position`), 오류 변환(`map_err`), 정렬 기준(`sort_by_key`), 스레드(D50 `thread::spawn(move || …)`), 조건 대기(D53 `wait_while`).

---

## 6. 반복자: 원소를 하나씩 내놓는 것

| 메서드 | 하는 일 | 이 코드에서 |
|---|---|---|
| `next()` | 다음 원소 하나 (`Option`) | `args.next()` |
| `skip(n)` | 앞의 n개 건너뛰기 | `args_os().skip(1)`: 프로그램 이름을 건너뜀 |
| `chunks(n)` | 슬라이스를 n개씩 자른 조각 (마지막은 짧을 수 있음) | `bytes.chunks(16)` |
| `enumerate()` | (번호, 원소) 쌍 | `for (i, chunk) in … .enumerate()` |
| `iter()` | 원소를 빌려서 하나씩 | `chunk.iter()` |
| `map(f)` | 원소마다 f를 적용 | `.map(OsString::from)` |
| `collect()` | 모아서 컬렉션으로 | `.collect::<Vec<_>>()` |
| `into_iter()` | 컬렉션을 가져가며 원소를 하나씩 | `vec.into_iter()` |

- **게으르다**: `map` 같은 어댑터는 만들기만 하면 아무 일도 안 한다. `for`, `collect`, `next`가 당겨 갈 때 돈다. 만들고 안 쓰면 `warning: unused Map that must be used`가 난다.
- `collect::<Vec<_>>()`의 `::<…>`는 "터보피시"다. 무엇으로 모을지 알려 주고, `_`는 원소 타입을 추론하라는 뜻이다.
- C의 `for (i = 0; i < n; i++)`보다 길어 보이지만, 의도가 이름에 드러나고 경계 검사를 덜 하게 된다(D7에서 `cargo asm`으로 확인한다).
- **자주 쓰는 이유**: 파서의 `lines()`·`split()`(D3), 캐시 세트에서 줄 찾기 `position()`·`min_by_key()`(D4), 심볼 테이블 반복자 직접 구현(D10), 디렉터리 순회(D17), `getaddrinfo` 결과 순회(D44).

---

## 7. 슬라이스 · 바이트 · 문자열 · 경로
```rust
fn clamp_window(data: &[u8], start: usize, limit: usize) -> (usize, &[u8]) {
    // …
    (start, &data[start..end]) // 반열린 구간: start는 포함, end는 제외
}
let tail = data.get(start..).unwrap_or_default(); // 범위를 벗어나면 None, 대신 빈 슬라이스
```

| 타입 | 뜻 | C로 치면 |
|---|---|---|
| `&[u8]` | 바이트 슬라이스: 포인터 + 길이 (16바이트) | `const uint8_t *p, size_t n` |
| `b"abc"` | 바이트 문자열 리터럴, 타입은 `&[u8; 3]` | 끝의 `\0`이 없는 `"abc"` |
| `&b""[..]` | 배열 전체를 슬라이스로 (`[..]`는 처음부터 끝까지) | |
| `String` | 힙에 있는 UTF-8 문자열 (소유) | `malloc`한 `char *` + 길이 + 용량 |
| `&str` | 빌린 UTF-8 문자열 | `const char *` + 길이 |
| `OsString`, `&OsStr` | OS가 주는 문자열. 리눅스에서는 UTF-8이 아니어도 됨 | `argv`의 원소 |
| `PathBuf`, `&Path` | 경로. 속은 `OsString` | |
| `Cow<str>` | 빌린 것이거나 소유한 것. 필요할 때만 복사 | |

- `String::with_capacity(39)`는 미리 39바이트를 잡아 두고, `clear()`는 내용만 비우고 잡은 메모리는 유지하고(직접 확인), `push(c)`는 글자 하나를 붙인다.
- `to_string_lossy()`는 UTF-8이 맞으면 복사 없이 빌려 주고(`Cow::Borrowed`), 아니면 깨진 바이트를 `�`로 바꾼 새 문자열을 만든다. `.into_owned()`는 어느 쪽이든 `String`으로 만든다.
- `path.display()`는 경로를 `{}`로 찍을 수 있게 해 준다. 경로는 UTF-8이 아닐 수 있어서 `Path`는 `Display`를 직접 구현하지 않는다.
- `char::from(b)`는 `u8`을 같은 번호의 글자로 바꾼다.
- **자주 쓰는 이유**: 시스템 코드는 거의 다 "바이트 버퍼를 잘라 보는 일"이다. ELF 헤더(D8)는 `&data[..64]`를 잘라 `from_le_bytes`로 읽고, RIO(D16)는 `&mut [u8]`을 앞으로 밀며 채운다. 경로를 C 함수에 넘길 때는 `CString`이 필요하다(D15, 경로 안의 NUL 문제).

---

## 8. 수명 표기
```rust
MissingValue(&'static str)        // 프로그램이 끝날 때까지 살아 있는 문자열
fmt::Formatter<'_>                // 수명 매개변수가 있는 타입, 이름은 추론에 맡긴다
fn clamp_window(data: &[u8], start: usize, limit: usize) -> (usize, &[u8])
                                  // 돌려주는 슬라이스는 data 안을 가리킨다
```
- 수명은 "이 참조가 가리키는 값이 언제까지 살아 있나"를 컴파일러에 알리는 표시다. 실행 비용은 없다. C에서 "이 포인터는 버퍼가 해제되기 전까지만 쓸 것"이라고 주석으로 적던 걸 컴파일러가 검사한다.
- `"-s"` 같은 문자열 리터럴은 실행 파일의 `.rodata` 영역에 들어 있어서 `'static`이다(직접 확인했다. 2주차에 ELF로 다시 본다). 그래서 `CliError` 안에 수명 매개변수 없이 담을 수 있다.
- 생략 규칙: 참조 인자가 하나면, 돌려주는 참조는 그 인자를 가리킨다고 본다. `clamp_window`가 돌려준 슬라이스는 `data`보다 오래 쓸 수 없다.
- **자주 쓰는 이유**: 2주차부터 복사 없는 파서를 만든다. `struct Elf<'a> { data: &'a [u8] }`(D9), HTTP 요청 `Request<'a>`(D47), C 연결 리스트를 소유자에 묶는 반복자(D44), 스레드에 넘기는 값의 `'static` 바운드(D50).

---

## 9. 매크로와 포맷

| 매크로 | 하는 일 |
|---|---|
| `write!(대상, …)`, `writeln!(대상, …)` | 대상(`String`, 파일, `BufWriter` 등)에 쓴다. 결과는 `Result` |
| `eprintln!(…)` | 표준 에러로 출력 |
| `assert_eq!(a, b)` | 다르면 `left:`·`right:` 값을 보여 주며 패닉 (테스트용) |
| `debug_assert!(조건)` | debug 빌드에서만 검사한다. release에서는 사라진다 |
| `matches!(값, 패턴)` | 패턴이 맞으면 `true` |

| 포맷 | 뜻 | 결과 예 |
|---|---|---|
| `{offset:08x}` | 0으로 채운 8자리 소문자 16진 | `000000ff` |
| `{b:02x}` | 2자리 16진 | `0a` |
| `{hex:<39}` | 왼쪽 정렬, 최소 39칸 | `ab` 뒤에 공백 37칸 |
| `{s:>5}` | 오른쪽 정렬, 최소 5칸 | 공백 3칸 뒤에 `ab` |
| `{s:.2}` | 앞의 2글자까지만 | `ab` |
| `{n:#x}` | `0x`를 붙인 16진 | `0xff` |
| `{n:b}` | 2진 | `101` |
| `{v:?}` | Debug 형식 | `[97, 98, 99]` |

- `{offset}`처럼 변수 이름은 중괄호 안에 바로 쓸 수 있다. 식은 안 된다. `{base + i}`는 컴파일 오류라서 `{}`와 인자로 쓴다.
- 이름이 `!`로 끝나면 매크로다. 함수와 달리 인자 개수가 자유롭고, 포맷 문자열을 컴파일할 때 검사한다. 인자 개수가 틀리면 컴파일 오류다(C의 `printf`와 다른 점).
- **자주 쓰는 이유**: D1 주소 분해기는 `{:#x}`·`{:b}`로 비트를 보여 준다. D24에서는 시그널 핸들러 안에서 할당 없이 숫자를 찍으려고 `fmt::Write`를 직접 구현한다. D39 힙 검사기는 `debug_assert!`로 불변식을 지킨다.

---

## 10. 모듈 · 속성 · 문서 주석 · 비트 연산

### 모듈과 속성
```rust
//! xxd-lite: …                         // 이 파일(크레이트) 전체에 대한 설명
/// 해석이 끝난 옵션.                     // 바로 아래 항목의 설명 (cargo doc에 나온다)
use std::io::{self, BufWriter, Write};  // io 자체와 io::BufWriter, io::Write를 한 번에

#[cfg(test)]                            // cargo test로 빌드할 때만 포함한다
mod tests {
    use super::*;                       // 부모 모듈의 모든 것 (비공개 항목까지)

    #[test]                             // 테스트 함수 표시
    fn partial_line_is_padded_to_39() { /* … */ }
}
```
- `#[…]`는 속성이다. 컴파일러에게 주는 지시로, C의 `#pragma`나 `__attribute__`에 해당한다. 앞으로 `#[repr(C)]`(FFI 구조체), `#[unsafe(no_mangle)]`(D14), `#[global_allocator]`(D37)를 만난다.
- 자식 모듈은 부모의 비공개 항목도 볼 수 있다. 그래서 테스트 모듈이 `pub`이 아닌 `dump`를 부를 수 있다(직접 확인).
- 내일 wc-lite에서는 `mod`로 파일을 나눈다.

### 비트 연산과 정수 변환
```rust
HEX[usize::from(b >> 4)]   // 위 4비트: 0xab >> 4 = 0xa
HEX[usize::from(b & 0x0f)] // 아래 4비트: 0xab & 0x0f = 0xb
```
- `>>`는 부호 없는 타입이면 논리 시프트, 부호 있는 타입이면 산술 시프트다(`-8i8 >> 1`은 `-4`). C에서는 음수를 오른쪽으로 시프트한 결과가 구현마다 다를 수 있지만 Rust는 정해져 있다.
- 시프트 양이 비트 수 이상이면 debug 빌드는 `attempt to shift left with overflow`로 패닉하고, release는 시프트 양을 잘라서 계산한다(`1u64 << 64`가 `1`이 된다. 직접 확인). D1에서 `1 << b`로 마스크를 만들 때 b가 64면 여기에 걸린다.
- `usize::from(b)`는 값을 잃지 않는 변환만 허락한다. `usize::from(x_u64)`는 컴파일 오류다(usize가 32비트인 플랫폼이 있기 때문). 값이 잘릴 수 있으면 `usize::try_from(x)`로 `Result`를 받는다(D8 `try_into`). `as`는 검사 없이 자르거나 부호를 확장한다(D12에서 일부러 다룬다).
