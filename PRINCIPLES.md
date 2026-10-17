# 코드 원칙

`RULES.md`가 저장소를 어떻게 쓸지 정한다면, 이 파일은 코드를 어떻게 쓸지 정한다.
원칙마다 이유와 예시를 붙였다. 예시의 ✕는 피할 것, ○는 지향할 것이다.
예시는 D0 xxd-lite에서 가져왔다. 새로 배운 원칙은 여기에 추가한다.

## 한눈에 보기

| 번호 | 원칙 |
|---|---|
| 1-1 | `main`은 조립만 하고, 종료 코드는 `ExitCode`로 돌려준다 |
| 1-2 | 입력과 출력은 함수 인자로 받는다 |
| 2-1 | 처리할 수 없는 오류는 `?`로 올려 보낸다 |
| 2-2 | 오류 종류는 enum으로, 메시지는 `Display` 한 곳에서 만든다 |
| 2-3 | 오류에는 맥락을 담는다: 무엇을 하다가, 어디서, 왜 |
| 2-4 | 루프 안의 오류는 분류부터 정한다 |
| 2-5 | 패닉은 내 버그에만 쓴다 |
| 3-1 | 인자는 빌리고, 반환은 소유로 한다 |
| 3-2 | 검사가 끝난 값은 타입이 보장하게 한다 |
| 3-3 | 한 값은 한 이름으로만 들고 다닌다 |
| 3-4 | 경계를 지키는 연산은 식의 마지막에 둔다 |
| 3-5 | `match`의 `_`는 마지막 수단이다 |
| 4-1 | 이름은 타입이 아니라 역할로 짓는다 |
| 4-2 | 쓰이는 범위가 길수록 이름도 길게 짓는다 |
| 4-3 | 한 개념에는 한 단어만 쓴다 |
| 4-4 | std의 이름 관례를 따른다 |
| 5-1 | 반복 루프 안에서 할당하지 않는다 |
| 5-2 | 출력은 모아서 쓰고, 끝에서 직접 `flush`한다 |
| 5-3 | 추측하지 말고 측정한다 |
| 6-1 | 버그를 고치기 전에 그 버그의 테스트부터 쓴다 |
| 6-2 | 테스트는 출력·에러·종료 코드를 모두, 경계값까지 본다 |

---

## 1. 구조

### 1-1. `main`은 조립만 하고, 종료 코드는 `ExitCode`로 돌려준다
**이유**
- 해석, 계산, 출력을 함수로 나누면 하나씩 따로 테스트할 수 있다.
- 오류 출력과 종료가 한 곳에 모여서 메시지 형식이 저절로 통일된다.
- `process::exit`은 소멸자를 건너뛴다. `BufWriter`에 남은 출력이 사라지고, 파일이나 잠금도 정리되지 않는다.

```rust
// ✕ 오류가 날 때마다 그 자리에서 출력하고 종료 (D0에 5곳)
None => {
    eprintln!("Usage: xxd-lite [-s start] [-l length] <file>");
    std::process::exit(1);
}

// ○ 오류는 run에서 올라오고, main이 한 번만 출력한 뒤 종료 코드를 돌려준다
fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("xxd-lite: {e}");
            ExitCode::FAILURE
        }
    }
}
```

### 1-2. 입력과 출력은 함수 인자로 받는다
**이유** 함수 안에서 `std::env::args()`나 `stdout()`을 직접 부르면 진짜 인자와 진짜 화면으로만 실행할 수 있다. 인자로 받으면 테스트에서 가짜 인자와 `Vec<u8>`을 넣을 수 있다.

```rust
// ✕ 함수 안에서 바로 화면에 출력한다: 출력을 검사할 방법이 없다
fn dump(bytes: &[u8], base: usize) {
    // ... println!(...)
}

// ○ 어디서 읽고 어디에 쓸지는 부르는 쪽이 정한다 (시그니처만)
fn parse_args(args: impl Iterator<Item = OsString>) -> Result<Options, CliError>
fn dump(bytes: &[u8], base: usize, out: &mut impl Write) -> io::Result<()>

// 실행할 때:   dump(window, start, &mut out)?;            (out은 stdout을 감싼 BufWriter)
// 테스트할 때: let mut out = Vec::new(); dump(b"Hi", 0, &mut out)?;
```

---

## 2. 오류 처리

Rust에는 예외가 없다. 오류는 `Result`라는 값이고, 함수 시그니처에 드러난다.
그래서 물어야 할 것은 "어디서 잡을까"가 아니라 "이 값을 받은 곳이 처리할 수 있나, 위로 넘겨야 하나"다.

