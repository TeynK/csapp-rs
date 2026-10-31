# D4 - lru-set

## 명세

### 목적
캐시의 세트 하나(줄 E개)를 흉내 내는 `CacheSet`과, 태그 열을 받아 그 세트에 차례로 접근해 보는 작은 도구.
직접 사상(E = 1), E-way 집합 연관, 완전 연관(S = 1) 캐시는 모두 "세트 S개 × 세트마다 줄 E개"라는 같은 구조다(CSAPP 6.4.3~6.4.4). 주소의 set index로 세트를 고르고 나면 나머지 일은 그 세트 안에서 끝난다. 줄 매칭(valid이고 tag가 같은 줄 찾기)과, miss일 때 넣을 줄 고르기(빈 줄, 없으면 LRU 줄)다. 세트끼리는 서로 영향을 주지 않으므로, 세트 하나를 정확히 만들면 캐시 전체는 그것을 S개 두면 된다.
오늘 만드는 `CacheSet`은 D6 cachesim의 중심이 된다(세트 S개 = `CacheSet` S개, 3C 분류에 쓰는 같은 용량의 완전 연관 캐시 = 줄 S×E개짜리 `CacheSet` 하나). D34 vmsim의 페이지 교체와 D60 프록시 캐시도 같은 LRU를 다시 쓴다. 그래서 공개 항목에 문서 주석(`///`)과 테스트를 갖춰 둔다(커리큘럼 "개념 재사용 지도").
Rust로는 `struct` + `impl`, `&self`와 `&mut self`, `Vec<Line>`, `iter().position()`, `min_by_key`, `#[test]`, 한 패키지 안의 라이브러리와 바이너리를 익힌다.

### 사용법
```
lru-set -E <줄 수> [<태그>...]
```
- `-E <줄 수>`는 반드시 첫 두 인자다. 줄 수 E는 1 이상 65536(2^16) 이하의 10진 정수다. 이 머신 L2 전체가 32768줄(2MiB ÷ 64B)이니, 캐시 하나를 통째로 한 세트(완전 연관)로 흉내 내도 남는다
- 그 뒤의 인자는 모두 태그다. 태그 하나가 접근 한 번이다. 태그는 0 이상 2^64 − 1 이하의 10진 정수이고, 하나도 없어도 된다
- 이 세트로 오는 접근들의 태그를 순서대로 준다고 보면 된다. 어느 세트로 갈지는 이미 정해졌으니 set index와 offset은 없다
- 예: `cargo run -q -p lru-set -- -E 2 1 2 1 3 2`

### 공개 API (`src/set.rs`)
```rust
/// 접근 한 번의 결과
pub enum Outcome {
    /// 태그가 세트에 있었다
    Hit,
    /// 태그가 없었고, 빈 줄(valid가 false)에 넣었다
    Miss,
    /// 태그가 없었고, 빈 줄이 없어서 LRU 줄을 쫓아내고 넣었다. victim은 쫓겨난 줄의 태그
    MissEvict { victim: u64 },
}

/// 캐시의 세트 하나: 줄 E개와, 그 줄들을 마지막으로 쓴 순서
pub struct CacheSet {
    // 필드는 자유. 줄은 Vec<Line>에 둔다
}

impl CacheSet {
    /// 줄이 lines개이고 모든 줄이 비어 있는(valid가 false) 세트
    pub fn new(lines: usize) -> Self;

    /// tag에 접근한다. 결과가 무엇이든 이 접근 뒤에 tag의 줄은 가장 최근에 쓴 줄이다
    pub fn access(&mut self, tag: u64) -> Outcome;

    /// tag가 세트에 있는지 본다. 쓴 것으로 치지 않으므로 LRU 순서는 그대로다
    pub fn contains(&self, tag: u64) -> bool;
}
```
- 줄 하나를 나타내는 `Line`은 직접 정의하고 공개하지 않는다. valid 비트, 태그, LRU 순서를 정할 값을 담는다. 모양은 자유다
- `new`의 `lines`는 1 이상이다. 0은 부르는 쪽의 버그이므로 패닉해도 된다(PRINCIPLES 2-5). CLI는 E를 검사한 뒤에 `new`를 부른다
- 테스트에서 `assert_eq!`로 `Outcome`을 비교하려면 `Outcome`에 무엇이 있어야 하는지는 컴파일러가 알려 준다(D3의 `Op`·`Access`와 같다)
- 위의 공개 항목에 `///` 문서 주석을 단다(위의 것을 그대로 써도 된다). 공개 API를 바꾸고 싶으면 리뷰 때 이유를 말한다

