# D3 브리핑 · trace-parse

2026-10-27. 명세는 `README.md`, 개념은 `concepts/d03-caching-and-traces.md`.

D2에서 넘어온 것: 리뷰의 "반드시 고칠 것" 중 테스트(길이 7, stride 3)는 1ebf2f2에서 고쳤다(`cargo test -p mountain` 3개 통과). 워크스페이스 clippy 경고 하나가 아직 남아 있다: `days/d00-wc-lite/src/counts.rs:22`(`collapsible_match`, D1부터). 고치면 D3과 섞지 말고 따로 커밋한다. 리뷰의 "원칙" 지적(4-4 `InvalidUtf8`, 3-3 `size_of::<u64>()`, 2-3 `-\xff`)은 "반드시 고칠 것"이 아니었으니 오늘 할 일에서 뺀다.

D2는 막힌 시간이 300분을 넘었다. 오늘은 핵심(F1~F5, E1~E4, 테스트 4개)이 check.sh를 통과하면 완료다. 확장 `-w`는 시간이 남을 때 한다.

## 1. 복습 퀴즈 (D2)
1. 트레이스에 ` L 1000,8`, ` L 1100,8`, ` L 1200,8`, …처럼 0x100(256바이트)씩 늘어나는 읽기가 이어진다. 이 머신의 L1d(S = 64, E = 8, B = 64)에서 이 주소들의 세트 인덱스는 어떻게 바뀌나? 이 패턴이 쓸 수 있는 L1d는 몇 바이트어치인가? 간격이 0x400(1KB)이면?
2. 설정 파일 65만 줄을 줄마다 아래 둘 중 하나로 해석한다. 모든 줄이 `key=value` 꼴로 정상이다. 두 줄의 결과는 같은가? 65만 줄을 읽는 동안 각각 `line.to_owned()`는 몇 번 불리나? 왜 그런가?
   ```rust
   let (key, value) = line.split_once('=').ok_or(ConfigError::NoEquals(line.to_owned()))?;
   let (key, value) = line.split_once('=').ok_or_else(|| ConfigError::NoEquals(line.to_owned()))?;
   ```

## 2. 명세 요점
```
trace-parse <트레이스 파일>
valgrind --tool=lackey --trace-mem=yes --log-file=scratch/ls.trace ls    # 트레이스 만들기
```
- 줄 형식: `<연산> <주소>,<크기>`. 연산은 `I`·`L`·`S`·`M`, 주소는 `0x` 없는 16진수(< 2^64), 크기는 1 이상의 10진수. 줄 앞뒤 공백은 무시하고, 칸 사이는 공백 하나 이상
- 앞뒤 공백을 뺀 내용이 비었거나 `==`로 시작하는 줄은 건너뛴다(valgrind의 메시지). 나머지는 모두 잘못된 줄이다
- 출력 여섯 줄: `instr`·`load`·`store`·`modify`(줄 수), `min`·`max`(데이터 접근 주소, `{:#x}`). `I` 줄은 세기만 하고 주소 범위에 넣지 않는다. 데이터 접근이 없으면 `min -`, `max -`
- 오류 E1~E4: `trace-parse: …` 한 줄, 종료 코드 1, 표준 출력 비움. E3는 **`경로:줄 번호: 이유`**. 줄 번호는 1부터, 건너뛴 줄도 센다. 가장 앞의 잘못된 줄에서 멈춘다
- 제약: `src/trace.rs`에 `Op`·`Access`·`parse_line(&str) -> Result<Option<Access>, ParseError>`. 테스트 4개 이상(I 줄, 데이터 줄, 건너뛸 줄, 잘못된 줄)을 `assert_eq!`로. std만, unsafe 없음, `args_os`, enum + `Display`, `writeln!` + `flush`
- 완료 기준: check.sh(debug 빌드). 작은 트레이스 결과를 그대로 비교하고, 그게 다 통과하면 valgrind로 `/bin/true`의 트레이스를 만들어 `grep`·`sort`로 구한 값과 비교한다
- 확장: `-w`로 서로 다른 64바이트 블록 수(`blocks`)를 더 쓴다(`HashSet`, `EXT=1`)