### 2-1. 처리할 수 없는 오류는 `?`로 올려 보낸다
**이유** 오류가 난 곳은 대개 어떻게 처리할지 모른다. `parse_value`는 프로그램을 끝낼지, 기본값을 쓸지 알 수 없다. 처리 방법은 그걸 아는 층에서 한 번만 정한다. 덤으로 정상 흐름이 중첩 없이 위에서 아래로 곧게 남는다.

`?`가 하는 일은 이게 전부다.
```rust
let n = text.parse::<usize>()?;
// 위 한 줄은 아래와 같다
let n = match text.parse::<usize>() {
    Ok(v) => v,
    Err(e) => return Err(From::from(e)), // 필요하면 오류 타입을 바꿔서 반환
};
```

```rust
// ✕ 4단 중첩, 오류마다 그 자리에서 종료
flag @ ("-s" | "-l") => match iter.next() {
    Some(val) => match val.parse::<usize>() {
        Ok(n) => match flag { "-s" => opt.st = n, _ => opt.len = n },
        Err(_) => { eprintln!("..."); std::process::exit(1); }
    },
    None => { eprintln!("..."); std::process::exit(1); }
},

// ○ 실패는 Err로 돌려주고, 부르는 쪽은 ? 한 글자
fn parse_value(flag: &'static str, value: Option<OsString>) -> Result<usize, CliError> {
    let Some(value) = value else {          // let-else: 값이 없으면 바로 빠져나간다
        return Err(CliError::MissingValue(flag));
    };
    let text = value.to_string_lossy().into_owned();
    text.parse().map_err(|_| CliError::BadNumber { flag, text })
}

Some("-s") => start = parse_value("-s", args.next())?,
```

### 2-2. 오류 종류는 enum으로, 메시지는 `Display` 한 곳에서 만든다
**이유**
- 부르는 쪽이 종류별로 다르게 처리할 수 있다. 예를 들어 닫힌 파이프만 조용히 끝낼 수 있다.
- 테스트에서 `matches!`로 어떤 오류인지 검사할 수 있다.
- 메시지 형식(소문자로 시작, 마침표 없음)을 한 곳에서 정한다.
- 오류를 `String`으로 만들면 종류 정보가 사라져서 위 세 가지가 모두 안 된다.

```rust
// ✕ 메시지 문자열만 남는다: 무슨 오류인지 구분할 수 없다
fn parse_value(flag: &str, value: Option<String>) -> Result<usize, String>
Err(format!("{flag}: invalid number: {text}"))

// ○ 종류는 variant로, 메시지는 Display에서
#[derive(Debug)]
enum CliError {
    MissingValue(&'static str),
    BadNumber { flag: &'static str, text: String },
    Read { path: PathBuf, source: io::Error },
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingValue(flag) => write!(f, "{flag}: missing value"),
            Self::BadNumber { flag, text } => write!(f, "{flag}: invalid number: {text}"),
            Self::Read { path, source } => write!(f, "{}: {source}", path.display()),
        }
    }
}
```
variant를 새로 추가하면 `Display`의 `match`가 컴파일 오류를 내서, 메시지 쓰는 걸 잊지 않게 해 준다(3-5).

### 2-3. 오류에는 맥락을 담는다: 무엇을 하다가, 어디서, 왜
**이유** `No such file or directory`만으로는 어느 파일인지 모른다. 시스템 콜은 원인(왜)만 알려 주고, 대상(어디서)은 내가 붙여야 한다.

```rust
// ✕ 원인만 남는다 → "xxd-lite: No such file or directory (os error 2)"
let data = fs::read(&path)?; // io::Error를 그대로 올린다

// ○ 대상을 붙인다 → "xxd-lite: /없는/파일: No such file or directory (os error 2)"
let data = fs::read(&path).map_err(|source| CliError::Read { path, source })?;
```
`path`를 오류 안으로 옮겨서(move) 복사가 없다. 이 줄 뒤에 `path`를 또 써야 하면 `path.clone()`을 넣는다.

### 2-4. 루프 안의 오류는 분류부터 정한다
**이유** 같은 `Err`라도 할 일이 다르다. 분류가 정해지면 arm에 쓸 코드(`continue`, `?`, `break`)가 정해진다. 새 시스템 콜을 쓸 때마다 "이 오류는 어느 칸인가?"부터 묻는다.

| 분류 | 예 | 할 일 | 코드 |
|---|---|---|---|
| 일시적 | EINTR(시그널에 끊김), EAGAIN | 다시 시도 | 가드 + `continue` |
| 이번 항목만 실패 | 여러 파일 중 하나가 없음, 클라이언트 하나가 끊김 | 알리고 다음으로 | `eprintln!` + `continue` |
| 더 진행할 수 없음 | 잘못된 인자, 출력 실패 | 위로 전파 | `?` |
| 정상적인 끝 | `read`가 0을 돌려줌(EOF), 읽는 쪽이 파이프를 닫음 | 조용히 끝 | `Ok(0)` arm, `ErrorKind` 분기 |
| 내 버그 | 불변식이 깨짐 | 멈춤 | `assert!`, `expect` |