### 기능
- F1. 인자를 해석한다. 인자를 모두 검사한 뒤에 접근을 시작한다. 그래서 오류가 나면 표준 출력은 비어 있다
- F2. 줄 E개짜리 빈 세트를 만든다(`CacheSet::new`)
- F3. 태그마다 `access`를 부르고 결과를 한 줄씩 쓴다
  - 줄 매칭: valid이고 태그가 같은 줄이 있으면 `Hit`
  - miss이고 빈 줄이 있으면 그 줄에 넣는다(`Miss`). 빈 줄이 여럿이면 어느 것이든 된다
  - miss이고 빈 줄이 없으면 LRU 줄, 즉 마지막으로 쓴 지 가장 오래된 줄을 쫓아내고 그 자리에 넣는다(`MissEvict`)
  - 줄을 "쓴다"는 것은 접근이 그 줄에 닿는 것이다. hit, 그리고 miss로 막 들어온 것이 쓴 것이다. `contains`는 쓴 것이 아니다
- F4. 끝에 hit·miss·쫓아내기 횟수를 한 줄로 쓴다. misses는 `Miss`와 `MissEvict`를 합친 수이고, evictions는 `MissEvict`의 수다(Cache Lab의 csim과 같은 셈법이다. 쫓아낸 접근도 miss다)

### 출력 형식
```
<태그> hit
<태그> miss
<태그> miss eviction <쫓겨난 태그>
…
hits:<수> misses:<수> evictions:<수>
```
- 접근마다 한 줄, 접근한 순서대로. 태그와 수는 10진수(`{}`)다
- 요약 줄은 늘 있다. 태그가 하나도 없으면 요약 줄만 나온다
- 표준 에러는 비어 있고 종료 코드는 0이다

### 출력 예시 (참조 구현으로 확인)
```
$ lru-set -E 2 1 2 1 3 2          # 1이 hit으로 최근에 쓴 줄이 되어, 3은 2를 쫓아낸다
1 miss
2 miss
1 hit
3 miss eviction 2
2 miss eviction 1
hits:1 misses:4 evictions:2
$ lru-set -E 1 0 1 0 1            # 줄이 하나면 두 태그가 번갈아 서로를 쫓아낸다(thrashing)
0 miss
1 miss eviction 0
0 miss eviction 1
1 miss eviction 0
hits:0 misses:4 evictions:3
$ lru-set -E 4                    # 태그가 없으면 요약 줄만
hits:0 misses:0 evictions:0
$ lru-set -E 0 1 2; echo "exit=$?"
lru-set: -E: invalid number of lines '0' (expected 1..=65536)
exit=1
$ lru-set -E 2 1 zz 3; echo "exit=$?"
lru-set: invalid tag 'zz'
exit=1
```

### 오류 처리 (잘못된 입력에 패닉 금지)
모든 오류는 표준 에러에 `lru-set: `로 시작하는 한 줄을 쓰고 종료 코드 1로 끝난다. 표준 출력은 비어 있다. 아래 메시지는 예시이고, 굵게 적은 맥락은 꼭 담는다(PRINCIPLES 2-3).
- E1. 사용법: 인자가 없음, 첫 인자가 `-E`가 아님, `-E` 뒤에 값이 없음 → **`usage`**(소문자. check.sh는 대소문자를 가린다)
  - 예: `lru-set: usage: lru-set -E <lines> [<tag>...]`
- E2. 줄 수: `-E`의 값이 1 이상 65536 이하의 10진 정수가 아님(`0`, `65537`, `-1`, `four`, `0x10`, `2.5`, 빈 문자열, UTF-8이 아닌 값) → **`-E`와 받은 값**
  - 예: `lru-set: -E: invalid number of lines '0' (expected 1..=65536)`
