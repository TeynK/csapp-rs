# D3 - trace-parse

## 명세

### 목적
valgrind lackey가 만든 메모리 접근 트레이스를 읽어, 연산(I·L·S·M)별 줄 수와 데이터 접근 주소의 범위를 출력하는 도구.
캐시가 보는 것은 프로그램이 아니라 주소의 열이다. 그래서 캐시 시뮬레이터는 프로그램을 돌리지 않고, 프로그램이 남긴 접근 트레이스를 입력으로 받는다(CSAPP 6.3.1의 hit·miss를 트레이스로 재현한다. Cache Lab Part A가 이 방식이다).
오늘 만드는 파서는 D6 cachesim의 입력부가 된다. D7에서는 직접 기록한 전치 함수의 트레이스를, D34 vmsim에서는 페이지 단위 트레이스를 같은 형식으로 읽는다.
Rust로는 `enum Op`, `struct Access`, `match`, `Option`·`Result`, `?`, `lines()`·`split`, 오류에 줄 번호 붙이기를 익힌다.

### 사용법
```
trace-parse <트레이스 파일>
```
- 인자는 파일 경로 하나다. 옵션은 없다(확장의 `-w`만 예외). `-`로 시작하는 인자는 옵션으로 보고 E1 오류다
- 트레이스 만들기(`sudo apt install valgrind`가 먼저다):
  ```
  valgrind --tool=lackey --trace-mem=yes --log-file=scratch/ls.trace ls
  cargo run -q -p trace-parse -- scratch/ls.trace
  ```
  `--log-file`을 주면 lackey가 쓰는 것(트레이스와 `==PID==` 메시지)은 파일로 가고, `ls`의 출력은 그대로 화면에 나온다. 트레이스는 1MB가 넘으므로 `scratch/`에 둔다(RULES.md)

### 트레이스 형식
lackey는 이렇게 쓴다(이 머신의 valgrind 3.22.0으로 `/bin/true`를 돌려 얻은 줄들이다. `…`는 줄을 건너뛴 곳, 오른쪽 설명은 붙인 것):
```
==469889== Lackey, an example Valgrind tool     valgrind의 메시지
…
I  0401f540,3                                   명령어 읽기: 주소 0x401f540에서 3바이트
I  0401f543,5
 S 1fff000028,8                                 데이터 쓰기: 8바이트
…
I  04020211,7
 M 04038e06,1                                   데이터 수정: 같은 주소를 읽고 쓰기, 1바이트
…
I  048dfac0,1
 L 1ffefffea8,8                                 데이터 읽기: 8바이트
```
- 접근 줄은 `<연산> <주소>,<크기>`다. 연산과 주소 사이에는 공백이 하나 이상 있다. 줄 앞뒤의 공백은 무시한다. lackey는 `I` 뒤에 공백 둘, `L`·`S`·`M` 앞뒤에 공백 하나를 쓰고, Cache Lab 문서와 그 트레이스는 `I 0400d7d4,8`, ` L 10,1`처럼 쓴다. 모두 받는다
  - 연산: `I`(명령어 읽기), `L`(데이터 읽기), `S`(데이터 쓰기), `M`(데이터 수정 = 같은 주소를 읽은 뒤 쓰기). 대문자 한 글자
  - 주소: 16진수 숫자만(`0x` 없음, 대소문자 모두). 자릿수는 상관없고, 값이 2^64 미만이어야 한다
  - 크기: 10진수 숫자만, 1 이상, `u64`에 들어가는 값
- 줄 끝은 `\n`이다. Windows식 `\r\n`도 받는다(`\r`은 줄 끝의 공백으로 본다). 마지막 줄 끝에 줄 바꿈이 없어도 그 줄을 읽는다
- 건너뛸 줄: 앞뒤 공백을 뺀 내용이 비었거나 `==`로 시작하는 줄(valgrind의 메시지)
- 그 밖의 줄은 모두 잘못된 줄이다(E3): 연산·주소·크기가 위와 다름, 쉼표가 없음, 칸이 모자라거나 남음(` L10,1`, ` L 10,1 x`, ` L 10, 1`)

### 기능
- F1. 인자를 해석한다(경로 하나).
- F2. 파일을 줄 단위로 읽어 `trace::parse_line`으로 해석한다. 건너뛸 줄은 건너뛴다.
- F3. 연산별로 줄 수를 센다. `M`도 한 줄을 1로 센다.
- F4. 데이터 접근(`L`·`S`·`M`)의 주소 최솟값과 최댓값을 구한다. 줄에 적힌 주소만 보고 크기는 보지 않는다. `I` 줄은 수만 세고 주소 범위에는 넣지 않는다.
- F5. 잘못된 줄을 만나면 거기서 멈추고 그 줄 번호로 오류를 낸다(E3). 줄 번호는 1부터 세고, 건너뛴 줄도 센다(편집기의 줄 번호와 같다).