```rust
// 한 match에 네 분류가 다 있다. arm 순서는 구체적인 것 → 가드 → 포괄 (CSAPP 10장 RIO와 같은 구조)
loop {
    match src.read(&mut buf) {
        Ok(0) => break,                                               // 정상적인 끝 (EOF)
        Ok(n) => out.write_all(&buf[..n])?,                           // 정상. 쓰기 실패는 전파
        Err(e) if e.kind() == io::ErrorKind::Interrupted => continue, // 일시적: 다시
        Err(e) => return Err(e),                                      // 진행 불가: 전파
    }
}

// 항목 하나의 실패는 알리고 다음으로 (`cat a 없는파일 b`가 b까지 출력하는 방식)
for path in paths {
    let data = match fs::read(path) {
        Ok(data) => data,
        Err(e) => {
            eprintln!("prog: {}: {e}", path.display());
            status = ExitCode::FAILURE; // 실패는 기억해 두고
            continue;                   // 다음 파일로
        }
    };
    // ... data 처리
}
```
서버(11장 프록시)도 같다. 연결 하나가 실패하면 기록만 하고 다음 연결로 넘어간다. 오류마다 종료하는 서버는 클라이언트 하나가 연결을 끊는 순간 통째로 죽는다.

### 2-5. 패닉은 내 버그에만 쓴다
**이유** 패닉은 "프로그램이 틀렸다"는 신호다. 잘못된 입력은 프로그램이 틀린 게 아니라 예상해야 하는 상황이므로 `Result`로 다룬다. 그러려면 사용자 입력으로 패닉이 날 수 있는 곳부터 알아야 한다.

| 패닉하는 것 | 언제 | 대신 쓸 것 |
|---|---|---|
| `std::env::args()` | 인자가 UTF-8이 아닐 때 | `std::env::args_os()` |
| `v[i]`, `&v[a..b]` | 범위를 벗어날 때 | `v.get(i)`, `v.get(a..b)` (`Option`을 돌려줌) |
| `a + b` | debug 빌드에서 오버플로가 날 때 | `checked_add`, `saturating_add` |
| `println!` | 쓰기에 실패할 때 (예: 닫힌 파이프) | `writeln!(out, …)?` |
| `.unwrap()` | `None`이나 `Err`일 때 | `?`, `match`, `let-else` |

`expect`는 실패할 수 없는 이유를 메시지로 쓸 수 있을 때만 쓴다. 그 메시지가 곧 불변식의 문서가 된다.
```rust
write!(hex, "{b:02x}").expect("String에 쓰기는 실패하지 않음");
```

---

## 3. 타입과 값

### 3-1. 인자는 빌리고, 반환은 소유로 한다
**이유** 빌리면 복사가 없고, 부르는 쪽이 값을 계속 쓸 수 있다. 새로 만든 값은 소유로 돌려줘야 부르는 쪽이 수명 걱정 없이 쓴다.

```rust
// ✕ 값을 가져가 버린다: 호출 뒤에 data를 쓰면 error[E0382]
fn dump(bytes: Vec<u8>) { /* ... */ }
dump(data);
println!("{}", data.len()); // borrow of moved value

// ○ 빌려 본다
fn dump(bytes: &[u8]) { /* ... */ }
dump(&data);
println!("{}", data.len()); // OK
```

| 받을 때 (빌림) | 돌려줄 때 (소유) |
|---|---|
| `&[u8]` | `Vec<u8>` |
| `&str` | `String` |
| `&Path` | `PathBuf` |

받을 때는 `&Vec<u8>`, `&String`보다 `&[u8]`, `&str`이 낫다. 배열, 슬라이스, 문자열 리터럴까지 모두 받을 수 있다.

### 3-2. 검사가 끝난 값은 타입이 보장하게 한다
**이유** `Option` 필드는 쓰는 곳마다 "없으면?"을 다시 묻게 만든다. 검사는 한 번만 하고 결과를 확정된 타입에 담으면, 이후 코드에서는 그 경우가 아예 사라진다.

```rust
// ✕ 파싱이 끝나도 path는 "없을 수 있다"
struct Args { st: usize, len: usize, path: Option<String> }

// ○ 파싱 중에는 지역 변수로 Option을 쓰고, 검사가 끝나면 확정된 타입으로
let mut path = None;
// ... 루프에서 path = Some(PathBuf::from(arg))
let path = path.ok_or(CliError::Usage)?; // 여기서 한 번 검사한다
Ok(Options { start, limit, path })       // Options.path는 PathBuf라서 항상 있다
```

