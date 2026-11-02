# CSAPP 6~12장 × Rust 커리큘럼

2026-11-02 개정. 이 파일이 원본이다. 이전 커리큘럼(Day 65개 중 D0~D5 진행)은 비공개 아카이브 저장소에 있다.

## 한눈에 보기

CSAPP 3판 6~12장을 한 절도 빼지 않고, CMU 15-213과 같은 깊이로 공부한다. 마일스톤 6개(선택 1개 별도)를 단계 26개로 나눈다.

- 모든 절은 개념 문서로 다룬다. 설명과 문제는 자작이고, 문서만 읽어도 그 절을 익히고 실험 결과를 예측할 수 있게 쓴다.
- 코드는 세 가지 중 하나에 해당할 때 짠다: 직접 만들어 봐야 이해되는 것, 뒤에서 그 위에 쌓을 것, 공식 채점기가 있는 것. 나머지는 짧은 실험으로 관찰한다.
- 골격(CLI, 입출력, 테스트, 타입, 이름)은 튜터가 주고, 학습자는 핵심 함수를 채운다. 마일스톤이 지날수록 골격은 줄고 설계는 늘어난다.
- 코드는 마일스톤을 넘어 쌓인다: `cachesim`(M1, M4의 TLB에서 다시 씀), `elf`(M2), `sysx`(M3~M6: fd·rio·proc·signal·mmap·net·sync), `alloc`(M4).
- 네 마일스톤은 CMU 공식 랩으로 끝난다: Cache Lab(M1), Shell Lab(M3), Malloc Lab(M4), Proxy Lab(M6).
- 마일스톤을 끝낸 뒤 원하면 논문 세션을 따로 연다. 마일스톤 완료 기준에는 넣지 않는다.

| 마일스톤 | CSAPP | 단계 | 완료 기준 | 기간(추정) |
|---|---|---|---|---|
| M1 메모리 계층 | 6장 | 4 | Cache Lab Part A(test-csim 27/27), Part B 32×32 미스 300 이하 | 2주 |
| M2 링킹 | 7장 | 4 | elfdump 출력이 readelf와 일치, 링크 실험 기록 | 2주 |
| M3 시스템 수준 I/O와 예외적 제어 흐름 | 10장, 8장, 부록 A | 5 | Shell Lab(trace01~16이 tshref와 일치) | 3~4주 |
| M4 가상 메모리 | 9장 | 5 | Malloc Lab(mdriver의 모든 트레이스 정답) | 3~4주 |
| M5 네트워크 프로그래밍 | 11장 | 3 | Tiny가 정적·동적 콘텐츠를 제공 | 2주 |
| M6 동시성 | 12장 | 5 | Proxy Lab(driver.sh 70/70) | 3주 |
| (선택) M7 파일 시스템 | 책 밖 | — | — | — |

합계 15~17주다. 2026-11-02에 시작하면 2027년 2월 중순~3월 초에 끝난다. 지난 커리큘럼의 실제 속도(주 3회 안팎)로 잡은 추정이고, 마일스톤이 끝날 때마다 실제 속도로 다시 잡는다.

## 깊이의 기준

- **CMU 15-213**(2025 가을): CSAPP 저자들의 학교에서 이 책으로 가르치는 원래 과목이다. 6~12장을 강의 16회 안팎으로 다루고 Cache·Malloc·Shell·Proxy·SFS 랩을 낸다. Cache·Shell·Proxy 랩 뒤에는 코드 리뷰가 있다. 마일스톤의 범위와 랩은 이 과목에 맞췄다.
- **MIT 6.1810**(2025 가을): 15-213 다음 단계의 OS 과목이다. xv6 커널 랩 9개(util, syscall, pgtbl, traps, cow, net, lock, fs, mmap)와 함께 주제 11개에 논문을 한 편씩 읽힌다. 마일스톤 뒤 논문 세션은 이 방식을 빌렸다.
- **Stanford CS111**(2026 가을), **Berkeley CS162**: 파일 시스템·프로세스·스레드를 다루고, CS162는 Pintos 커널을 구현한다. 파일 시스템은 CSAPP 밖이라 선택 마일스톤 M7로 둔다.
- 순서는 6 → 7 → 10·8 → 9 → 11 → 12다. CMU는 9장을 8장보다 먼저 하지만, Rust에서는 libc 호출을 RAII로 감싸는 `unsafe`(10·8장)부터 하고 원시 포인터 산술(9장 할당기)로 넘어가야 계단이 완만하다.

