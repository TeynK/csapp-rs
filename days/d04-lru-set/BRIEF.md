# D4 브리핑 · lru-set

2026-10-30. 명세는 `README.md`, 개념은 `concepts/d04-associativity-and-lru.md`.

D3에서 넘어온 것:
- 리뷰의 "반드시 고칠 것" 2개는 6e17c25·160cc1a에서 해결됐다(REVIEW.md의 반영 확인). 지금 작업 트리에 D3 README(기록의 `- 예측: - 예측:` 중복을 고친 것)와 REVIEW.md가 커밋되지 않은 채 남아 있다. D4와 섞지 말고 먼저 따로 커밋한다.
- 워크스페이스 clippy 경고 하나(`days/d00-wc-lite/src/counts.rs:22`, `collapsible_match`)가 D1부터 그대로다(오늘 `cargo clippy -q --workspace`로 다시 확인). 고치면 wc-lite만 따로 커밋한다.
- 리뷰 원칙 2-2(`run`이 `Box<dyn Error>`를 돌려줌)는 오늘 명세의 제약에 넣었다. 퀴즈 2가 이것이다.
- `cargo new` 뒤에 `Cargo.lock`에 `lru-set` 항목이 생겼다(워크스페이스가 새 패키지를 알아본 것). D4 커밋에 함께 넣는다.

D3은 막힌 시간 100분, 힌트 0이었다. 오늘도 핵심(F1~F4, E1~E4, 테스트 3개)이 check.sh를 통과하면 완료다. 확장 `-p`는 시간이 남을 때 한다. 일정은 커리큘럼(D4는 10/22 목요일)보다 8일 늦다. 따라잡으려고 오늘 분량을 늘리지 않는다.

## 1. 복습 퀴즈 (D3)
1. D3 트레이스의 ` M 7ff0005c8,8` 한 줄은 Cache Lab 방식의 캐시 시뮬레이터(D6)에서 접근 몇 번인가? 그 줄의 결과로 나올 수 있는 것을 hit / miss / miss eviction의 조합으로 모두 쓰고, 나올 수 없는 조합이 있다면 왜 없는지 한 줄로. 이 셈으로 D3의 `ls` 트레이스(load 122156, store 45859, modify 1831)를 돌리면 데이터 캐시 접근은 모두 몇 번인가?
2. D3의 `run`은 `Result<(), Box<dyn Error>>`를 돌려주고, `dump(&mut out, &summary)?`로 쓰기 오류를 그대로 올린다. 이제 `main`에 "읽는 쪽이 파이프를 먼저 닫아 쓰기가 실패한 경우(`io::ErrorKind::BrokenPipe`)만 메시지 없이 종료 코드 0으로" arm을 넣으려 한다(PRINCIPLES 2-4의 "정상적인 끝"). ① 지금 구조에서 그 arm을 쓰기 어려운 이유는? ② `run`이 `Result<(), CliError>`를 돌려주고 쓰기 오류가 모두 `CliError::Write(io::Error)`로 온다면, 그 arm의 패턴과 가드는 어떻게 쓰나?

## 2. 명세 요점
```
lru-set -E <줄 수> [<태그>...]          # 예: lru-set -E 2 1 2 1 3 2
```
- 세트 하나(줄 E개)에 태그를 차례로 넣는다. `-E`는 첫 두 인자이고 E는 1~65536이다. 그 뒤는 모두 10진 u64 태그다(0개도 된다)
- 출력: 접근마다 `<태그> hit` / `<태그> miss` / `<태그> miss eviction <쫓겨난 태그>`, 끝에 `hits:… misses:… evictions:…`. misses에는 쫓아낸 접근도 들어간다
- 교체: 빈 줄(valid가 false)이 먼저, 없으면 LRU 줄이다. hit도 그 줄을 가장 최근으로 만든다. `contains`는 순서를 바꾸지 않는다
- 오류 E1~E4: `lru-set: …` 한 줄, 종료 코드 1, 표준 출력 비움. 인자를 모두 검사한 뒤에 시작하므로 뒤쪽 태그가 틀려도 출력이 없다
- 제약: `src/set.rs`에 `Outcome`·`CacheSet`(`new`, `access(&mut self)`, `contains(&self)`)·`Line`, `src/lib.rs`에 `pub mod set;`, CLI는 `main.rs`. 테스트 3개(E = 1 충돌, E = 2 LRU 순서와 `contains`, cold miss와 태그 0)를 `assert_eq!`로. `run`은 오류 enum을 돌려준다(`Box<dyn Error>`가 아니다)
- 완료 기준: check.sh(debug 빌드)의 마지막 줄 `OK 60 · FAIL 0`. 짧은 열은 기대값과 그대로 비교하고, 긴 열(태그 2만 개까지)은 LRU의 성질로 만든 기대값과 비교한다. 참조 구현은 빌드를 빼고 약 2.3초였다
- 확장: `-p lru|fifo|random`과 `ReplacementPolicy` 트레잇(`EXT=1`), Belady의 이상 현상 실험