### 3-3. 한 값은 한 이름으로만 들고 다닌다
**이유** 같은 값의 두 버전(자르기 전과 후)이 함께 있으면 언젠가 틀린 쪽을 쓴다. D0에서는 오프셋 계산에 자르기 전 값 `opt.st`를 썼다. 지금은 우연히 맞지만, 자르는 방식이 바뀌면 바로 버그가 된다.

```rust
// ✕ 자른 값(start)과 자르기 전 값(opt.st)이 함께 돌아다닌다
let start = opt.st.min(data.len());
// ...
let offset = opt.st + i * 16;

// ○ 같은 이름으로 덮어써서(shadowing) 자르기 전 값은 아예 못 쓰게 한다
let Options { start, limit, path } = parse_args(std::env::args_os().skip(1))?;
// ...
let (start, window) = clamp_window(&data, start, limit); // 이 줄부터 start는 자른 값뿐이다
```

### 3-4. 경계를 지키는 연산은 식의 마지막에 둔다
**이유** `end ≤ len`을 보장하는 `min`이 식 중간에 있으면, 그 뒤의 덧셈이 경계를 다시 넘긴다. D0의 `-s` 패닉이 이것이었다. 지킨 불변식은 `debug_assert!`로 적어 두면, 깨지는 순간 그 자리에서 멈춘다(release 빌드에서는 검사하지 않는다).

```rust
// ✕ min 뒤에 덧셈: 13바이트 파일에 -s 7 → 7 + min(MAX, 13) = 20 > 13 → 패닉
let end = start.saturating_add(limit.min(data.len()));

// ○ min이 마지막: 무엇을 더하든 end ≤ data.len()
let end = start.saturating_add(limit).min(data.len());
debug_assert!(start <= end && end <= data.len());

// ○ 덧셈 자체를 없애는 방법도 있다
let tail = data.get(start..).unwrap_or_default(); // start가 넘으면 빈 슬라이스
let window = &tail[..tail.len().min(limit)];
```

### 3-5. `match`의 `_`는 마지막 수단이다
**이유** `_`는 "나머지는 신경 쓰지 마"라는 뜻이라 컴파일러의 빠짐 검사를 끈다. 경우를 다 나열해 두면, 새 경우가 생겼을 때 처리하지 않은 곳을 컴파일러가 알려 준다. enum에 variant를 추가했을 때 그 enum을 다루는 `match`마다 컴파일 오류가 나는 것도 이 덕분이다.

```rust
// ✕ "-s가 아니면 -l"이라는 가정이 숨어 있다.
//    바깥 패턴에 "-c"를 추가하면 -c의 값이 조용히 len에 들어간다
Ok(n) => match flag {
    "-s" => opt.st = n,
    _ => opt.len = n,
},

// ○ 경우마다 arm을 따로 둔다. 순서는 구체적인 것 → 가드 → 포괄
Some("-s") => start = parse_value("-s", args.next())?,
Some("-l") => limit = parse_value("-l", args.next())?,
Some(s) if s.starts_with('-') => return Err(CliError::UnknownOption(s.to_owned())),
_ if path.is_some() => return Err(CliError::TooManyFiles),
_ => path = Some(PathBuf::from(arg)),
```
문자열처럼 경우가 무한하면 `_`가 필요하다. 그때도 구체적인 arm을 먼저 다 쓰고, `_`는 진짜 나머지만 받게 한다. `io::ErrorKind`처럼 `#[non_exhaustive]`가 붙은 enum은 앞으로 종류가 늘 수 있어서 `_`가 필수다.

---

## 4. 이름

### 4-1. 이름은 타입이 아니라 역할로 짓는다
**이유** 타입은 컴파일러와 에디터가 알려 준다. 이름은 코드가 알려 주지 않는 것, 즉 이 값이 무엇에 쓰이는지를 말해야 한다.

| ✕ | ○ | 이유 |
|---|---|---|
| `iter` | `args` | 반복자라는 건 타입이 말해 준다. 무엇을 도는지가 중요하다 |
| `hex` (바이트 하나) | `b` | 16진 문자열이 아니라 바이트다 |
| `line` (16진 부분만) | `hex` | 줄 전체가 아니다 |
| `data` (일부 구간) | `window` | 전체 데이터와 다른 것이다 |

### 4-2. 쓰이는 범위가 길수록 이름도 길게 짓는다
**이유** 3줄짜리 루프의 `i`, `b`는 바로 위에서 뜻이 보인다. 구조체 필드와 함수 인자는 멀리서 읽히니 완전한 단어여야 한다. 낯선 약어는 grep으로 찾을 수도 없다(`st`로 검색하면 `start`, `std`, `struct`가 다 걸린다).