### 출력 형식
```
instr <I 줄 수>
load <L 줄 수>
store <S 줄 수>
modify <M 줄 수>
min <데이터 주소 최솟값>
max <데이터 주소 최댓값>
```
- 이름과 값 사이는 공백 하나다. 수는 10진수, 주소는 `0x`를 붙인 소문자 16진수이고 앞에 0을 채우지 않는다(`{:#x}`: `0x0`, `0x421c7f0`)
- 데이터 접근이 하나도 없으면(빈 파일, `I` 줄만 있는 파일) `min -`, `max -`
- 표준 에러는 비어 있고 종료 코드는 0이다

### 출력 예시 (참조 구현으로 확인)
```
$ cat writeup.trace                 # Cache Lab 문서 4.1절의 예
I 0400d7d4,8
 M 0421c7f0,4
 L 04f6b868,8
 S 7ff0005c8,8
$ trace-parse writeup.trace
instr 1
load 1
store 1
modify 1
min 0x421c7f0
max 0x7ff0005c8
$ trace-parse empty.trace           # 빈 파일
instr 0
load 0
store 0
modify 0
min -
max -
$ printf '==1== hi\n L 10,1\n S zz,8\n L 20,1\n' > bad.trace
$ trace-parse bad.trace; echo "exit=$?"
trace-parse: bad.trace:3: invalid address 'zz'
exit=1
```

### 오류 처리 (잘못된 입력에 패닉 금지)
모든 오류는 표준 에러에 `trace-parse: `로 시작하는 한 줄을 쓰고 종료 코드 1로 끝난다. 표준 출력은 비어 있다. 아래 메시지는 예시이고, 굵게 적은 맥락은 꼭 담는다(PRINCIPLES 2-3).
- E1. 사용법: 인자가 없음, 경로가 둘 이상, `-`로 시작하는 인자(`-`, `--` 포함) → **`usage`**(소문자. check.sh는 대소문자를 가린다)
  - 예: `trace-parse: usage: trace-parse <trace-file>`
- E2. 읽기: 파일이 없음, 디렉터리, 읽기 권한이 없음, UTF-8이 아님 → **경로**
  - 예: `trace-parse: nofile.trace: No such file or directory (os error 2)`
  - UTF-8이 아닌 내용은 E2로 보고해도 되고, 그 줄의 E3로 보고해도 된다. 어느 쪽이든 경로를 담는다
- E3. 해석: 형식에 맞지 않는 첫 줄 → **`경로:줄 번호: 이유`** 형식. 컴파일러 오류와 같은 GNU 형식이다
  - 예: `trace-parse: bad.trace:3: invalid address 'zz'`, `trace-parse: t.trace:1: unknown operation 'X'`
  - 이유는 비어 있으면 안 된다. 무엇이 틀렸는지 받은 글자 그대로 담기를 권한다
- E4. 출력 실패(`trace-parse writeup.trace > /dev/full`) → `trace-parse:`로 시작하는 메시지
- 잘못된 줄이 여럿이면 가장 앞의 것만 보고한다. check.sh는 다른 종류의 오류를 한 번에 하나만 넣는다

### 제약
- std만 쓴다. 외부 크레이트와 unsafe는 쓰지 않는다
- 인자는 `std::env::args_os`로 받는다
- 파서는 `src/trace.rs` 모듈에 둔다. 공개 API는 아래와 같다. `ParseError`는 직접 정의한다(variant는 자유)
  ```rust
  /// 트레이스 한 줄의 연산
  pub enum Op {
      Instr,  // I
      Load,   // L
      Store,  // S
      Modify, // M
  }

  /// 트레이스 한 줄이 나타내는 접근
  pub struct Access {
      pub op: Op,
      pub addr: u64,
      pub size: u64,
  }

  /// 트레이스 한 줄을 해석한다. 건너뛸 줄(빈 줄, `==`로 시작하는 줄)이면 Ok(None)이다.
  /// 이 함수는 줄 번호도 파일 경로도 모른다. 그 맥락은 부르는 쪽이 붙인다.
  pub fn parse_line(line: &str) -> Result<Option<Access>, ParseError>;
  ```
- 같은 파일의 `#[cfg(test)] mod tests`에 `parse_line`을 검사하는 `#[test]`를 4개 이상 둔다: lackey의 I 줄(`"I  0401f540,3"`), 데이터 줄(`L`·`S`·`M` 중 하나 이상), 건너뛸 줄(`==` 줄과 빈 줄), 잘못된 줄(하나 이상). 앞의 셋은 `assert_eq!`로 `Ok(Some(Access { … }))`·`Ok(None)`과 통째로 비교한다. 그러려면 세 타입에 무엇이 있어야 하는지는 컴파일러가 알려 준다
- 파일은 통째로 읽어도(`fs::read_to_string`) 줄씩 읽어도(`BufRead::lines`) 된다
- 오류 종류는 enum으로, 메시지는 `Display` 한 곳에서 만든다(PRINCIPLES 2-2). 출력은 `writeln!`으로 쓰고 끝에서 `flush`한다(PRINCIPLES 5-2)