## 3. 개념 핵심 (CSAPP 6.3.1)
- **층 k는 층 k+1의 캐시**: 층 k+1은 블록으로 나뉘고, 층 k는 그 일부의 복사본을 든다. 필요한 블록이 있으면 hit, 없으면 miss다. miss면 블록을 가져오고, 자리가 없으면 피해 블록을 쫓아낸다. 누구를 쫓아낼지가 교체 정책(무작위, LRU)이다
- **miss 셋**: 처음 보는 블록이라 생기는 cold, 자리가 남는데도 배치 정책("블록 i는 자리 i mod 4") 때문에 같은 자리를 다투는 conflict, 작업 집합이 캐시보다 커서 생기는 capacity. 블록 크기가 정해지면 cold miss 수 = 트레이스의 서로 다른 블록 수(오늘 확장)
- **관리 주체**: 레지스터는 컴파일러, L1~L3는 하드웨어, 메인 메모리는 OS + 주소 번역 하드웨어(9장), 웹 캐시는 프록시(11장)
- **트레이스 기반 시뮬레이션**: 캐시는 주소의 열만 보므로, 접근 기록이 있으면 구성과 정책을 바꿔 가며 같은 기록을 몇 번이고 다시 돌릴 수 있다. Cache Lab Part A(D6)가 이것이다
- **lackey**: valgrind가 기계어를 번역하며 접근마다 출력 코드를 끼운다. `I` 명령어 읽기, `L` 읽기, `S` 쓰기, `M` 같은 주소를 읽고 쓰기(시뮬레이터에서는 접근 두 번). 커널 안의 접근은 트레이스에 없다
- **손으로 먼저**: 예측 전에 6.3.1의 예(자리 4개, i mod 4, 블록 0, 8, 0, 8, …)를 따라가고, 개념 문서 6절의 yi.trace 표를 가린 채 (s, E, b) = (4, 1, 4)로 채워 Cache Lab 문서의 `hits:4 misses:5 evictions:3`과 맞춰 본다

자세한 내용: `concepts/d03-caching-and-traces.md`

## 4. 오늘 쓸 Rust 문법
아래 출력은 모두 이 머신(rustc 1.99.1)에서 돌려 본 것이다. 예는 일부러 오늘 과제와 다른 상황에서 골랐다.

1. **데이터 없는 `enum` + `match` + `derive`.** C에서는 `enum state { RUNNING, … }`에 `switch`를 썼고, 모르는 값은 `-1` 같은 약속으로 돌려줬다. Rust는 `match`가 값을 돌려주고, "없음"은 `Option`이다.
   ```rust
   #[derive(Debug, Clone, Copy, PartialEq, Eq)]
   enum ProcState { Running, Sleeping, Zombie }   // /proc/<pid>/stat의 셋째 칸

   fn state_from(c: char) -> Option<ProcState> {
       match c {
           'R' => Some(ProcState::Running),
           'S' => Some(ProcState::Sleeping),
           'Z' => Some(ProcState::Zombie),
           _ => None,
       }
   }
   state_from('Z')                              // Some(Zombie)
   state_from('X')                              // None
   state_from('R') == Some(ProcState::Running)  // true
   ```
   `derive`를 빼고 테스트에서 `assert_eq!(state_from('R'), Some(ProcState::Running))`라고 쓰면 컴파일 오류가 난다: `E0369`(`==`를 `Option<ProcState>`에 쓸 수 없음), `E0277`(`ProcState`가 `Debug`를 구현하지 않음). `assert_eq!`는 `==`로 비교하고, 다르면 `{:?}`로 두 값을 찍기 때문이다. `rustc --explain E0369`. `Copy`가 있으면 C의 enum처럼 값을 복사해 넘긴다.

2. **`Result<Option<T>, E>`: 셋 중 하나.** C라면 "1 찾음, 0 건너뜀, −1 오류"를 반환값으로 약속하고 결과는 포인터 인자로 내보냈다. Rust는 세 경우가 타입에 다 드러난다.
   ```rust
   // fstab 한 줄 → 마운트 항목 / 주석이나 빈 줄 / 깨진 줄
   fn parse_mount(line: &str) -> Result<Option<Mount>, MountError>

   match parse_mount(line) {
       Ok(Some(m)) => mounts.push(m),
       Ok(None) => {}                   // 건너뜀
       Err(e) => return Err(/* e에 맥락을 붙인 오류 */),
   }
   ```
   `parse_mount(line)?`라고 쓰면 `?`는 `Err`만 꺼내 위로 보내고, 남는 값은 `Option<Mount>`다.