```rust
// ✕ 멀리서 읽히는데 뜻을 알 수 없다
struct Args { st: usize, len: usize, path: Option<String> }
let mut opt = Args { st: 0, len: usize::MAX, path: None };

// ○
struct Options { start: usize, limit: usize, path: PathBuf }
let opts = parse_args(std::env::args_os().skip(1))?;
```
줄여 써도 되는 건 널리 쓰이는 약어뿐이다: `buf`, `len`, `idx`, `ptr`, `fd`, `addr`, `src`, `dst`, `e`/`err`, `msg`, `cfg`, `ctx`, `n`, 루프의 `i`/`j`.

### 4-3. 한 개념에는 한 단어만 쓴다
**이유** 한 줄에 같은 단어가 다른 뜻으로 두 번 나오면 버그가 눈에 안 띈다. D0의 `opt.len.min(data.len())`에서 두 `len`은 뜻이 다르다(출력 상한과 파일 크기). 이 줄이 자연스러워 보여서 `min`의 위치가 틀린 것(3-4)이 안 보였다.

| 단어 | 뜻 |
|---|---|
| `offset` | 기준점에서 떨어진 거리 (보통 바이트) |
| `index` | 원소 번호 |
| `len`, `count` | 원소 개수 |
| `size` | 바이트 크기 |
| `capacity` | 할당된 양 |
| `start..end` | 반열린 구간 (`end`는 포함하지 않음) |
| `last` | 포함되는 마지막 위치 |
| `limit`, `max_*` | 상한 |

- 단위는 이름에 넣는다: `timeout_ms`, `block_size_bytes`. 캐시 시뮬레이터의 `s, E, b`도 코드에서는 `set_bits`, `lines_per_set`, `block_bits`로 쓴다.
- bool은 질문형으로 짓고 부정형은 피한다: `is_partial`, `has_path` (○) / `not_found` (✕, `!not_found`가 생긴다).
- 함수는 동사, 값은 명사로 짓는다: `parse_args`, `clamp_window` / `opts`, `window`.

### 4-4. std의 이름 관례를 따른다
**이유** 관례를 알면 처음 보는 함수도 이름만으로 비용과 소유권을 짐작할 수 있다. 큰 코드를 빨리 읽는 힘의 절반이 여기서 나온다. 내 함수도 같은 관례를 따르면 남도, 석 달 뒤의 나도 그렇게 읽는다.

| 형태 | 뜻 | 예 |
|---|---|---|
| `new`, `with_capacity`, `from_*` | 생성자 | `String::with_capacity(39)` |
| `as_*` | 비용 없음, 빌림 → 빌림 | `as_str`, `as_bytes` |
| `to_*` | 비용 있음 (복사·변환) | `to_string`, `to_vec`, `to_owned` |
| `into_*` | 소유권을 가져감 | `into_bytes`, `into_owned` |
| `is_*`, `has_*` | bool을 돌려줌 | `is_empty`, `is_some` |
| `get_` 없는 getter | 그냥 값 | `len()` (`get(i)`는 `Option`을 주는 조회) |
| `try_*` | 실패하면 `Result` | `try_from`, `try_into` |
| `*_mut` | `&mut` 버전 | `iter_mut`, `get_mut` |
| `*_or`, `*_or_else` | 실패할 때의 대체값 | `unwrap_or`, `ok_or_else` |

- 표기(`snake_case` 등)는 `RULES.md`를 따른다. 약어도 한 단어로 쓴다: `TcpStream`, `Utf8Error` (○) / `TCPStream` (✕).
- 오류 타입은 `…Error`로 짓고, variant에는 `Error`를 붙이지 않는다: `CliError::BadNumber`.
- `_`와 `_이름`은 다르다. `let _ = 값;`은 그 자리에서 바로 버리고(drop), `let _guard = 값;`은 스코프 끝까지 살려 둔다. 12장에서 `let _ = mutex.lock()`이라고 쓰면 잠금이 즉시 풀린다.

---

## 5. 성능

### 5-1. 반복 루프 안에서 할당하지 않는다
**이유** 힙 할당은 결국 `malloc` 호출이다(9장). 바이트마다 `format!`을 부르면 64MB 파일에서 약 6,700만 번 할당한다. 버퍼는 루프 밖에서 한 번 만들고 `clear()`로 재사용한다.