### 완료 기준
```sh
./days/d03-trace-parse/check.sh
```
- 마지막 줄이 `FAIL 0`이고 종료 코드가 0이면 완료다. check.sh는 debug로 빌드한다. 참조 구현으로 돌리면 빌드를 빼고 1~2초 걸렸다
- 정상 케이스는 작은 트레이스 파일을 만들어 표준 출력 전체를 기대값과 비교하고, 빈 표준 에러와 종료 코드 0을 본다. 기대값은 참조 구현으로 확인했다
- 실제 트레이스: 작은 트레이스가 모두 통과하면, check.sh가 valgrind lackey로 `/bin/true`의 트레이스를 만들어 `grep -c`로 센 연산별 줄 수, `sort`로 찾은 주소 최솟값·최댓값과 내 출력을 비교한다. valgrind가 없으면 FAIL이다
- 오류 케이스는 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄(`trace-parse: `로 시작, 맥락 포함), 패닉 없음을 본다. E3는 첫 줄이 `trace-parse: <파일>:<줄 번호>: <이유>`인지 본다(PRINCIPLES 6-2)
- 경계값: 빈 파일(0줄)·건너뛸 줄만·`I` 줄만·데이터 줄 1개 / 주소 `0`·`ffffffffffffffff`·17자리(2^64)·앞에 0을 붙인 19자리 / 크기 `0`·`1`·2^64−1·2^64 / 줄 번호: 첫 줄·건너뛴 줄 뒤·마지막 줄(끝에 줄 바꿈 없음) / CRLF 줄 끝
- `cargo test -p trace-parse`에서 trace 모듈의 테스트 4개 이상이 통과해야 한다
- 기록: `ls` 트레이스의 출력 여섯 줄과 예측 비교, 예측 2를 위한 `/bin/true` 트레이스의 출력. 결과 줄에 환경 한 줄(`lscpu`의 Model name, `uname -r`, `valgrind --version`)

### 범위 밖
확장의 `-w` 말고는 옵션이 없다. 표준 입력에서 읽기, 여러 파일, `0x`가 붙은 주소를 받아 주기, `+` 부호, 탭·유니코드 공백, 주소 + 크기가 2^64를 넘는지 검사하기, `-w`를 두 번 주기, 빈 문자열 인자. check.sh는 이것들을 넣지 않는다.

### 확장
- `-w`: 데이터 접근(`L`·`S`·`M`)이 건드린 서로 다른 64바이트 블록의 수를 일곱째 줄 `blocks <수>`로 더 쓴다. 블록 번호는 주소 ÷ 64(주소 >> 6)이고, 크기는 보지 않는다. 블록 경계를 넘는 접근도 시작 주소의 블록 하나로 센다(Cache Lab과 같은 가정). `std::collections::HashSet`을 쓴다. `-w`는 경로 앞에 와도 뒤에 와도 된다. `EXT=1 ./days/d03-trace-parse/check.sh`로 확인한다
  - 이 수는 블록이 64바이트인 캐시라면 크기가 아무리 커도 피할 수 없는 cold miss의 수다(개념 문서 3절). `ls` 트레이스의 `blocks × 64`바이트를 L1d(32KiB)·L2(2MiB)와 견주어 기록에 쓴다
- `ls -l /usr/bin`처럼 일을 더 하는 명령의 트레이스와 비교한다

## 기록
- 예측: ① (라) instr가 데이터 접근의 10배 넘게: 분기·계산도 전부 I이고 L·S·M은 늘 I와 함께 나오므로 ② (라) /bin/true도 명령어 10만 개 넘게: main이 단순해도 함수 호출, 메모리 할당, 라이브러리 코드를 불러오는 일이 필요해서
- 결과: ① ls: instr 479708, load 122156, store 45859, modify 1831 → instr ÷ 데이터 접근 = 2.82배(나). 예측 (라)는 틀림. 명령 2.8개마다 데이터 접근 한 번꼴 ② /bin/true: instr 179195(ls의 37%) → (라) 맞음. 그중 98.6%가 ld.so 안의 명령(ls도 79.2%). 데이터 주소 범위 0x108040~0x1fff000feb(ls). check.sh OK 55 · FAIL 0, cargo test 4개 통과. 환경: Intel(R) N150, 6.8.0-147-generic, valgrind-3.22.0, --release
- 배운 것: 메모리 접근이 통상 2~3배가량 이루어 진다는거
- 재미(1~5): 4 - 막힌 시간(분): 100 - 힌트 단계(0~3): 0