## 3. 개념 핵심 (CSAPP 6.4.3~6.4.4)
- **E-way 집합 연관**: 세트마다 줄이 E개다. 세트 선택은 직접 사상과 같은 인덱싱이고, 줄 매칭은 세트의 E줄을 모두 본다(valid이고 tag가 같은가). 세트 하나는 작은 연관 메모리다(키 = tag + valid, 값 = 블록)
- **miss일 때 교체**: 빈 줄이 있으면 거기에 넣고, 없으면 정책이 고른 줄을 쫓아낸다. 책의 정책은 무작위, LFU(가장 적게 쓴 것), LRU(가장 오래전에 쓴 것). 아래 층일수록 miss가 비싸서 좋은 정책이 값어치가 있다
- **완전 연관(S = 1, E = C/B)**: set index 비트가 없다(주소 = tag | offset). conflict miss가 없고 cold·capacity만 남는다. C/B개의 tag를 동시에 비교해야 해서 TLB 같은 작은 캐시에만 쓴다
- **같은 구조**: 직접 사상(E = 1), E-way, 완전 연관(S = 1)은 "세트 S개 × 줄 E개"의 특수한 경우다. 용량이 같으면 E를 늘릴 때 S가 준다. 세트끼리는 독립이라 세트 하나를 정확히 만들면 캐시는 그것을 S개 두면 된다(D6)
- **LRU의 값**: 정확한 LRU는 세트마다 ⌈log₂ E!⌉비트(8-way면 16비트)를 hit 때마다 고쳐야 해서 하드웨어는 흔히 근사를 쓴다. 이 머신 L1d에서 같은 세트로 가는 주소 9개를 돌아가며 읽으면 로드당 1.32ns였다. 정확한 LRU였다면 매번 miss라 L2 지연(수 ns)에 가까웠어야 한다(개념 문서 10절)
- **손으로 먼저**: 연습문제 6.13의 나머지(그 주소가 hit인가, 돌려줄 바이트는 무엇인가)와 6.14·6.15를 책의 캐시 내용 표로 푼다. 6.12·6.13의 주소 분해는 D1 예측 1에서 했다. 답은 책 장 끝에 있다

자세한 내용: `concepts/d04-associativity-and-lru.md`

## 4. 오늘 쓸 Rust 문법
아래 출력과 오류는 모두 이 머신(rustc 1.99.1, 에디션 2024)에서 돌려 본 것이다. 예는 일부러 오늘 과제와 다른 상황(파일 표, 디스크 스케줄러)에서 골랐다.

1. **`struct` + `impl` + 연관 함수 `new`.** C에서는 `struct fd_table`과 `fd_table_new()`, `fd_table_open(struct fd_table *t, …)`처럼 구조체와 함수를 따로 두고 첫 인자로 포인터를 넘겼다. Rust는 함수를 `impl` 블록에 묶고, 첫 인자 `self`를 `.` 앞에 쓴다.
   ```rust
   /// 열린 파일 표: 번호(fd)마다 빈칸이거나 파일 이름
   struct FdTable {
       slots: Vec<Option<String>>,
   }

   impl FdTable {
       fn new(size: usize) -> Self {               // self가 없는 연관 함수. FdTable::new(4)로 부른다
           Self { slots: vec![None; size] }        // Self는 FdTable의 별명
       }

       /// 가장 작은 빈 번호에 넣는다(POSIX open의 규칙). 꽉 찼으면 None
       fn open(&mut self, name: &str) -> Option<usize> {
           let fd = self.slots.iter().position(|slot| slot.is_none())?;
           self.slots[fd] = Some(name.to_owned());
           Some(fd)
       }

       fn close(&mut self, fd: usize) {
           if let Some(slot) = self.slots.get_mut(fd) {
               *slot = None;
           }
       }

       fn is_open(&self, fd: usize) -> bool {
           matches!(self.slots.get(fd), Some(Some(_)))
       }
   }

   let mut t = FdTable::new(4);
   t.open("a")      // Some(0)
   t.open("b")      // Some(1)
   t.close(0);
   t.open("c")      // Some(0)   ← 가장 작은 빈 번호
   t.is_open(1)     // true
   t.is_open(3)     // false
   ```
   `position`은 조건이 처음 참인 원소의 번호를 `Option<usize>`로 준다(없으면 `None`). 함수가 `Option`을 돌려줄 때 `?`는 `None`을 그대로 돌려주며 빠져나간다. `Result`의 `?`와 같은 일이다.