- E3. 태그: 10진 정수가 아니거나 2^64 이상(`zz`, `-1`, `0x10`, `1.5`, `18446744073709551616`, 빈 문자열, UTF-8이 아닌 값) → **받은 값**
  - 예: `lru-set: invalid tag 'zz'`
  - 잘못된 태그가 여럿이면 가장 앞의 것만 보고한다. 그 앞의 태그가 정상이어도 표준 출력은 비어 있다(F1)
- E4. 출력 실패(`lru-set -E 2 1 > /dev/full`) → `lru-set:`로 시작하는 메시지
- 받은 값이 UTF-8이 아니면 `to_string_lossy`로 바꿔 담아도 된다. check.sh는 그런 값에서 종료 코드, 빈 표준 출력, 접두사만 본다
- check.sh는 한 번에 오류를 하나만 넣는다

### 제약
- std만 쓴다. 외부 크레이트와 unsafe는 쓰지 않는다. 인자는 `std::env::args_os`로 받는다
- 한 패키지에 라이브러리와 바이너리를 둔다. D6 cachesim이 같은 모양이다
  - `src/set.rs`: `Outcome`, `CacheSet`, `Line`과 그 테스트
  - `src/lib.rs`: `pub mod set;` (라이브러리 크레이트 `lru_set`의 뿌리)
  - `src/main.rs`: CLI(인자 해석, 출력, 오류). `use lru_set::set::{CacheSet, Outcome};`으로 가져다 쓴다
  - 바이너리만 두고 `main.rs`에 `mod set;`을 쓰면, CLI가 부르지 않는 `contains`에 `dead_code` 경고가 난다(이 머신에서 확인. BRIEF 4절). `#[allow(dead_code)]`로 가릴 수도 있지만, CLI 밖에서도 쓸 공개 API는 라이브러리에 두는 것이 제자리다
  - 라이브러리의 `///` 주석 안에 코드 블록(```` ``` ````)을 쓰면 문서 테스트가 되어 `cargo test`가 컴파일하고 돌린다. 블록 안에서는 바깥 사용자처럼 `use lru_set::set::CacheSet;`부터 써야 한다. 문서 테스트가 실패하면 check.sh의 단위 테스트 항목도 FAIL이다(참조 구현으로 확인)
- `set.rs`의 `#[cfg(test)] mod tests`에 `#[test]`를 3개 이상 둔다. 모두 `access`의 결과를 `assert_eq!`로 `Outcome`과 비교한다
  1. E = 1 충돌: 두 태그가 번갈아 오면 매번 쫓아낸다. `MissEvict`의 `victim`까지 본다
  2. E = 2 LRU 순서: hit이 LRU 순서를 바꾼다. `contains`는 바꾸지 않는다
  3. cold miss: 빈 세트에 서로 다른 태그 E개를 넣으면 모두 `Miss`다(쫓아내기 없음). 태그 0을 넣는다
- 오류 종류는 enum으로, 메시지는 `Display` 한 곳에서 만든다(PRINCIPLES 2-2). `run`은 `Box<dyn Error>`가 아니라 그 enum을 돌려준다(D3 리뷰 2-2)
- 출력은 `BufWriter`에 `writeln!`으로 쓰고 끝에서 `flush`한다(PRINCIPLES 5-2)

### 완료 기준
```sh
./days/d04-lru-set/check.sh
```
- 마지막 줄이 `OK 60 · FAIL 0`이고 종료 코드가 0이면 완료다. check.sh는 debug로 빌드한다. 참조 구현으로 돌리면 빌드를 빼고 약 2.3초 걸렸다(확장까지 `EXT=1`이면 `OK 75 · FAIL 0`, 약 2.5초)
- 단위 테스트: `cargo test -p lru-set`에서 set 모듈의 테스트가 3개 이상 통과하고, 테스트 모듈에 `.access(`와 `.contains(`를 부르는 줄이 있어야 한다
- 정상 케이스는 표준 출력 전체를 기대값과 비교하고, 빈 표준 에러와 종료 코드 0을 본다. 짧은 태그 열의 기대값은 참조 구현으로 확인했고, 긴 태그 열은 LRU의 성질로 만든다(예: 서로 다른 태그를 차례로 주면, 0부터 센 i번째 태그(i ≥ E)는 i − E번째 태그를 쫓아낸다)
- 오류 케이스는 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄(`lru-set: `로 시작, 맥락 포함), 패닉 없음을 본다(PRINCIPLES 6-2)
- 경계값: 태그 0개·1개 / 서로 다른 태그 E−1·E·E+1개 / E = 1·65536·65537·2^64 / 태그 0·2^64−1·2^64 / 태그 2만 개
- check.sh가 보지 않는 것: 커밋 전 `cargo clippy -q --workspace` 경고 0(RULES)
- 기록: 예측 1·2를 확인한 출력(BRIEF.md 7절의 명령)

### 범위 밖
`-E`를 다른 자리에 두기, `-E2`처럼 붙여 쓰기, `+` 부호나 앞의 0이 붙은 수(`+5`, `007`), 공백이 섞인 인자, 표준 입력에서 태그 읽기, 16진 태그. check.sh는 이것들을 넣지 않는다.

### 확장
- `-p <정책>`: 교체 정책을 고른다. `-E <줄 수>` 바로 뒤(셋째·넷째 인자)에 둔다. 정책은 `lru`(기본), `fifo`, `random`
  - FIFO: 가장 먼저 들어온 줄을 쫓아낸다. hit은 순서를 바꾸지 않는다
  - Random: 빈 줄이 없을 때 쫓아낼 줄을 무작위로 고른다. 난수는 외부 크레이트 없이 직접 만든다(xorshift. D5의 확장과 같다)
  - `ReplacementPolicy` 트레잇을 만들어 `CacheSet`이 정책을 갈아끼울 수 있게 한다. 트레잇의 모양은 자유다. 다만 공개 트레잇의 메서드가 비공개 `Line`을 주고받으면 `private_interfaces` 경고가 난다(참조 구현으로 확인). 트레잇에는 줄 번호나 순서 값처럼 공개된 타입만 오가게 한다
  - 정책이 여럿이 되면 위 API의 문서 주석 중 LRU를 전제한 곳(`MissEvict`의 "LRU 줄", `access`의 "가장 최근에 쓴 줄")을 "정책이 고른 줄"처럼 고친다
  - `-p` 뒤에 값이 없으면 E1(**`usage`**), 모르는 정책이면 **`-p`와 받은 값**을 담은 오류(종료 코드 1)
  - `EXT=1 ./days/d04-lru-set/check.sh`로 확인한다. Random은 고를 줄이 하나뿐이거나(E = 1) 쫓아낼 일이 없는 경우만 기대값과 비교하고, 나머지는 결과의 앞뒤가 맞는지만 본다(hit은 세트에 있는 태그에만, 쫓겨나는 태그는 세트에 있던 것, 쫓아내기는 세트가 꽉 찼을 때만)
- 실험: `1 2 3 4 1 2 5 1 2 3 4 5`를 FIFO와 LRU로, E = 3과 E = 4에서 돌려 miss 수를 비교한다. 줄을 늘렸는데 miss가 늘어나는 경우가 있는지 본다

## 기록
- 예측: 
  - 1. (나), 처음 2번 콜드미스에 다음부턴 계속 evict당해서 전부 미스
  - 2. 감이 아에 안오는데, 명령어를 쪼개서 직접 분석해서 돌려야하나..?
- 결과: ① (8,1) 21, (4,2) 30, (2,4) 3, (1,8) 3 miss → (나) 맞음. (4,2)는 블록 0·4·8이 모두 세트 0으로 몰려 줄 2개를 셋이 돌아가며 써서 매번 miss. cold는 2번이 아니라 3번 ② 보기를 고르지 못함. 같은 32KiB에서 8-way 4380 miss(hit 97.45%), 직접 사상 7944 miss(95.37%) → 1.81배 (다). check.sh OK 60 · FAIL 0, cargo test 3개 통과. 환경: Intel(R) N150, 6.8.0-147-generic, --release

- 배운 것: 개신기한 문법이 많다. 대체 저거 언제 익숙해지냐
- 재미(1~5): 4- 막힌 시간(분): 100- 힌트 단계(0~3):0

