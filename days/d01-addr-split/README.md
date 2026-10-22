# D1 - addr-split

## 명세

### 목적
캐시 구성(S, E, B, m)과 주소를 받아, 그 주소를 tag · set index · block offset으로 나눠 보여 주는 도구.
캐시가 주소를 어떻게 읽는지(CSAPP 6.4.1~6.4.2)를 비트 단위로 눈으로 확인한다.
여기서 만드는 `Geometry::split`은 D4 lru-set과 D6 cachesim에서 그대로 다시 쓰고, D7에서는 같은 세트에 몰리는 주소를 고를 때, D29·D32에서는 가상 주소를 VPN·VPO와 4단계 인덱스로 나눌 때 같은 방법을 쓴다.
Rust로는 정수 타입(u32·u64·u128), 시프트와 마스크, 넘침(overflow) 처리, 16진수 파싱, `{:#x}`·`{:b}` 포맷을 익힌다.

### 사용법
```
addr-split <주소> -s <s> -E <E> -b <b> [-m <m>]
```
- `<주소>`: `0x`나 `0X`로 시작하면 16진수(대소문자 무관), 아니면 10진수. 값이 u64에 들어가면 자릿수는 상관없다(`0x0000000000000000007`도 된다)
- `-s` 세트 인덱스 비트 수(S = 2^s), `-E` 세트당 줄 수, `-b` 블록 오프셋 비트 수(B = 2^b), `-m` 주소 비트 수(기본 64). 모두 10진수
- 옵션과 주소는 어떤 순서로 와도 된다. 옵션 이름은 대소문자를 가린다(`-E`와 `-e`는 다르다)
- 옵션 바로 뒤의 인자는 `-`로 시작해도 그 옵션의 값이다(`-s -1`에서 `-1`은 `-s`의 값)
- 같은 옵션을 두 번 주면 마지막 값을 쓴다. 앞의 값이 잘못됐을 때(`-s abc -s 4`) 오류로 보든 마지막 값만 보든 자유다(check.sh는 넣지 않는다)

### 기능
- F1. 주소를 해석한다(16진수·10진수). 주소는 m비트 안에 들어가야 한다(주소 < 2^m)
- F2. t = m − s − b를 구하고, 주소를 위에서부터 tag(t비트) | set(s비트) | offset(b비트)으로 나눈다
- F3. S = 2^s, B = 2^b, C = S × E × B를 구한다. S, B, C는 u64에 안 들어갈 수 있다(s + b = 64이면 S × B = 2^64). 넘치지 않게 계산해 맞는 값을 쓴다
- F4. 아래 형식으로 6줄을 쓴다
- F5. 값의 경계: m은 1~64, s와 b는 0 이상이고 s + b ≤ m(t = 0도 된다), E는 1 이상(2의 거듭제곱이 아니어도 된다. 이 머신의 L3는 12-way다)

### 출력 형식
줄마다 앞의 이름을 8칸 왼쪽 정렬하고 바로 값을 쓴다.
```
address <주소> (m=<m>)
bits    <tag 비트>|<set 비트>|<offset 비트>
tag     <tag> (t=<t>)
set     <set> (s=<s>)
offset  <offset> (b=<b>)
cache   S=<S> E=<E> B=<B> C=<C>
```
- 주소, tag, set, offset은 `{:#x}` 형식이다: `0x`를 붙인 소문자 16진수, 앞의 0은 없음, 0은 `0x0`
- bits 줄은 각 필드를 그 필드의 폭(t, s, b)만큼의 2진수로 앞을 0으로 채워 쓰고 `|`로 잇는다. 폭이 0인 필드는 빈 문자열이다. 그래서 `|`는 언제나 2개이고 이 줄의 길이는 8 + m + 2다
- S, E, B, C는 10진수

### 출력 예시 (참조 구현으로 확인)
```
$ addr-split 0x7ff000a4 -s 4 -E 2 -b 5
address 0x7ff000a4 (m=64)
bits    0000000000000000000000000000000001111111111100000000000|0101|00100
tag     0x3ff800 (t=55)
set     0x5 (s=4)
offset  0x4 (b=5)
cache   S=16 E=2 B=32 C=1024
$ addr-split 0xdeadbeef -m 32 -s 0 -E 32 -b 5
address 0xdeadbeef (m=32)
bits    110111101010110110111110111||01111
tag     0x6f56df7 (t=27)
set     0x0 (s=0)
offset  0xf (b=5)
cache   S=1 E=32 B=32 C=1024
$ addr-split 0x2000 -m 13 -s 3 -E 2 -b 2
addr-split: address 0x2000 does not fit in m=13 bits
$ echo $?
1
```
두 번째는 S = 1인 완전 연관(fully associative) 캐시라 set 필드가 비어 있다(m = 32, C = 1024, B = 32, E = 32. CSAPP 3판 연습문제 6.9의 세 번째 캐시).

### 오류 처리 (잘못된 입력에 패닉 금지)
모든 오류는 표준 에러에 `addr-split: `로 시작하는 한 줄을 쓰고 종료 코드 1로 끝난다. 표준 출력은 비어 있다. 아래 메시지는 예시이고, 굵게 적은 맥락은 꼭 담는다(PRINCIPLES 2-3).
- E1. 사용법: 인자 없음, 주소 없음, 주소가 2개 이상 → **`usage`**
  - 예: `addr-split: usage: addr-split <address> -s <s> -E <E> -b <b> [-m <m>]`