2. **`&self`, `&mut self`, `self`.** C의 `const struct fd_table *t`, `struct fd_table *t`, 구조체 값 전달에 해당한다. 다른 점은 컴파일러가 검사한다는 것이다.
   ```rust
   let t = FdTable::new(4);   // mut가 없다
   t.open("a");               // error[E0596]: cannot borrow `t` as mutable, as it is not declared as mutable

   fn is_open(&self, fd: usize) -> bool {
       self.slots[fd] = None;  // error[E0596]: cannot borrow `self.slots` as mutable, as it is behind a `&` reference
       …
   }
   ```
   `&self` 메서드는 구조체를 바꿀 수 없다. "들여다보기만 한다"는 약속이 시그니처에 적히고 컴파일러가 지킨다. `rustc --explain E0596`.

3. **`min_by_key`와 `enumerate`: 가장 작은 것 고르기.** C라면 `best = -1`로 시작하는 루프를 짰다.
   ```rust
   // 디스크 헤드(트랙 50)에서 가장 가까운 요청부터 처리한다 (SSTF, D5에서 다시)
   let head = 50u32;
   let pending = [82u32, 17, 43, 140, 57];
   pending.iter().enumerate().min_by_key(|&(_, &track)| track.abs_diff(head)).map(|(i, _)| i)
                                                     // Some(2)   43은 거리 7. 57도 거리 7이다
   pending.iter().enumerate().max_by_key(|&(_, &track)| track.abs_diff(head))
                                                     // Some((3, 140))
   let ties = [7u32, 3, 3, 9, 9];
   ties.iter().enumerate().min_by_key(|&(_, &v)| v)   // Some((1, 3))   같으면 앞의 것
   ties.iter().enumerate().max_by_key(|&(_, &v)| v)   // Some((4, 9))   같으면 뒤의 것
   [0u32; 0].iter().min_by_key(|&&v| v)               // None
   pending.iter().position(|&t| t > 100)              // Some(3)
   pending.iter().position(|&t| t > 500)              // None
   ```
   `enumerate()`가 (번호, 원소)를 주므로 `min_by_key`의 결과에서 번호를 꺼낼 수 있다. 같은 값이 여럿이면 `min_by_key`는 첫 번째를, `max_by_key`는 마지막을 돌려준다. 고르는 기준값이 서로 다르게 만들어 두면 이 규칙에 기댈 일이 없다.

4. **필드 빌림과 E0499.** 원소를 `&mut`로 잡은 채 `self`의 `&mut` 메서드를 부르면 `self`를 두 번 빌리는 셈이다.
   ```rust
   struct Job { id: u32, last_run: u64 }
   struct Scheduler { now: u64, jobs: Vec<Job> }

   impl Scheduler {
       fn tick(&mut self) -> u64 { self.now += 1; self.now }

       fn run(&mut self, id: u32) {
           if let Some(job) = self.jobs.iter_mut().find(|j| j.id == id) {
               job.last_run = self.tick();   // error[E0499]: cannot borrow `*self` as mutable more than once at a time
           }
       }
   }
   ```
   `job`이 `self.jobs`를 빌리고 있는데 `self.tick()`이 `self` 전체를 또 빌린다. C라면 그냥 컴파일되고, 만약 `tick`이 `jobs`를 재할당했다면 `job`은 해제된 메모리를 가리켰을 것이다. 고치는 방향은 셋이다. ① 빌리기 전에 먼저 부른다(`let now = self.tick();` 뒤에 `find`). ② 메서드 대신 필드를 직접 쓴다. 한 함수 안에서 `self.jobs`와 `self.now`는 따로 빌릴 수 있어서 `self.now += 1; job.last_run = self.now;`는 컴파일된다. ③ `position`으로 번호만 찾고, 그 빌림이 끝난 뒤에 `self.tick()`과 `self.jobs[i]`를 쓴다. 셋 다 이 머신에서 컴파일하고 실행해 확인했다. `rustc --explain E0499`.