출처(2026-11-02 확인): [CMU 15-213 F25 일정](https://www.cs.cmu.edu/afs/cs/academic/class/15213-f25/www/schedule.html), [CMU 15-213 F25 랩](https://www.cs.cmu.edu/afs/cs/academic/class/15213-f25/www/labs.html), [MIT 6.1810 2025 일정](https://pdos.csail.mit.edu/6.828/2025/schedule.html), [Stanford CS111](https://web.stanford.edu/class/cs111), [Berkeley CS162](https://rise.cs.berkeley.edu/course/cs162-operating-systems-systems-programming)

## 공부 방법

### 단계 하나 (1~3회 앉아서)

1. **시작**: "M1-2 시작"을 보내면 튜터가 개념 문서, 골격 코드, 단계 명세(마일스톤 `README.md`), 예측 질문을 준비한다. 학습자는 받은 것을 `M1-2: 골격`으로 먼저 커밋한다. 그래야 이력에서 골격과 학습자의 코드가 갈린다.
2. **읽기**: 개념 문서를 읽고 자작 문제를 푼 뒤 접힌 풀이로 맞춰 본다.
3. **예측**: 실행 전에 `LOG.md`에 예측을 쓴다. 개념 문서의 "예측 실마리"만으로 추론할 수 있다.
4. **구현**: 골격의 `todo!()`를 채운다. 15분 넘게 막히면 "힌트 1" → "힌트 2" → "힌트 3".
5. **검증**: 명세의 확인 명령(테스트, 공식 채점기, 측정)을 돌린다.
6. **리뷰**: "리뷰"를 보내면 튜터가 직접 돌려 보고 `LOG.md`에 결과·피드백과 배운 것을 쓴 뒤, 이해도 질문과 설계 조언을 한다.
7. 커밋하고 다음 단계로 간다.

### 마일스톤 마무리

- 마지막 단계 리뷰 뒤 "M1 마무리"를 보내면 마일스톤 전체 리뷰와 체크포인트를 한다.
- 그 뒤 원하면 "M1 논문"으로 논문 세션을 연다.

### 개념 문서 기준

- 그 단계의 CSAPP 절을 빠짐없이 다룬다. 문서 끝 체크리스트에 절 번호마다 다뤘는지 표시한다.
- 설명, 그림, 문제는 자작한다. 공개 저장소이므로 책의 문장, 그림, 연습문제 원문, 해설을 옮기지 않는다.
- 절마다 자작 문제와 단계별 풀이를 넣고, 풀이는 `<details>`로 접는다. 풀이의 숫자는 코드로 검산한다.
- 책 연습문제 번호표: 그 절에 해당하는 연습문제 번호만 적는다. 공식 해답은 책 각 장 끝의 "Solutions to Practice Problems"에 있다. 막히면 그 문제를 채팅에 붙여 넣고 물어본다.
- 예측 실마리: 이 단계 예측에 쓰는 모델과 식, 이 머신의 값(확인한 명령과 함께), 추론의 방향.
- C·어셈블리와의 연결, 흔한 오해, 이 커리큘럼에서 다시 나오는 곳.

### 예측 규칙

- 단계마다 1~2개 낸다. 개념 문서의 내용과 이 머신의 값만으로 추론할 수 있어야 한다. 문서에 없는 지식(커널 내부 동작, 기기별 특성)에 기대는 예측은 내지 않는다.
- 감이 없을 만한 수치는 범위 보기(객관식)로 내고, 고른 이유를 쓰게 한다.
- 답은 어디에도 미리 쓰지 않는다(개념 문서, 명세, 채팅 모두). 결과는 리뷰 때 튜터가 직접 돌려서 쓴다.

### 골격 단계

| 마일스톤 | 튜터가 주는 것 | 학습자가 하는 것 |
|---|---|---|
| M1~M2 | 모듈 구성, 타입, 시그니처, 이름, 문서 주석, 테스트, CLI | 함수 몸체 |
| M3~M4 | 공개 API(타입·시그니처), 테스트, CLI | 내부 구조와 보조 함수 설계, 구현 |
| M5~M6 | CLI와 테스트 | 설계 노트 한 쪽(모듈·타입·소유권·스레드) → 리뷰 → 구현 |

- 골격 자체가 그 마일스톤 Rust 문법의 읽기 교재다. 브리핑에서 골격에 처음 나온 문법을 C와 비교해 짚는다.
- 이름은 `docs/GLOSSARY.md`에서 가져온다. 학습자가 만드는 보조 함수도 사전의 관례를 따르면 된다.
- CLI 파싱과 출력 형식은 언제나 튜터 몫이다. 완료 기준은 공식 채점기와 테스트이고, CLI 경계값은 검사하지 않는다.

### 기록

| 파일 | 칸 | 쓰는 사람 |
|---|---|---|
| `LOG.md` | 예측 | 학습자(실행 전) |
| `LOG.md` | 결과와 피드백, 배운 것, 힌트 단계 | 튜터 |
| `LOG.md` | 재미(1~5), 막힌 시간(분) | 학습자 |
| `QA.md` | 질문과 답의 요지 | 튜터(세션 중에 바로) |
| `REVIEW.md` | 리뷰 | 튜터 |

"배운 것"은 학습자가 던진 질문 중 중요한 지식을 다시 짚는 칸이다. 세션이 바뀌면 대화가 사라지므로 `QA.md`가 그 원본이다.

### 리뷰

- 튜터가 테스트, 채점기, clippy를 직접 돌리고, 측정이 있으면 `--release`로 잰다.
- 이해도 질문 3~5개: 개념과, 그 코드가 왜 그렇게 동작하는지. 학습자가 자기 말로 답하면 ○△✕로 채점하고 보충한다.
- 설계·구조 조언: 모듈 경계, 소유권, 오류 흐름, `unsafe` 건전성. `docs/RULES.md`의 설계 원칙 번호로 짚는다.
- 테스트가 잡은 정확성 문제.
- 이름과 스타일은 지적하지 않는다(이름 사전과 fmt·clippy의 몫).

### 논문 세션

- 마일스톤을 끝낸 뒤 "M1 논문"으로 따로 연다. 마일스톤 진행을 막지 않는다.
- 튜터가 `papers/mN-주제.md`에 서지, 논문 다리(CSAPP 밖 용어 1~2쪽), 읽을 범위, 길잡이 질문, 동향 논문 3편을 쓴다.
- 학습자가 읽고 5줄 노트(문제, 핵심 아이디어, 기대는 CSAPP 개념, 비교 대상, 한계·반론)를 쓰면, 튜터가 피드백하고 심사위원처럼 토론한 뒤 요지를 남긴다.
- 읽는 법: 1회독(10분)은 제목·초록·서론·그림·결론, 2회독(30~60분)은 그림과 실험 위주, 3회독은 끌리는 논문만. 참고: S. Keshav, "How to Read a Paper"(ACM SIGCOMM CCR, 2007).
- 가능하면 내 코드로 작게 재현한다. 예: cachesim에 SIEVE 교체 정책을 넣어 트레이스로 미스율 비교.
- 인용 수는 조회한 출처와 날짜를 붙인다. 아래 마일스톤의 값은 Semantic Scholar에서 2026-11-02에 조회했다. 구글 스칼라와는 다를 수 있다.

### 체크포인트 (마일스톤 마무리 때)

- 근거: `LOG.md`의 숫자(재미, 막힌 시간, 힌트), `REVIEW.md`의 이해도 질문 점수, `git log`.
- 세 가지 추세: 예측이 틀렸을 때 "왜"를 파고드는가, 같은 종류의 버그를 더 빨리 잡는가, 힌트 의존이 줄어드는가.
- 다음 마일스톤의 기간과 골격 양을 조정한다.

## M1 메모리 계층 (6장)

- 15-213 대응: 강의 "The Memory Hierarchy", "Cache Memories", Cache Lab
- 쌓이는 코드: `crates/cachesim`(M4의 TLB에서 다시 쓴다), `apps/csim`, `experiments`
- Rust: 구조체·enum·`match`, 트레잇과 제네릭(교체 정책, `BufRead`), 이터레이터와 클로저, 모듈과 워크스페이스(라이브러리 + 실행 파일), 단위·통합 테스트

| 단계 | CSAPP 절 | 할 일 | 확인 |
|---|---|---|---|
| M1-1 저장 장치와 지역성 | 6.1~6.3 | 실험: 포인터 추적으로 작업 집합 크기별 접근 지연을 재고, 순차 접근과 비교 | 측정 결과와 `lscpu`의 캐시 크기 대조 |
| M1-2 캐시 구조 | 6.4.1~6.4.4 | 구현: 주소 분해, LRU 세트, 캐시의 hit·miss·eviction | 테스트 |
| M1-3 쓰기와 시뮬레이터 | 6.4.5~6.4.7 | 구현: 쓰기 정책(dirty 비트), 3C 분류(같은 용량의 완전 연관 캐시를 나란히), csim | test-csim 27/27, 3C 합 = 미스 수 |
| M1-4 캐시 친화적 코드 | 6.5~6.6 | 실험: 행렬곱 루프 순서 6가지와 블로킹 / 구현: 전치 커널과 주소 기록기 → 내 csim(s=5, E=1, b=5)으로 Part B 자가 채점. 선택: 핸드아웃의 trans.c로 공식 test-trans, 메모리 마운틴 | 32×32 미스 300 이하(만점 기준: 64×64는 1,300, 61×67은 2,000 이하) |

논문 세션 후보: FlashAttention (NeurIPS 2022, 인용 5,749). 동향: S3-FIFO "FIFO Queues are All You Need for Cache Eviction" (SOSP 2023, 119), SIEVE (NSDI 2024, 67), Pond (ASPLOS 2023, 544).

## M2 링킹 (7장)

- 15-213 대응: 강의 "Linking". 15-213에는 링킹 랩이 없어서 elf 도구와 링크 실험이 이 마일스톤의 코드다
- 쌓이는 코드: `crates/elf`, `apps/elfdump`, `experiments`(C 파일, `build.rs`)
- Rust: 수명(`&'a [u8]`, 복사 없는 파서), `TryFrom`·`From`, 오류 enum과 `Display`, `Iterator` 직접 구현, `extern "C"`와 `build.rs`, `cdylib`, `CStr`·`CString`, 함수 포인터

| 단계 | CSAPP 절 | 할 일 | 확인 |
|---|---|---|---|
| M2-1 컴파일 드라이버와 목적 파일 | 7.1~7.4 | 구현: ELF 헤더와 섹션 헤더 파서, `elfdump header`·`sections` / 실험: `gcc -v -save-temps`, `rustc --emit` | `readelf -h`·`-S`와 일치 |
| M2-2 심볼과 심볼 해석 | 7.5~7.6 | 구현: 심볼 테이블, `elfdump syms` / 실험: strong·weak 규칙, 정적 라이브러리와 링크 순서, `build.rs`로 C 라이브러리 링크 | `readelf -s`·`nm`과 일치 |
| M2-3 재배치와 로딩 | 7.7~7.9, 7.14 | 구현: 재배치 엔트리와 프로그램 헤더, `elfdump relocs`·`segments` / 실험: 패치될 값을 계산해 `objdump`와 비교, PT_LOAD와 `/proc/<pid>/maps` 비교 | 계산이 `objdump`와 일치 |
| M2-4 동적 링킹과 인터포지셔닝 | 7.10~7.13 | 실험: 공유 라이브러리, dlopen 플러그인(`cdylib`), gdb로 GOT/PLT 관찰, 인터포지셔닝 3종(런타임은 Rust `cdylib` + `LD_PRELOAD`) | 실험 기록 |

논문 세션 후보: BOLT (CGO 2019, 174) 또는 RetroWrite (IEEE S&P 2020, 212). 동향: Propeller (ASPLOS 2023, 47), XZ 백도어 분석 "On the critical path to implant backdoors…" (arXiv 2024, 31).

## M3 시스템 수준 I/O와 예외적 제어 흐름 (10장, 8장, 부록 A)

- 15-213 대응: 강의 "Processes and Multitasking", "Exceptional Control Flow", "System Level I/O", Shell Lab
- 쌓이는 코드: `crates/sysx`(fd, rio, proc, signal), `apps/tsh`
- Rust: `unsafe`와 `// SAFETY:`, libc FFI, RAII(`Drop`), `Read`·`Write` 구현, `CString`·`CStr`, `io::Error`와 errno, `static`과 원자 타입, 시그널 핸들러의 제약

| 단계 | CSAPP 절 | 할 일 | 확인 |
|---|---|---|---|
| M3-1 Unix I/O와 RIO | 10.1~10.5 | 구현: `sysx::Fd`, `sysx::rio`(short count, 버퍼 읽기) | 테스트(파이프로 short count 재현) |
| M3-2 메타데이터, 공유, 리다이렉션, 표준 I/O | 10.6~10.12 | 구현: stat과 디렉터리 반복자, `dup2` / 실험: 세 테이블(`/proc/self/fdinfo`), fork와 버퍼 | 테스트, 실험 기록 |
| M3-3 예외와 프로세스 | 8.1~8.4, 부록 A | 구현: `sysx::proc`(spawn, wait, 종료 상태 해석) / 실험: `asm!`으로 시스템 콜, fault 3종, 문맥 전환 비용, 좀비와 고아 | 테스트, 측정 |
| M3-4 시그널과 비지역 점프 | 8.5~8.7 | 구현: `sysx::signal`(sigaction, 시그널 집합, 블록 가드, 안전한 출력) / 실험: 시그널은 큐잉되지 않음, 경쟁과 sigprocmask, sigsuspend, setjmp와 Rust의 대안 | 테스트, 실험 기록 |
| M3-5 Shell Lab | 8.4.6, 8.5 종합 | 구현: tsh(잡 컨트롤). 명령줄 파서는 골격으로 준다(CMU 핸드아웃도 parseline을 준다) | sdriver trace01~16이 tshref와 일치 |

논문 세션 후보: What Modern NVMe Storage Can Do, And How To Exploit It (VLDB 2023, 97). 동향: ghOSt (SOSP 2021, 130), XRP (OSDI 2022, 120), Eliminating Receive Livelock in an Interrupt-Driven Kernel (USENIX ATC 1996, 553).

## M4 가상 메모리 (9장)

- 15-213 대응: 강의 "Virtual Memory: Concepts", "Virtual Memory: Details", "Dynamic Memory Allocation: Basic/Advanced", Malloc Lab
- 쌓이는 코드: `apps/vmsim`(TLB는 cachesim 재사용), `sysx::mmap`, `crates/alloc`(할당기, staticlib와 `GlobalAlloc`)
- Rust: 원시 포인터, `NonNull`, 포인터 산술, 정렬과 `Layout`, `GlobalAlloc`, `UnsafeCell`, `MaybeUninit`, Miri, `Deref`, `#[unsafe(no_mangle)] extern "C"`와 staticlib

| 단계 | CSAPP 절 | 할 일 | 확인 |
|---|---|---|---|
| M4-1 VM 개념과 주소 번역 | 9.1~9.6 | 구현: 책 9.6.4와 같은 규모의 작은 시스템 주소 번역 시뮬레이터(표의 값은 자작, TLB는 cachesim) / 실험: TLB reach 계단, huge page, `perf stat`의 dTLB 미스 | 테스트, 측정 |
| M4-2 리눅스 VM과 메모리 매핑 | 9.7~9.8 | 구현: `sysx::Mmap` / 실험: 주소 공간 지도, 요구 페이징(RSS, minflt), 공유·사적 매핑과 COW | 테스트, 측정 |
| M4-3 동적 할당 기초 | 9.9.1~9.9.12 | 구현: 가짜 힙 위의 암시적 가용 리스트(배치, 분할, 경계 태그, 연결), 힙 검사기 | 테스트, Miri |
| M4-4 Malloc Lab | 9.9.13~9.9.14 | 구현: 명시적·분리 가용 리스트, staticlib로 mdriver 연결, `#[global_allocator]` | mdriver 모든 트레이스 정답(점수는 기록). 핸드아웃에 든 트레이스는 M4 시작 때 확인한다 |
| M4-5 GC와 메모리 버그 | 9.10~9.11 | 실험: 메모리 버그 동물원(C의 valgrind·ASan 대 Rust의 컴파일 오류·Miri) / 선택: 내 힙 위의 보수적 mark & sweep | 실험 기록 |

논문 세션 후보: PagedAttention "Efficient Memory Management for Large Language Model Serving with PagedAttention" (SOSP 2023, 9,683). 동향: vAttention (ASPLOS 2025, 176), Meltdown (USENIX Security 2018, 1,544), mimalloc (APLAS 2019, 101).

## M5 네트워크 프로그래밍 (11장)

- 15-213 대응: 강의 "Network Programming (Part I, II)". Tiny는 책 11.6의 예제다
- 쌓이는 코드: `sysx::net`, `crates/http`, `apps/tiny`, `experiments`(hostinfo, echo)
- Rust: 소켓 FFI 구조체(`sockaddr` 캐스팅, `socklen_t`), C 연결 리스트를 감싼 반복자(수명과 `Drop`), 바이트 순서, 복사 없는 파서(수명 다시 보기)

| 단계 | CSAPP 절 | 할 일 | 확인 |
|---|---|---|---|
| M5-1 클라이언트-서버와 인터넷 | 11.1~11.3, 11.4.7 | 구현: 바이트 순서와 IP 변환, getaddrinfo 반복자, hostinfo | 테스트 |
| M5-2 소켓 인터페이스 | 11.4 | 구현: `sysx::net`(open_clientfd, open_listenfd), 반복형 echo 서버 | 테스트, nc로 확인 |
| M5-3 웹 서버와 Tiny | 11.5~11.6 | 구현: HTTP 요청 파서, Tiny(정적은 mmap, 동적은 CGI) | 테스트, curl로 확인 |

논문 세션 후보: Understanding Host Network Stack Overheads (SIGCOMM 2021, 181). 동향: eRPC "Datacenter RPCs can be General and Fast" (NSDI 2019, 409), Snap (SOSP 2019, 265), Demikernel (SOSP 2021, 166).

## M6 동시성 (12장)

- 15-213 대응: 강의 "Concurrent Programming", "Synchronization: Basic/Advanced", "Thread-Level Parallelism", Proxy Lab
- 쌓이는 코드: `sysx::sync`(Semaphore, Sbuf, RW 락), `apps/proxy`
- Rust: `Send`·`Sync`, `Arc`, `Mutex`·`Condvar`·`RwLock`, `thread::scope`, 채널, 원자 타입과 `Ordering`, 가드 타입(`Deref`·`DerefMut`), `'static` 바운드. async는 선택

| 단계 | CSAPP 절 | 할 일 | 확인 |
|---|---|---|---|
| M6-1 프로세스와 I/O 다중화 | 12.1~12.2 | 구현: fork 기반 echo 서버, select 기반 이벤트 서버(상태 머신) | nc 여러 개로 확인 |
| M6-2 스레드와 공유 변수 | 12.3~12.4 | 구현: 스레드 기반 echo 서버 / 실험: 공유 변수 표(C 대 Rust 컴파일러) | 실험 기록 |
| M6-3 세마포어와 동기화 | 12.5 | 구현: Semaphore, Sbuf, readers-writers, 프리스레딩 echo 서버 / 실험: badcnt | 테스트 |
| M6-4 병렬성과 동시성 문제 | 12.6~12.7 | 실험: psum 속도 향상과 false sharing, 스레드 안전·재진입·경쟁·교착 | 측정 |
| M6-5 Proxy Lab | 11·12장 종합 | 구현: 순차 → 동시 → 캐시 | driver.sh 70/70 |

논문 세션 후보: Understanding Memory and Thread Safety Practices and Issues in Real-World Rust Programs (PLDI 2020, 150). 동향: Learning from Mistakes (ASPLOS 2008, 1,039), RustBelt (POPL 2018, 521), Tree Borrows (PLDI 2025, 18).

## (선택) M7 파일 시스템

CSAPP 밖이다. CMU 15-213의 SFS 랩(메모리 안의 파일 시스템)과 Stanford CS111의 파일 시스템 과제를 본떠, M6를 끝낸 뒤 원하면 한다: inode와 블록, 디렉터리와 경로 해석, 동시 접근.

## CSAPP 절 커버리지

모든 절이 어느 단계에서 다뤄지는지 정리했다. 절 번호는 CS:APP3e 공식 목차로 확인했다. 개념 문서 끝의 체크리스트가 이 표의 세부다.

| 장 | 절 → 단계 |
|---|---|
| 6 | 6.1.1~6.1.4, 6.2.1~6.2.3, 6.3.1~6.3.2 → M1-1 · 6.4.1~6.4.4 → M1-2 · 6.4.5~6.4.7 → M1-3 · 6.5, 6.6.1~6.6.3 → M1-4 |
| 7 | 7.1~7.4 → M2-1 · 7.5, 7.6.1~7.6.3 → M2-2 · 7.7.1~7.7.2, 7.8, 7.9, 7.14 → M2-3 · 7.10, 7.11, 7.12, 7.13.1~7.13.3 → M2-4 |
| 10 | 10.1~10.4, 10.5.1~10.5.2 → M3-1 · 10.6~10.11 → M3-2 |
| 8 | 8.1.1~8.1.3, 8.2.1~8.2.5, 8.3, 8.4.1~8.4.6, 부록 A.1~A.2 → M3-3 · 8.5.1~8.5.7, 8.6, 8.7 → M3-4 |
| 9 | 9.1, 9.2, 9.3.1~9.3.6, 9.4, 9.5, 9.6.1~9.6.4 → M4-1 · 9.7.1~9.7.2, 9.8.1~9.8.4 → M4-2 · 9.9.1~9.9.12 → M4-3 · 9.9.13~9.9.14 → M4-4 · 9.10.1~9.10.3, 9.11.1~9.11.10 → M4-5 |
| 11 | 11.1, 11.2, 11.3.1~11.3.3, 11.4.7 → M5-1 · 11.4.1~11.4.6, 11.4.8~11.4.9 → M5-2 · 11.5.1~11.5.4, 11.6 → M5-3 |
| 12 | 12.1.1~12.1.2, 12.2.1~12.2.2 → M6-1 · 12.3.1~12.3.8, 12.4.1~12.4.3 → M6-2 · 12.5.1~12.5.5 → M6-3 · 12.6, 12.7.1~12.7.5 → M6-4 |

각 장의 요약 절(6.7, 7.15, 8.8, 9.12, 10.12, 11.7, 12.8)은 마일스톤 마무리에서 한 쪽 정리로 다시 본다.

## Rust 문법 커버리지

| 문법 | 처음 쓰는 곳 | 다시 쓰는 곳 |
|---|---|---|
| 구조체, enum, `match`, `Option`, `Result` | M1-2 | 전부 |
| 이터레이터, 클로저 | M1-2 | M2-2(`Iterator` 직접 구현) |
| 모듈, 워크스페이스, 단위·통합 테스트 | M1-2 | 전부 |
| 트레잇, 제네릭, 트레잇 객체 | M1-3 | M2, M6 |
| 수명 | M2-1 | M5-1, M5-3 |
| `TryFrom`·`From`, 오류 enum | M2-1 | 전부 |
| FFI 기초(`extern "C"`, `build.rs`, `cdylib`), `unsafe` | M2-2, M2-4 | M3~M6 |
| RAII(`Drop`), `Read`·`Write` 구현 | M3-1 | M3~M6 |
| `static`, 원자 타입 | M3-4 | M6 |
| `Deref` | M4-2 | M6-3 |
| 원시 포인터, `Layout`, `GlobalAlloc`, `UnsafeCell`, Miri | M4-3 | M4-4 |
| 스레드, `Send`·`Sync`, `Arc`, `Mutex`·`Condvar` | M6-2 | M6-3~M6-5 |
| 원자 타입의 `Ordering`, `#[repr(align(64))]` | M6-4 | — |
| async | M6 뒤(선택) | — |

## 크레이트 정책

- 기본은 std + libc다.
- 튜터가 쓰는 CLI는 clap(derive)을 쓴다.
- 단계별로 허용: rustc-demangle(M2-2), rayon(M6-4 비교), mio·tokio(M6 뒤 선택).
- 개념을 감추는 크레이트(nix, memmap2, crossbeam, tokio 등)는 직접 구현을 끝낸 뒤 비교와 코드 리딩에만 쓴다.

## 환경

- Linux x86-64 네이티브. Intel N150(L1d 32 KiB × 4, L2 2 MiB, L3 6 MiB), 커널 6.8.0-147-generic(2026-11-02 `lscpu`, `uname -r`).
- 있는 도구(2026-11-02 확인): gcc, make, gdb, rust-gdb, binutils(readelf, objdump, nm), strace, valgrind, perf, gnuplot, python3, curl, nc, telnet, Rust stable·nightly.
- 없는 도구는 처음 쓰는 단계에서 설치한다: ltrace, hyperfine, wrk, cargo-show-asm(`cargo asm`), Miri(`rustup component add miri --toolchain nightly`).

## C 개발자를 위한 Rust 대응표

C와 어셈블리를 이미 아니, Rust는 "C에서 사람이 지키던 규칙을 컴파일러가 검사한다"는 관점으로 배우는 것이 가장 빠르다. 브리핑도 이 표를 기준으로 설명한다.

| C에서는 | Rust에서는 | 핵심 차이 |
|---|---|---|
| malloc/free 책임 규칙 | 소유권 + `Drop` | 해제 시점을 컴파일러가 정함 |
| `const T*` / `T*` | `&T` / `&mut T` | `&mut`는 유일해야 함(restrict가 강제되는 셈) |
| 포인터 + 길이 | 슬라이스 `&[T]` | 길이가 타입에 붙고 경계 검사 |
| NULL | `Option<T>` | `Option<&T>`는 포인터 크기 그대로 |
| -1 + errno | `Result<T, io::Error>` | `?` 연산자로 전파 |
| tagged union | enum + `match` | 빠진 분기는 컴파일 오류 |
| 함수 포인터 구조체(vtable) | `dyn Trait` | 제네릭은 단형화로 인라인 |
| goto cleanup | `Drop`(RAII) | 조기 반환에도 정리 보장 |
| 전역 변수 | `static` + 원자 타입·`Mutex` | `static mut` 참조는 금지 |
| 스레드 안전은 문서의 약속 | `Send` / `Sync` | 컴파일러가 검사 |
| 어디서나 가능한 위험 연산 | `unsafe` 블록 | 위험을 작은 구역에 가두고 안전한 API로 감싼다 |

생성 코드가 궁금하면 `cargo asm`(cargo-show-asm 설치 후)이나 `objdump -d`로 어셈블리를 연다. 3장을 아는 것이 여기서 큰 무기가 된다.

## Rust 2024 에디션 주의

cargo new의 기본 에디션(1.85부터)이고, 시스템 코드에서 바로 부딪히는 변경점이다. 예전 블로그 예제와 다르게 써야 한다.

- extern 블록은 `unsafe extern "C" { ... }`로 쓴다.
- `#[no_mangle]`은 `#[unsafe(no_mangle)]`로 쓴다. `export_name`, `link_section`도 같다.
- `static mut`에 대한 참조는 금지된다. 원자 타입이나 직접 만든 래퍼를 쓴다.
- `std::env::set_var`·`remove_var`가 unsafe다. 멀티스레드에서 환경 변수 접근이 불건전할 수 있기 때문이며, 12장 스레드 안전성의 실제 사례다.
- unsafe fn 안에서도 unsafe 연산은 `unsafe { }`로 감싸야 경고가 없다.

출처: [Rust 2024 에디션 가이드](https://doc.rust-lang.org/edition-guide/rust-2024/index.html), [새로 unsafe가 된 함수](https://doc.rust-lang.org/edition-guide/rust-2024/newly-unsafe-functions.html)

## 대형 코드 읽는 법

목표 ①(큰 코드베이스 읽기)을 위해 마일스톤마다 한 번은 실제 코드를 읽는다. 튜터의 골격을 읽는 것도 같은 연습이다.

1. 질문을 들고 읽는다. 예: "std는 `Command::spawn`에서 exec 실패를 어떻게 부모에게 알리나?"
2. `cargo doc --open`으로 공개 API와 핵심 타입의 지도부터 본다.
3. 테스트와 예제부터 읽는다. 사용법과 불변식이 함께 보인다.
4. rust-analyzer의 정의로 이동, 참조 찾기로 호출 경로를 따라간다.
5. 다 읽으면 "내 코드(cachesim, elf, sysx …)의 어느 부분에 해당하는가"를 한 줄로 적는다.

마일스톤별 후보: M1 std `Vec`의 용량 증가, M2 gimli-rs/object의 ELF 파서, M3 std `process::Command`의 유닉스 구현과 signal-hook, M4 memmap2와 linked_list_allocator, M5 httparse, M6 std `Mutex`·`Condvar`의 futex 구현과 `mpsc`.

## 꺾일 때

"꺾임" + 한 줄 상황을 보내면, 원인을 같이 짚고 그 단계 목표를 줄여 바로 다시 굴러가게 한다.

| 유형 | 신호 | 첫 처방 |
|---|---|---|
| 완벽주의 | 돌아가기도 전에 리팩터링, push 미루기, 하루 빠지면 "망했다" | 테스트가 통과하면 완료. 리뷰의 설계 조언은 다음 단계에서 반영해도 된다 |
| AI 무가치론 | "AI면 10초면 짜는데 내가 왜?" | 목표는 코드가 아니라 판정하는 능력. 끝낸 뒤 내 버전과 AI 버전을 비교해 틀린 곳 찾기 |
| 나태 | 시작을 미룸, "오늘은 피곤하니까" | 최소 목표를 "개념 문서 한 절 읽기"로 낮추기. 다음에 채울 `todo!()` 하나를 정해 두고 끝내기 |
| 막힘 | 한 버그에 1시간 넘게 매달림 | 15분이면 힌트 1, 2시간이면 힌트 3으로 그날 마무리 |
| Rust 벽 | borrow checker와 싸우며 "C였으면 5분인데" | `clone()` 허용. 같은 컴파일 오류를 세 번 만나면 미니 강의 요청 |
| 중반 늪 (M3~M4) | 신선함은 떨어졌는데 난이도는 최고 | 선택 실험을 건너뛰고 랩으로 직행. 한 달 전 내 코드와 비교하기 |
| 공백 후 복귀 | 며칠 끊긴 뒤 다시 열기가 무서움 | 따라잡지 말고 일정을 통째로 미루기. 첫날은 개념 문서의 자작 문제 하나와 가장 작은 `todo!()` 하나 |

규칙은 하나, 정해 둔 휴식일 말고는 이틀 연속으로 빠지지 않기다. 무기력이 몇 주씩 이어지면 공부보다 컨디션 문제일 수 있으니, 그때는 쉬는 게 먼저다.

## 참고 자료

| 마일스톤 | The Book |
|---|---|
| M1 | 10장(제네릭·트레잇), 11장(테스트), 14.3절(워크스페이스) |
| M2 | 10.3절(수명), 13장(클로저·이터레이터), 20.1절(Unsafe Rust) |
| M3 | 15장(스마트 포인터·`Drop`·`Deref`) |
| M4 | 20.1절 다시 보기 |
| M5 | 21.1절(단일 스레드 웹 서버) |
| M6 | 16장(동시성), 21장(멀티스레드 웹 서버), 17장(async, 선택) |

- [CS:APP3e 랩 페이지](https://csapp.cs.cmu.edu/3e/labs.html): Cache·Shell·Malloc·Proxy Lab 자습용 핸드아웃
- [The Rustonomicon](https://doc.rust-lang.org/nomicon/): unsafe, FFI, 원시 포인터(M3부터)
- [Rust Atomics and Locks](https://mara.nl/atomics/)(Mara Bos): M6에서 1~2장, readers-writers와 락을 만들 때 8~9장
- [libc 크레이트 문서](https://docs.rs/libc)와 man 2·3·7 페이지: 시스템 콜 시그니처와 오류 코드

## 출처

- 대학 과목: 위 "깊이의 기준"의 링크(2026-11-02 확인)
- 인용 수: [Semantic Scholar API](https://api.semanticscholar.org/graph/v1)(2026-11-02 조회)
- CSAPP 절 번호: [CS:APP3e 서문과 목차](https://csapp.cs.cmu.edu/3e/pieces/preface3e.pdf)
- Part B 만점 기준: Cache Lab 핸드아웃의 `driver.py`