3. **`lines()`와 줄 번호.** C의 `fgets` 루프에서는 줄 번호를 직접 셌다. Rust는 `enumerate()`가 (번호, 원소) 쌍을 준다. **번호는 0부터**다.
   ```rust
   let text = "# hosts\n127.0.0.1 localhost\n\n::1 ip6-localhost\n";
   for (i, line) in text.lines().enumerate() {
       println!("{i}: {line:?}");
   }
   // 0: "# hosts"
   // 1: "127.0.0.1 localhost"
   // 2: ""
   // 3: "::1 ip6-localhost"

   // 주석과 빈 줄을 뺀 줄들의 (번호 + 1)
   text.lines().filter(|l| !l.is_empty() && !l.starts_with('#')).enumerate()       // 1, 2  ← 거른 뒤에 셌다
   text.lines().enumerate().filter(|(_, l)| !l.is_empty() && !l.starts_with('#'))  // 2, 4  ← 세고 나서 걸렀다
   ```
   편집기의 줄 번호는 아래쪽이다. 그 밖에: `"a\r\nb".lines()` → `["a", "b"]`(CRLF의 `\r`도 뗀다), `"a\n".lines()` → `["a"]`(끝의 줄 바꿈은 빈 줄을 만들지 않는다), `"a\n\n".lines()` → `["a", ""]`, `"".lines()` → `[]`.

4. **칸 나누기.** C에서는 `strtok`이나 `sscanf`를 썼다. Rust의 `&str`에는 자르는 메서드가 많고, 모두 원래 문자열을 빌려 보는 조각을 준다(복사 없음).
   ```rust
   let req = "GET  /index.html   HTTP/1.0";      // 칸 사이 공백이 여러 개
   req.split(' ')              // ["GET", "", "/index.html", "", "", "HTTP/1.0"]   ← 빈 칸이 생긴다
   req.split_whitespace()      // ["GET", "/index.html", "HTTP/1.0"]
   "  MemTotal:  16115184 kB \r".trim()   // "MemTotal:  16115184 kB"   (\r도 공백이다)
   "PORT=8080".split_once('=') // Some(("PORT", "8080"))
   "PORT".split_once('=')      // None
   "a=b=c".split_once('=')     // Some(("a", "b=c"))   첫 번째 '='에서만 자른다
   "PORT=".split_once('=')     // Some(("PORT", ""))   오른쪽이 빈 문자열이다

   let mut words = "GET /".split_whitespace();
   words.next()                // Some("GET")
   words.next()                // Some("/")
   words.next()                // None
   "   ".split_whitespace().next()   // None
   ```
   `split`, `split_whitespace`는 반복자다. `next()`가 `None`이면 칸이 더 없다는 뜻이다. 칸이 모자라거나 남는지 확인하는 방법은 여럿이다.

5. **문자열 → 수.** C의 `strtoull(s, &end, 16)`은 `0x`도 받고, 어디서 멈췄는지는 `end`로 직접 확인해야 했다. Rust는 문자열 전체가 수가 아니면 `Err`다.
   ```rust
   u64::from_str_radix("dead", 16)               // Ok(57005)
   u64::from_str_radix("DEAD", 16)               // Ok(57005)    대문자도 받는다
   u64::from_str_radix("0xdead", 16)             // Err(ParseIntError { kind: InvalidDigit })   0x는 받지 않는다
   u64::from_str_radix("", 16)                   // Err(ParseIntError { kind: Empty })
   u64::from_str_radix("10000000000000000", 16)  // Err(ParseIntError { kind: PosOverflow })    17자리 = 2^64
   u64::from_str_radix("ffffffffffffffff", 16)   // Ok(18446744073709551615)
   u64::from_str_radix("+dead", 16)              // Ok(57005)    + 부호는 받는다(오늘은 범위 밖)
   u64::from_str_radix("-1", 16)                 // Err(ParseIntError { kind: InvalidDigit })
   "0042".parse::<u64>()                         // Ok(42)       parse는 10진수다
   format!("{:#x} {:#x}", 0u64, 57005u64)        // "0x0 0xdead"
   ```
   `ParseIntError`를 `{}`로 찍으면 `invalid digit found in string`, `cannot parse integer from empty string`, `number too large to fit in target type`이다. 메시지에는 받은 글자를 함께 담는다(PRINCIPLES 2-3).