- E2. 옵션: 모르는 옵션(`-x`, `-S`, `-e`, `-`로 시작하는 나머지 전부), 옵션 뒤에 값이 없음, `-s`·`-E`·`-b` 중 빠진 것 → **그 옵션 이름**
  - 예: `addr-split: unknown option '-e'`, `addr-split: -b needs a value`, `addr-split: missing -E`
- E3. 값: 정수가 아님, 타입에 안 들어감, 범위 밖(`-E 0`, `-m 0`, `-m 65`), UTF-8이 아님 → **옵션 이름과 받은 값 그대로**
  - 예: `addr-split: -s: invalid value 'abc'`
- E4. 구성: s + b > m → **s, b, m 값 모두**
  - 예: `addr-split: s + b exceeds m (s=8, b=6, m=13)`
  - `-s 4294967295 -b 1`도 패닉 없이 이 오류다(더하다가 넘치면 안 된다)
- E5. 주소: 해석할 수 없음(`0xZZ`, `0x`, `12a`, 빈 문자열, u64를 넘는 값, UTF-8이 아닌 인자), 또는 m비트에 안 들어감 → **받은 주소**
  - 예: `addr-split: invalid address '0xZZ'`, `addr-split: address 0x2000 does not fit in m=13 bits`
- E6. 출력 실패(`addr-split ... > /dev/full`) → `addr-split:`로 시작하는 메시지
- 오류가 여럿 겹치면 어느 것을 보고해도 된다. check.sh는 한 번에 하나만 넣는다

### 제약
- std만 사용. 외부 크레이트와 unsafe는 쓰지 않는다
- 인자는 `std::env::args_os`로 받는다. UTF-8이 아닌 인자에서 패닉하지 않는다(E5, PRINCIPLES 2-5)
- 주소 분해는 `src/geometry.rs` 모듈에 둔다. 공개 API는 아래와 같다
  ```rust
  pub struct Geometry { pub m: u32, pub s: u32, pub e: u64, pub b: u32 }
  pub struct Parts { pub tag: u64, pub set: u64, pub offset: u64 }
  impl Geometry {
      /// s + b ≤ m ≤ 64이고 addr < 2^m이라고 가정한다(검사는 부르는 쪽이 한다).
      pub fn split(&self, addr: u64) -> Parts;
  }
  ```
  S, B, C를 어디서 계산할지는 자유다(`Geometry`의 메서드를 권한다)
- 같은 파일의 `#[cfg(test)] mod tests`에 `split`을 검사하는 `#[test]`를 3개 이상 둔다: 위 출력 예시의 첫 번째, s = 0, s + b = m = 64(t = 0). 공용 헬퍼를 거쳐 불러도 된다
- 오류 종류는 enum으로, 메시지는 `Display` 한 곳에서 만든다(PRINCIPLES 2-2)
- `println!`은 쓰기에 실패하면 패닉한다. 출력은 `writeln!`으로 쓰고 끝에서 `flush`한다(E6, PRINCIPLES 5-2)

### 완료 기준
```sh
./days/d01-addr-split/check.sh
```
- 마지막 줄이 `FAIL 0`이고 종료 코드 0이면 완료
- 비교할 실제 도구가 없어서, 기대 출력은 참조 구현으로 만들어 check.sh에 적었다
- 정상 케이스는 표준 출력 전체, 빈 표준 에러, 종료 코드 0을 본다. 오류 케이스는 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄(`addr-split: `로 시작, 맥락 포함), 패닉 없음을 본다 (PRINCIPLES 6-2)
- 경계값: 주소 0, 1, 2^m − 1, 2^m, u64 최댓값, u64 + 1 / m = 1, 64, 0, 65 / s = 0, b = 0, t = 0, s = 64, b = 64, s + b = m + 1 / E = 1, u64 최댓값(C가 u64를 넘음), 0
- `cargo test -p addr-split`에서 geometry 모듈의 테스트 3개 이상이 통과해야 한다
- FAIL이면 그 아래에 어느 쪽(stdout/stderr/종료 코드)이 어떻게 다른지 나온다

### 범위 밖
`+` 부호, `_` 자릿수 구분, `0o`·`0b` 접두사, 긴 옵션(`--sets`), `--`, `-h`. check.sh는 이것들을 넣지 않는다(`+5`를 받아도 틀린 것은 아니다).

### 확장
- 같은 세트 주소 만들기 `-n <N>`: 6줄 뒤에 주소와 set·offset이 같고 tag만 1, 2, …, N만큼 큰 주소를 한 줄에 하나씩 `same    <주소>`(`{:#x}`)로 쓴다. m비트를 넘는 주소가 나오면 거기서 멈춘다(N개보다 적어도 된다. t = 0이면 0줄). N은 0 이상의 정수이고, 아니면 E3. D7 충돌 실험에 쓴다. `EXT=1 ./days/d01-addr-split/check.sh`로 확인
- 이 머신의 캐시로 해 보기: `/sys/devices/system/cpu/cpu0/cache/index0/`의 `number_of_sets`, `ways_of_associativity`, `coherency_line_size`를 보고 L1d의 s, E, b를 정해 C가 `size`와 같은지 확인한다(index0~3이 L1d, L1i, L2, L3)

## 기록
- 예측: 8(tag) 3(set) 2(offset) 1110001|101|00, cache줄만 바뀜, E증가와 C증가는 비례
- 결과: 정답
- 배운 것: 러스트 문법은 거지같다
- 재미(1~5):3 - 막힌 시간(분):too much time - 힌트 단계(0~3):0