5. **`vec![값; n]`은 `Clone`이 필요하다.**
   ```rust
   struct Slot { used: bool }
   let slots = vec![Slot { used: false }; 4];                        // error[E0277]: the trait bound `Slot: Clone` is not satisfied
   let slots: Vec<Slot> = (0..4).map(|_| Slot { used: false }).collect();   // 된다
   ```
   `vec![x; n]`은 `x`를 복제해 n칸을 채운다. 타입에 `#[derive(Clone)]`을 붙이거나, 복제하지 않고 하나씩 만들어 `collect`한다.

6. **한 패키지에 라이브러리와 바이너리.** C로 치면 `libset.a` + `set.h`와, 그것을 쓰는 `main.c`다.
   ```
   days/d04-lru-set/src/
     lib.rs     pub mod set;                                ← 라이브러리 크레이트 lru_set의 뿌리
     set.rs     pub struct CacheSet { … } …                 ← 그 안의 set 모듈
     main.rs    use lru_set::set::{CacheSet, Outcome};      ← 바이너리 크레이트. 라이브러리를 바깥에서 쓴다
   ```
   - 패키지 이름의 `-`는 크레이트 이름에서 `_`가 된다(`lru-set` → `lru_set`).
   - 이 머신에서 위의 파일 표로 확인한 것: 바이너리만 두고 `main.rs`에 `mod table;`을 쓰면, `main`은 안 부르고 테스트만 부르는 `pub fn is_open`에 ``warning: method `is_open` is never used``가 난다. 바이너리 안의 `pub`은 바깥에서 쓸 길이 없기 때문이다. 같은 파일을 `lib.rs`의 `pub mod table;`로 옮기면 빌드와 clippy 모두 경고가 없다. 라이브러리의 `pub` 항목은 바깥에 내놓은 API라서다. 오늘의 `contains`가 바로 이 경우다(CLI는 쓰지 않는다).
   - 비공개 필드는 바깥에서 못 본다. 바이너리에서 `t.slots.len()`을 쓰면 ``error[E0616]: field `slots` of struct `FdTable` is private``. C에서 헤더에 `struct fd_table;`만 선언해 속을 감추던 것(불투명 포인터)을 컴파일러가 보장해 준다.
   - `cargo test -p 패키지 -- table::`는 라이브러리의 `table::tests::…`를 돌린다. 바이너리와 문서 테스트도 각자 `test result:` 줄을 찍는다(0개).
   - 라이브러리의 `///` 안에 코드 블록을 쓰면 문서 테스트가 된다. 블록은 크레이트 바깥 코드처럼 컴파일되므로 `use lru_set::set::CacheSet;`부터 써야 하고, 빠지면 E0433으로 `cargo test`가 실패해 check.sh의 단위 테스트 항목도 FAIL이 된다(참조 구현으로 확인).

7. **이름 붙은 필드가 있는 variant.** D0의 `CliError::BadNumber { flag, text }`와 같은 모양이다.
   ```rust
   #[derive(Debug)]
   enum Reply { Done, Moved { to: u32 } }

   match r {
       Reply::Done => "done".to_owned(),
       Reply::Moved { to } => format!("moved to {to}"),   // 필드를 같은 이름의 변수로 꺼낸다
   }
   format!("{:?}", Reply::Moved { to: 3 })   // "Moved { to: 3 }"
   ```