6. **"아직 없음"은 `Option`으로.** C에서는 최솟값을 `UINT64_MAX`로 시작하는 식의 약속값을 썼다. 그러면 "아무것도 못 봤다"와 "진짜 값이 그것이다"를 구별할 수 없어서 `bool`을 하나 더 들고 다녔다. Rust는 `Option<u64>` 하나로 둘 다 담는다.
   ```rust
   [3u64, 9, 4].iter().max()   // Some(9)
   [0u64; 0].iter().max()      // None    빈 것의 최댓값은 없다
   None < Some(0)              // true    Option끼리 비교하면 None이 가장 작다
   None.min(Some(5))           // None    ← 그래서 Option끼리 min을 하면 계속 None이다
   None.max(Some(5))           // Some(5)
   ```
   `Option`을 갱신할 때는 `match`로 `None`과 `Some`을 나누는 것이 가장 분명하다. 출력할 때도 `match`로 `Some(v)`면 `{v:#x}`, `None`이면 `-`를 쓴다.

7. **파일 읽기 두 가지.** C에서는 `fopen` + `fgets` 루프였다.
   ```rust
   let text = fs::read_to_string(path)?;           // 파일 전체가 String 하나. text.lines()는 빌려 보므로 줄마다 할당이 없다
   let reader = BufReader::new(File::open(path)?);
   for line in reader.lines() {                    // 줄마다 io::Result<String>. 줄마다 새 String을 만든다
       let line = line?;
   }
   ```
   이 머신에서 확인한 오류: 디렉터리는 `fs::read_to_string("/etc")`가 `Is a directory (os error 21)`이다. `File::open("/etc")`는 성공하고 첫 읽기에서 같은 오류가 난다. UTF-8이 아닌 파일은 `read_to_string`이 `stream did not contain valid UTF-8`(종류 `InvalidData`)이고, `BufRead::lines`는 그 줄에서 같은 오류를 낸다. 없는 파일은 `No such file or directory (os error 2)`다. `ls` 트레이스는 수 MB라 어느 쪽이든 된다.

8. **`HashSet` (확장).** C라면 해시 테이블을 직접 짰을 일이다.
   ```rust
   use std::collections::HashSet;
   let mut seen = HashSet::new();
   seen.insert("10.0.0.1")   // true   새로 들어갔다
   seen.insert("10.0.0.1")   // false  이미 있었다
   seen.insert("10.0.0.2")   // true
   seen.len()                // 2
   ```

## 5. 흔한 함정
1. **줄 번호가 0부터이거나, 건너뛴 줄을 안 센다.** `enumerate()`는 0부터 세고, 거른 뒤에 `enumerate()`하면 건너뛴 줄이 번호에서 빠진다(문법 3). check.sh의 `e-lineno.trace:5`가 잡는다
2. **`split(' ')`.** lackey의 `I  0401f540,3`은 `I` 뒤 공백이 둘이라 빈 칸이 생기고, ` L …`은 앞 공백 때문에 첫 칸이 빈 문자열이다(문법 4)
3. **최솟값을 0이나 `u64::MAX`로 시작하기.** 0으로 시작하면 `min`이 언제나 `0x0`이고, 약속값으로 시작하면 데이터 접근이 없을 때 `-` 대신 그 값이 나온다. `Option`끼리 `min`을 하면 `None`이 이긴다(문법 6)
4. **`I` 줄을 주소 범위에 넣기.** 명세 F4는 데이터 접근(`L`·`S`·`M`)만 본다. check.sh의 `order.trace`와 `instr.trace`가 잡는다
5. **주소를 `parse::<u64>()`로 읽기.** `parse`는 10진수라 `1ffefffe78` 같은 주소는 오류가 나지만, `10`이나 `210`처럼 숫자만 있는 주소는 **10진수로 조용히 잘못** 읽힌다(0x10이 아니라 10). check.sh의 `yi.trace`가 잡는다

## 6. 예측 (구현 전에 README `예측:`에)
먼저 말 세 개를 정리한다(자세한 것은 개념 문서 5절).
- **트레이스**: 프로그램이 도는 동안 한 메모리 접근을 일어난 순서대로 한 줄씩 적은 기록이다. valgrind가 만들어 준다. "`ls` 트레이스"는 `ls` 명령을 한 번 돌리며 남긴 기록이다
- **`I` 줄**: 명령어 하나를 메모리에서 읽어 온 것이다. 명령어를 하나 실행할 때마다 한 줄이 생기므로 `I` 줄 수 = 실행한 명령어 수다
- **데이터 접근**(`L`·`S`·`M` 줄): 그 명령어가 메모리 피연산자를 읽거나 쓴 것이다. 3장의 명령으로 보면 이렇다