```rust
// ✕ 바이트마다 String을 새로 만든다
for &b in chunk {
    line.push_str(&format!("{b:02x}"));
}

// ○ 버퍼는 루프 밖에서 한 번 만들고, 그 버퍼에 직접 쓴다
use std::fmt::Write as _; // String에 write!를 쓰는 트레잇 (io::Write와 다르다)
let mut hex = String::with_capacity(39);
for chunk in bytes.chunks(16) {
    hex.clear(); // 메모리는 그대로 두고 내용만 비운다
    for &b in chunk {
        write!(hex, "{b:02x}").expect("String에 쓰기는 실패하지 않음");
    }
    // ...
}
```
반복 루프 안에 `format!`, `to_string()`, `String::new()`, `Vec::new()`가 보이면 의심한다.

### 5-2. 출력은 모아서 쓰고, 끝에서 직접 `flush`한다
**이유** Rust의 stdout은 파이프나 파일로 내보낼 때도 줄마다 `write` 시스템 콜을 한다. 터미널이 아니면 블록 단위로 모아 쓰는 C의 stdio와 다르다. `BufWriter`로 감싸면 수 KB씩 모아서 쓴다. `BufWriter`는 drop될 때도 flush하지만 그때 생긴 오류는 버리므로, 오류를 보려면 마지막에 직접 `flush()`한다.

```rust
// ✕ 줄마다 write 한 번: /bin/ls 덤프에 8,895번
println!("{offset:08x}: {hex:<39}  {ascii}");

// ○ 모아서 쓴다: 149번
let mut out = BufWriter::new(io::stdout().lock()); // 잠금도 한 번만 잡는다
writeln!(out, "{offset:08x}: {hex:<39}  {ascii}")?;
// ...
out.flush()?; // 마지막에 직접
```

### 5-3. 추측하지 말고 측정한다
**이유** 병목은 짐작과 다른 곳에 있다. D0에서도 /dev/null로 보낼 때는 할당과 포맷이, 파이프로 보낼 때는 시스템 콜이 병목이었다.

```sh
mkdir -p scratch && head -c 64M /dev/urandom > scratch/big.bin
cargo build -q --release -p xxd-lite
time target/release/xxd-lite scratch/big.bin > /dev/null              # 전체 시간
time target/release/xxd-lite scratch/big.bin | cat > /dev/null        # 파이프로
strace -c -e trace=write target/release/xxd-lite /bin/ls > /dev/null  # write 횟수
```

D0 측정 (Xeon 2.1GHz 2코어 VM, 커널 6.18, `--release`, 64MB 무작위 파일)

| 버전 | → /dev/null | → 파이프 |
|---|---|---|
| D0 처음 코드 (`println!`, 바이트마다 `format!`) | 5.4초 | 30.0초 |
| + `BufWriter` (5-2) | 4.5초 | 4.6초 |
| + `format!` 대신 `write!` (5-1) | 2.9초 | 3.7초 |
| + 줄 버퍼 재사용 (5-1, 7절 예시) | 1.9초 | 2.2초 |
| + `write!` 대신 16진 표 조회 | 0.52초 | 0.96초 |
| 참고: C로 된 xxd | 1.25초 | 2.4초 |

원칙만 지켜도(7절) 2.8배, 파이프로는 13배 빨라진다. 더 줄이고 싶으면 포맷 대신 표에서 글자를 꺼낸다.
```rust
const HEX: &[u8; 16] = b"0123456789abcdef";
hex.push(char::from(HEX[usize::from(b >> 4)]));   // 위 4비트
hex.push(char::from(HEX[usize::from(b & 0x0f)])); // 아래 4비트
```

---

## 6. 검증