8. **테스트에서 결과 여러 개를 한 번에 비교하기.**
   ```rust
   let mut small = FdTable::new(2);
   let got: Vec<Option<usize>> = ["x", "y", "z"].iter().map(|name| small.open(name)).collect();
   assert_eq!(got, [Some(0), Some(1), None]);   // Vec과 배열을 바로 비교할 수 있다
   ```
   클로저가 `small`을 `&mut`로 빌려 원소마다 `open`을 부른다. 한 줄씩 `assert_eq!`를 쓰는 것보다, 실패하면 열 전체가 `left`와 `right`로 찍혀서 어디서 갈렸는지 한눈에 보인다.

## 5. 흔한 함정
1. **valid를 보지 않는다.** 빈 줄의 tag 칸이 0이면, 빈 세트에 태그 0이 오자마자 hit이 된다. check.sh의 `-E 2 0`이 잡는다
2. **hit에서 LRU 정보를 고치지 않는다.** 그러면 들어온 순서로 쫓아내는 FIFO가 된다. 명세의 첫 예(`-E 2 1 2 1 3 2`)에서 3이 2가 아니라 1을 쫓아낸다
3. **빈 줄을 채운 것을 `MissEvict`로 보고한다.** 빈 줄과 쫓아낼 줄을 한 번에 고르는 방식이면, 고른 줄이 빈 줄이었는지 따로 봐야 한다. check.sh의 `-E 3 0 1 2`(쫓아내기 0)가 잡는다
4. **줄을 채울 때 LRU 정보를 적지 않는다.** hit 때만 적으면 새로 들어온 줄끼리 구별이 안 되고, 쫓아낼 줄이 LRU가 아니게 된다. check.sh의 `-E 2 1 2 3 4 5`(4는 2를 쫓아내야 한다)가 잡는다
5. **misses에 `MissEvict`를 안 센다.** 요약 줄의 misses는 쫓아낸 접근까지 센다(Cache Lab과 같다)
6. **태그를 다 검사하기 전에 출력을 시작한다.** `-E 2 1 zz qq`에서 `1 miss`가 먼저 찍히면 E3인데 표준 출력이 비지 않는다. 인자를 모두 검사해 확정된 값(예: `Vec<u64>`)으로 바꾼 뒤 시작한다(PRINCIPLES 3-2)
7. **E0499.** 줄을 `iter_mut()`로 잡은 채 `self`의 `&mut` 메서드를 부른다(문법 4)
8. **`cargo build`는 되는데 `cargo test`만 안 된다.** 테스트의 `assert_eq!(set.access(1), Outcome::Hit)`은 `Outcome`에 `==`와 `{:?}`가 있어야 컴파일된다. 없으면 E0369와 E0277이 난다(참조 구현으로 확인. D3 BRIEF 4절 1과 같은 이야기다)

## 6. 예측 (구현 전에 README `예측:`에)
먼저 말을 정리한다(자세한 것은 개념 문서 2~5절).
- **세트와 줄**: 캐시는 세트 S개로 나뉘고, 세트마다 블록을 담을 자리(줄)가 E개다. 블록은 정해진 세트 하나에만 들어간다. 세트 번호 = 블록 번호 mod S다(D1)
- **LRU**: 세트의 줄이 다 찼는데 새 블록이 오면, 그 세트에서 마지막으로 쓴 지 가장 오래된 블록을 쫓아낸다
- **용량이 같은 여러 모양**: 줄이 모두 8개인 캐시는 S × E = 8이 되게 여러 모양으로 짤 수 있다. E = 1이면 직접 사상(D1)이고, S = 1이면 블록이 아무 줄에나 들어가는 완전 연관이다

1. 줄이 모두 8개인 캐시 네 가지가 있다: (S, E) = (8, 1), (4, 2), (2, 4), (1, 8). 모두 LRU이고 처음엔 비어 있다. 블록 0, 4, 8을 이 순서로 10바퀴(읽기 30번) 읽는다. 네 캐시 중 miss가 가장 많은 것은? (가) (8, 1) (나) (4, 2) (다) (2, 4) (라) (1, 8) (마) 넷 다 같다. 이유를 한 줄 붙인다
2. D3에서 만든 `scratch/ls.trace`의 데이터 접근은 171677번이다(`M`은 읽기·쓰기 두 번으로 센다). 이것을 이 머신 L1d의 모양(S = 64, E = 8, 32KiB)으로 흉내 낸 miss 수와, 용량은 같은 32KiB로 두고 직접 사상(S = 512, E = 1)으로 짠 캐시의 miss 수를 비교한다. 세트끼리는 서로 독립이라, 트레이스를 세트별로 나눠 세트마다 `lru-set`을 돌리고 miss를 더하면 캐시 전체를 흉내 낸 것과 같다(개념 문서 6절, 명령은 7절). 직접 사상의 miss는 8-way의 몇 배쯤일까? (가) 거의 같다(1.1배 미만) (나) 1.1~1.5배 (다) 1.5~3배 (라) 3배 넘게. D1의 conflict miss와 D3에서 본 `ls`의 접근(스택의 `push`·`pop`, 여러 영역에 흩어진 데이터)을 떠올려 이유를 한 줄 붙인다