| 명령 | 트레이스에 남는 것 |
|---|---|
| `add %rbx,%rax`, `cmp`, `jne`, `lea 8(%rdi),%rax` | `I` 하나뿐이다(레지스터만 쓰거나 주소만 계산한다) |
| `mov 8(%rsp),%rax`, `pop %rbx`, `ret` | `I` + `L`(메모리에서 읽는다) |
| `mov %rax,(%rdi)`, `push %rbx`, `call f` | `I` + `S`(메모리에 쓴다) |
| `addq $1,(%rdi)` | `I` + `M`(같은 곳을 읽고 쓴다) |

1. 3장에서 읽은 어셈블리를 떠올리면 명령 몇 개 중 하나꼴로 메모리를 건드렸나? 그 감으로 `ls` 트레이스의 `instr ÷ (load + store + modify)`를 고르고, 이유를 한 줄 붙인다. (가) 1배 안팎: 거의 모든 명령이 메모리를 건드린다 (나) 2~4배 (다) 5~10배 (라) 10배 넘게
2. `/bin/true`는 아무 일도 하지 않고 종료 코드 0만 돌려주는 명령이다(`true; echo $?` → `0`). 인자 없이 부르면 C로 치면 거의 `int main(void) { return 0; }`다. 이 프로그램을 한 번 실행하는 동안 CPU가 실행하는 명령어(`I` 줄)는 몇 개쯤일까? (가) 100개 미만 (나) 수백~수천 (다) 수만 (라) 10만 넘게. C 프로그램에서 `main` 앞뒤로 실행되는 코드가 있는지, 있다면 무슨 일을 하는지 떠올려 이유를 한 줄 붙인다

## 7. 진행
0. 예측 두 개를 README `예측:`에 먼저 적는다. lackey가 트레이스 끝에 찍는 요약(`guest instrs`)에 답이 들어 있으니, 트레이스를 만들기 전에 적는다
1. `sudo apt install valgrind` → `valgrind --version`(apt 후보는 3.22.0)
2. 트레이스 만들기와 눈으로 보기:
   ```sh
   valgrind --tool=lackey --trace-mem=yes --log-file=scratch/ls.trace ls
   valgrind --tool=lackey --trace-mem=yes --log-file=scratch/true.trace /bin/true
   head -n 12 scratch/ls.trace; tail -n 5 scratch/ls.trace
   ```
3. `src/trace.rs`: `Op`, `Access`, `ParseError`, `parse_line` + 테스트 4개 → `main.rs`에 `mod trace;` → `cargo test -p trace-parse`
4. `main`: 인자 → 파일 읽기 → 줄 번호를 붙여 `parse_line` → 개수·`min`·`max` → `BufWriter`로 여섯 줄
5. 오류 E1~E4. E3의 경로와 줄 번호는 `parse_line` 밖(부르는 쪽)에서 붙인다(PRINCIPLES 2-3)
6. `./days/d03-trace-parse/check.sh`
7. `cargo run -q -p trace-parse -- scratch/ls.trace`, `cargo run -q -p trace-parse -- scratch/true.trace`로 예측 1·2를 확인한다. `instr`는 `grep 'guest instrs' scratch/ls.trace`(lackey의 요약)와 같아야 한다. 참조 구현은 이 머신의 `ls` 트레이스(약 9MB)를 debug 빌드로 약 0.7초, release로 약 0.06초에 읽었다. 이보다 몇 배 넘게 느리면 줄마다 하는 일 중에 무거운 것(`format!`, `to_string`, `collect`)이 있는지 본다(PRINCIPLES 5-1)
8. 기록: 예측 / 결과 / 배운 것과 숫자 세 개. 결과 줄에 환경 한 줄(`lscpu | grep 'Model name'`, `uname -r`, `valgrind --version`)을 붙인다

- 90분이 넘으면 그 상태로 커밋한다. 컴파일이 안 되면 끝에 `(WIP)`
- 15분 넘게 막히면 "힌트 1". 끝나면 `./days/d03-trace-parse/check.sh` → "D3 리뷰"