### 6-1. 버그를 고치기 전에 그 버그의 테스트부터 쓴다
**이유** 테스트가 먼저 실패하는 걸 봐야, 그 테스트가 정말 그 버그를 잡는다는 게 증명된다. 고친 뒤에는 같은 버그가 다시 생기는 걸 막는다. 이런 테스트를 쓰려면 입출력을 인자로 받아야 한다(1-2).

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn partial_line_is_padded_to_39() {
        // 버그 1: 덜 찬 줄의 ASCII 열이 한 칸 당겨짐
        let mut out = Vec::new();
        dump(b"Hello, world\n", 0, &mut out).unwrap();
        assert_eq!(
            out,
            b"00000000: 4865 6c6c 6f2c 2077 6f72 6c64 0a         Hello, world.\n"
        );
    }

    #[test]
    fn start_alone_stays_in_bounds() {
        // 버그 2: -s만 주면 end가 파일 끝을 넘어 패닉
        assert_eq!(clamp_window(b"Hello", 1, usize::MAX), (1, &b"ello"[..]));
        assert_eq!(clamp_window(b"Hello", 7, usize::MAX), (5, &b""[..]));
    }
}
```
두 테스트 모두 D0의 버그를 일부러 다시 넣으면 실패하는 것을 확인했다.

### 6-2. 테스트는 출력·에러·종료 코드를 모두, 경계값까지 본다
**이유** 표준 출력만 비교하면 패닉해도 통과할 수 있다. D0의 처음 완료 기준이 그래서 `-s` 패닉을 놓쳤다. 버그는 경계에 모이므로 0, 1, n−1, n, n+1, 아주 큰 값을 넣는다.

```sh
cargo build -q -p xxd-lite && X=target/debug/xxd-lite
check() { diff <(xxd "$@" 2>&1; echo "exit=$?") <($X "$@" 2>&1; echo "exit=$?") >/dev/null && echo "OK   $*" || echo "FAIL $*"; }
L=$(stat -c %s Cargo.toml)
check -s 1 Cargo.toml                                    # 1
check -s $((L-1)) Cargo.toml                             # n-1
check -s $L Cargo.toml                                   # n
check -s $((L+1)) Cargo.toml                             # n+1
check -l 0 Cargo.toml; check -l 99999999999 Cargo.toml  # 0, 아주 큰 값
```

---

## 7. 전체 예시: D0 xxd-lite

위 원칙을 모두 적용해 D0을 다시 쓴 것이다. 주석의 괄호 안 번호가 적용한 원칙이다.
D0 완료 기준 18개와 테스트 3개를 통과하고, `clippy::pedantic` 경고가 0개다.

```rust
//! xxd-lite: 파일을 16진수로 덤프한다 (D0 리뷰 반영 예시)

use std::ffi::OsString;
use std::fmt;
use std::fs;
use std::io::{self, BufWriter, Write};
use std::path::PathBuf;
use std::process::ExitCode;

const BYTES_PER_LINE: usize = 16;

/// 해석이 끝난 옵션. 검사를 통과한 값만 담는다 (3-2)
struct Options {
    start: usize,
    limit: usize,
    path: PathBuf,
}

/// 이 프로그램에서 날 수 있는 오류의 전체 목록 (2-2)
#[derive(Debug)]
enum CliError {
    Usage,
    MissingValue(&'static str),
    BadNumber { flag: &'static str, text: String },
    UnknownOption(String),
    TooManyFiles,
    Read { path: PathBuf, source: io::Error }, // 어느 파일인지 맥락을 담는다 (2-3)
    Write(io::Error),
}

impl fmt::Display for CliError {
    // 메시지 형식은 여기 한 곳에서: 소문자로 시작, 마침표 없음 (2-2)
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: xxd-lite [-s start] [-l length] <file>"),
            Self::MissingValue(flag) => write!(f, "{flag}: missing value"),
            Self::BadNumber { flag, text } => write!(f, "{flag}: invalid number: {text}"),
            Self::UnknownOption(opt) => write!(f, "unknown option: {opt}"),
            Self::TooManyFiles => write!(f, "only one file can be given"),
            Self::Read { path, source } => write!(f, "{}: {source}", path.display()),
            Self::Write(source) => write!(f, "write error: {source}"),
        }
    }
}

/// 결과를 종료 코드로 바꾸기만 한다. exit은 쓰지 않는다 (1-1)
fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        // 확장 ①: "조용히 끝낼 오류"는 이 자리에 arm을 하나 더 둔다 (2-4)
        Err(e) => {
            eprintln!("xxd-lite: {e}"); // 접두사는 여기서만 붙인다
            ExitCode::FAILURE
        }
    }
}

/// 조립: 해석 → 읽기 → 자르기 → 출력. 실패는 ?로 올려 보낸다 (2-1)
fn run() -> Result<(), CliError> {
    let Options { start, limit, path } = parse_args(std::env::args_os().skip(1))?;
    // path는 오류 안으로 옮겨 간다. 이 뒤로 path를 안 쓰니 복사할 필요가 없다 (2-3)
    let data = fs::read(&path).map_err(|source| CliError::Read { path, source })?;
    // 자른 start로 덮어쓴다. 자르기 전 값은 이제 쓸 수 없다 (3-3)
    let (start, window) = clamp_window(&data, start, limit);
    let mut out = BufWriter::new(io::stdout().lock()); // 모아서 쓴다 (5-2)
    dump(window, start, &mut out).map_err(CliError::Write)?;
    out.flush().map_err(CliError::Write) // drop에 맡기면 flush 오류가 사라진다 (5-2)
}