## 7. 진행
0. 예측 두 개를 README `예측:`에 먼저 적는다
1. `src/set.rs`: `Outcome`, `Line`, `CacheSet`(`new`·`access`·`contains`) + 테스트 3개, `src/lib.rs`에 `pub mod set;` → `cargo test -p lru-set`
2. `src/main.rs`: 인자 → E 검사 → 태그를 모두 검사 → 세트 → 접근마다 한 줄 → 요약 → `flush`. 오류 E1~E4는 enum + `Display`이고, `run`이 그 enum을 돌려준다
3. `./days/d04-lru-set/check.sh`
4. 예측 확인. `cargo build -q --release -p lru-set` 뒤에 `X=target/release/lru-set`
   - 예측 1: 네 캐시마다 블록 0, 4, 8의 세트(블록 mod S)와 태그(블록 ÷ S)를 구한다. 세트마다 그 세트로 가는 태그를 읽는 순서대로 모아 `$X -E <E> …`로 한 번씩 돌리고, 세트들의 miss를 더한다. 10바퀴는 아래 `rounds`로 만든다
     ```sh
     rounds() { for r in $(seq 10); do echo "$@"; done; }   # 인자 묶음을 10번 되풀이한다
     $X -E 3 $(rounds 5 6) | tail -n 1                      # 예: 태그 5, 6을 10바퀴, 줄 3개
     ```
   - 예측 2: 블록 번호를 뽑고, 세트(블록 mod S)마다 태그(블록 ÷ S) 파일을 만들어 세트마다 `$X -E <E>`로 돌린 뒤 더한다. 세트 수가 512면 반복문이 수백 번 돌아 몇 초 걸린다
     ```sh
     # 데이터 접근의 블록 번호 (블록 = 주소 ÷ 64, M은 읽기·쓰기 두 번)
     gawk '$1 ~ /^[LSM]$/ { split($2, a, ","); b = int(strtonum("0x" a[1]) / 64); print b; if ($1 == "M") print b }' scratch/ls.trace > scratch/blocks
     wc -l < scratch/blocks                          # 171677
     # sim S E: 세트마다 줄 E개짜리 lru-set을 돌리고 hit·miss를 더한다
     sim() {
       rm -rf scratch/sets && mkdir scratch/sets
       gawk -v S="$1" '{ print int($1 / S) > ("scratch/sets/" ($1 % S)) }' scratch/blocks
       for f in scratch/sets/*; do "$X" -E "$2" $(cat "$f") | tail -n 1; done |
         gawk -F'[: ]' '{ h += $2; m += $4; n++ } END { print n " sets, hits:" h " misses:" m }'
     }
     sim 64 8      # 이 머신 L1d의 모양
     sim 512 1     # 같은 32KiB를 직접 사상으로
     ```
     세트 하나만 들여다보려면 `$X -E 8 $(cat scratch/sets/0)`처럼 그 파일을 넘긴다. 반복문이 접근을 빠짐없이 나누는지는 튜터가 이 머신에서 확인했다(두 경우 모두 합이 171677번)
5. 기록: 예측 / 결과 / 배운 것과 숫자 세 개. 결과에는 예측 1의 네 캐시 miss 수와 예측 2의 `sim` 두 줄을 적는다

- 커밋 전에 `cargo fmt` → `cargo clippy -q --workspace`(경고 0)
- 90분이 넘으면 그 상태로 커밋한다. 컴파일이 안 되면 끝에 `(WIP)`
- 15분 넘게 막히면 "힌트 1". 끝나면 `./days/d04-lru-set/check.sh` → "D4 리뷰"