/// 인자를 직접 읽지 않고 받는다. 테스트에서 가짜 인자를 넣을 수 있다 (1-2)
fn parse_args(mut args: impl Iterator<Item = OsString>) -> Result<Options, CliError> {
    let (mut start, mut limit, mut path) = (0, usize::MAX, None);
    while let Some(arg) = args.next() {
        // 구체적인 arm → 가드 → 포괄 순서 (3-5)
        match arg.to_str() {
            Some("-s") => start = parse_value("-s", args.next())?,
            Some("-l") => limit = parse_value("-l", args.next())?,
            Some(s) if s.starts_with('-') => return Err(CliError::UnknownOption(s.to_owned())),
            _ if path.is_some() => return Err(CliError::TooManyFiles),
            _ => path = Some(PathBuf::from(arg)),
        }
    }
    let path = path.ok_or(CliError::Usage)?; // 여기서 한 번 검사하면 이후로는 항상 있다 (3-2)
    Ok(Options { start, limit, path })
}

fn parse_value(flag: &'static str, value: Option<OsString>) -> Result<usize, CliError> {
    let Some(value) = value else {
        return Err(CliError::MissingValue(flag));
    };
    let text = value.to_string_lossy().into_owned();
    text.parse().map_err(|_| CliError::BadNumber { flag, text })
}

/// 출력할 구간과 그 시작 위치. 파일 밖을 가리키지 않는다 (3-4)
fn clamp_window(data: &[u8], start: usize, limit: usize) -> (usize, &[u8]) {
    let start = start.min(data.len());
    let end = start.saturating_add(limit).min(data.len()); // 경계를 지키는 min은 마지막에
    debug_assert!(start <= end && end <= data.len());
    (start, &data[start..end])
}

/// 어디에 쓸지는 호출자가 정한다: 실행할 땐 stdout, 테스트할 땐 Vec<u8> (1-2)
fn dump(bytes: &[u8], base: usize, out: &mut impl Write) -> io::Result<()> {
    use std::fmt::Write as _; // String에 write!를 쓰기 위한 트레잇 (io::Write와 다름)

    let mut hex = String::with_capacity(39); // 줄 버퍼는 루프 밖에서 한 번 (5-1)
    let mut ascii = String::with_capacity(BYTES_PER_LINE);
    for (i, chunk) in bytes.chunks(BYTES_PER_LINE).enumerate() {
        hex.clear(); // 메모리는 두고 내용만 비운다
        ascii.clear();
        for (j, &b) in chunk.iter().enumerate() {
            if j > 0 && j % 2 == 0 {
                hex.push(' '); // 구분자는 묶음 사이에만
            }
            write!(hex, "{b:02x}").expect("String에 쓰기는 실패하지 않음");
            ascii.push(match b {
                0x20..=0x7e => char::from(b),
                _ => '.',
            });
        }
        let offset = base + i * BYTES_PER_LINE;
        writeln!(out, "{offset:08x}: {hex:<39}  {ascii}")?; // 쓰기 실패는 위로 (2-5)
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(list: &[&str]) -> impl Iterator<Item = OsString> {
        list.iter()
            .map(OsString::from)
            .collect::<Vec<_>>()
            .into_iter()
    }

    #[test]
    fn partial_line_is_padded_to_39() {
        // 버그 1: 덜 찬 줄의 ASCII 열이 한 칸 당겨짐 (6-1)
        let mut out = Vec::new();
        dump(b"Hello, world\n", 0, &mut out).unwrap();
        assert_eq!(
            out,
            b"00000000: 4865 6c6c 6f2c 2077 6f72 6c64 0a         Hello, world.\n"
        );
    }

    #[test]
    fn start_alone_stays_in_bounds() {
        // 버그 2: -s만 주면 end가 파일 끝을 넘어 패닉 (6-1)
        assert_eq!(clamp_window(b"Hello", 1, usize::MAX), (1, &b"ello"[..]));
        assert_eq!(clamp_window(b"Hello", 7, usize::MAX), (5, &b""[..]));
    }

    #[test]
    fn missing_value_is_an_error() {
        assert!(matches!(
            parse_args(args(&["f", "-s"])),
            Err(CliError::MissingValue("-s"))
        ));
    }
}
```

---

## 8. 커밋 전 점검

- [ ] `process::exit`이 없고, 사용자 입력이 닿는 곳에 `unwrap()`이 없다 (1-1, 2-5)
- [ ] 새 오류는 `CliError` variant로 만들었고, 맥락을 담았다 (2-2, 2-3)
- [ ] `_` arm은 진짜 나머지만 받는다 (3-5)
- [ ] 한 줄에 같은 단어가 다른 뜻으로 두 번 나오지 않는다 (4-3)
- [ ] 반복 루프 안에 `format!`, `to_string()`, `String::new()`, `Vec::new()`가 없다 (5-1)
- [ ] 이번에 고친 버그마다 테스트가 있다 (6-1)
- [ ] 완료 기준이 출력·에러·종료 코드를 모두 비교한다 (6-2)
