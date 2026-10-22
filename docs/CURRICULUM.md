# CSAPP 6–12장 × Rust 시스템 프로그래밍 커리큘럼

Oct 14, 2026 · @teyn

> 이 파일이 원본이다. claude.ai에 있던 같은 문서는 2026-10-16에 옮겨 온 사본이므로, 고칠 때는 이 파일을 고친다.

## 한눈에 보기

0주차 주말 2일 + 9주, 총 65개의 하루 완결 프로젝트로 CSAPP 6\~12장 핵심 키워드 전부를 Rust로 직접 구현합니다. 중간에 버퍼 주 2주를 넣어 Oct 17, 2026 시작 기준 Jan 3, 2027에 끝납니다.

### 목표

- Rust를 손발처럼 쓰고, 큰 코드베이스도 읽어 낼 수 있는 힘
- 시스템 소프트웨어 개념을 "구현해 본 지식"으로 만들기

### 하루 단위

- 평일: 60\~90분 미니 프로젝트. "핵심"만 하면 60분, "확장"은 시간이 남을 때.
- 주말 ★: 4\~8시간 통합 프로젝트. 셸·malloc·웹 서버·프록시 같은 큰 랩은 전부 주말에 둡니다.
- 밀리면 주말 오전에 따라잡습니다. 2주차가 끝날 때 속도를 점검해, 필요하면 주말 ★를 둘로 쪼갭니다.

### 쉬는 날과 버퍼 주

9주를 하루도 쉬지 않고 달리면 중반에 꺾일 가능성이 큽니다. 그래서 쉬는 것도 일정에 넣었습니다.

- **주 1일 휴식**: 평일 중 하루는 쉽니다. 요일을 정해 두는 게 좋습니다(예: 수요일). 그날 유닛은 같은 주 토요일 오전에 먼저 합니다.
- **버퍼 주 2회**: 3주차 뒤 Nov 9, 2026\~Nov 15, 2026, 6주차 뒤 Dec 7, 2026\~Dec 13, 2026. 평일은 쉬고, 토요일에는 밀린 유닛 따라잡기·백지 복습·체크포인트를 하고, 일요일은 완전히 쉽니다.
- **백지 복습**: 책과 코드를 덮고, 지난 3주의 핵심 개념을 빈 종이에 설명해 본 뒤 막힌 곳만 다시 봅니다.
- **앞당겨 쓰기**: 아프거나 일이 몰리면 버퍼 주를 앞당겨 써도 됩니다. 버퍼를 다 쓰면 그만큼 끝나는 날을 미룹니다.

### 장 순서와 이유: 6 → 7 → 10 → 8 → 9 → 11 → 12 → 캡스톤

1. 6장 메모리 계층: unsafe 없이 순수 Rust로 시작할 수 있고, 캐시 개념이 TLB(9장)·false sharing(12장)·프록시 캐시의 바닥이 됩니다.
2. 7장 링킹: 바이너리 파싱으로 수명(lifetime)을 익히고, 링킹을 통해 FFI를 자연스럽게 도입합니다. ELF와 로딩은 8장 execve, 9장 메모리 매핑의 전제입니다.
3. 10장 시스템 수준 I/O: 시스템 콜과 fd가 이후 모든 것의 바닥입니다. 여기서 만든 Fd·RIO를 셸·웹 서버·프록시까지 계속 씁니다.
4. 8장 예외적 제어 흐름: fd 위에 프로세스와 시그널을 쌓고, 셸에서 10장의 dup2를 다시 씁니다.
5. 9장 가상 메모리: page fault(8장 fault), COW(8장 fork), 로딩(7장), TLB(6장 캐시)가 모두 전제라 이 자리가 최적입니다. malloc은 7장 링킹 지식으로 공식 채점기에 연결합니다.
6. 11장 네트워크: 소켓은 fd(10장), CGI는 fork·exec·dup2(8·10장), 정적 콘텐츠는 mmap(9장)입니다.
7. 12장 동시성: 앞의 모든 것 위에서 동시성을 다루며, Rust의 Send/Sync가 가장 빛나는 구간입니다.
8. 캡스톤: 동시 캐싱 프록시로 6·10·11·12장을 묶고, async와 대형 코드 리딩으로 마무리합니다.

### 주차 요약

| 주차 (시작일) | 범위 | 주말 ★ | Rust 포커스 |
| --- | --- | --- | --- |
| 0 (10/17\~) | Rust 기초 | xxd-lite, wc-lite | 소유권·빌림·구조체·열거형·에러 처리 |
| 1 (10/19\~) | 6장 메모리 계층 | 캐시 시뮬레이터, 행렬 블로킹 | 트레잇·테스트·모듈 |
| 2 (10/26\~) | 7장 링킹 | ELF 분석기, 동적 링킹·인터포지셔닝 | 수명·이터레이터·첫 FFI |
| 3 (11/2\~) | 10장 I/O, 8장 진입 | 예외·시스템 콜 실험, 프로세스 실험 | unsafe·RAII(Drop)·std I/O 트레잇 |
| 버퍼 A (11/9\~) | 쉬기 + 1\~3주차 복습 | 토요일만: 따라잡기·백지 복습·체크포인트 | sysx 정리(선택) |
| 4 (11/16\~) | 8장 시그널 | 미니 셸 tsh (2일) | 전역 상태·원자 타입·큰 프로그램 구조 |
| 5 (11/23\~) | 9장 번역·매핑 | 페이징 시뮬레이터, 쓰기 추적기 | 원시 포인터·워크스페이스·건전성 |
| 6 (11/30\~) | 9장 동적 할당 | malloc 완성, malloc 추적 + GC | GlobalAlloc·Miri·아레나 패턴 |
| 버퍼 B (12/7\~) | 쉬기 + 4\~6주차 복습 | 토요일만: 따라잡기·백지 복습·체크포인트 | 워크스페이스 정리(선택) |
| 7 (12/14\~) | 11장 네트워크, 12장 진입 | Tiny 웹 서버, 동시 echo 서버 | FFI 구조체·프로토콜 파싱 |
| 8 (12/21\~) | 12장 동시성 | 프리스레딩·교착상태, psum | Send/Sync·Arc·Mutex·Condvar·원자 타입 |
| 9 (12/28\~) | 캡스톤 | async 프록시, 대형 코드 리딩 | async·대규모 구조 |

## 공부 방법

하루는 브리핑 → 예측 → 구현 → 검증 → 리뷰 → 복습으로 돌아갑니다. 개념과 핵심 문법은 제가 주고, 구현은 직접 하고, 결과는 제가 리뷰합니다.

### 평일 루프 (60분)

1. 브리핑 (10분): "D12 시작"이라고 보내면 오늘의 명세(목적·사용법·기능·완료 기준), 개념 핵심, 필요한 Rust 문법, 흔한 함정, 예측 질문 2개를 받습니다. 정답 코드는 주지 않습니다.
2. 예측 (5분): 실행 전에 결과를 먼저 적습니다. 예: "열 우선 순회는 몇 배 느릴까?" 틀린 예측이 가장 많이 가르쳐 줍니다.
3. 구현 (35분): 직접 짭니다. 15분 넘게 막히면 "힌트 1 → 2 → 3" 순으로 요청합니다(방향 → 구체적 접근 → 코드 조각).
4. 검증 (5분): 테스트, 공식 드라이버, strace·perf·gdb로 확인하고 예측과 비교합니다.
5. 리뷰 (5분): "D12 리뷰"를 요청합니다. 튜터(Claude Code)가 저장소에서 check.sh·테스트·clippy를 직접 돌린 뒤 개념 오해, Rust 관용구, unsafe 건전성, 성능 네 관점으로 피드백하고, 요지를 그 Day의 REVIEW.md에 남깁니다.
6. 복습: 다음 날 브리핑은 전날 내용 퀴즈 2문제로 시작합니다.

**CSAPP 예습**: 각 주차 첫머리의 "CSAPP 읽기"에 적힌 절을 그날 공부 전에 자투리 시간(15\~20분)에 훑어 오세요. 브리핑은 그 위에서 핵심만 짚고, 책의 연습문제(Practice Problem) 1\~2개를 예측 단계에 씁니다. 주말 ★는 오전에 해당 절을 정독하고 시작합니다.

### 명세 양식

매일 브리핑은 그날 만들 프로그램의 명세로 시작합니다. 명세는 그날 패키지의 README 맨 위에 붙이고, 그 아래에 기록을 적습니다.

1. 목적: 무엇을 하는 프로그램인지, 실무와 이 커리큘럼에서 왜 필요한지, 뒤에서 어디에 다시 쓰이는지
2. 사용법: 명령 형태와 옵션. 라이브러리를 만드는 날은 공개 API(타입·함수 시그니처)
3. 기능: 반드시 구현할 동작 F1, F2 …
4. 출력 형식: 정확한 형식과 예시
5. 오류 처리: 잘못된 입력에 대한 메시지와 종료 코드
6. 제약: 쓸 수 있는 것과 없는 것
7. 완료 기준: 패키지의 `check.sh`. 표준 출력·표준 에러·종료 코드를 모두 비교하고, 경계값(0, 1, n−1, n, n+1, 아주 큰 값)을 넣습니다
8. 범위 밖과 확장: 안 해도 되는 것, 시간이 남으면 할 것

명세의 출력 예시와 완료 기준은 가능하면 참조 구현으로 미리 돌려 본 뒤 드립니다. 참조 구현 코드는 드리지 않습니다.

저장소 루트에서 Claude Code를 열고 "D12 시작"이라고 보내면 됩니다. 튜터 지침은 `CLAUDE.md`, 절차는 `.claude/skills/`에 있습니다.

### 주말 루프

- 오전 브리핑 → 단계(마일스톤)마다 중간 리뷰 → 저녁 최종 리뷰.
- 마지막 30\~60분은 그 주 주제와 맞닿은 실제 코드를 읽습니다(각 주의 "코드 리딩").

### 원칙

- 모든 unsafe 블록 위에 `// SAFETY:` 주석으로 왜 안전한지 씁니다. 리뷰 1순위 항목입니다.
- 측정은 항상 `--release`로 합니다. 측정 없는 성능 주장은 하지 않습니다.
- 매일 README에 "예측 / 결과 / 배운 것" 3줄을 남깁니다. 9주 뒤 그대로 포트폴리오가 됩니다.

### 대형 코드 읽는 법

1. 질문을 들고 읽습니다. 예: "tokio는 어디서 epoll\_wait를 부르나?"
2. `cargo doc --open`으로 공개 API와 핵심 타입의 지도부터 봅니다.
3. 테스트와 예제부터 읽습니다. 사용법과 불변식이 함께 보입니다.
4. rust-analyzer의 정의로 이동·참조 찾기로 호출 경로를 따라갑니다.
5. 다 읽으면 "내 sysx의 어느 부분에 해당하는가"를 한 줄로 적습니다.

### 매일의 기록

- README의 "예측 / 결과 / 배운 것" 3줄 아래에 숫자 세 개를 더 적습니다. 재미(1\~5), 막힌 시간(분), 받은 힌트 단계(0\~3).
- 튜터는 세션이 바뀌면 이전 대화를 기억하지 못합니다. 체크포인트 판단의 근거는 전부 저장소의 기록(README 기록, REVIEW.md, BUGS.md, git log)입니다.

### 체크포인트

- **2주차 끝**: 속도 점검. 평일 유닛이 계속 90분을 넘기면 분량을 줄입니다.
- **버퍼 A·B 토요일과 9주차 끝**: "체크포인트"라고 보내면 저장소 기록을 읽고 속도·재미·힌트 의존도의 추세를 정리해 드립니다. 다음 구간의 분량 조정과, 어느 방향(성능·툴체인·OS·런타임·네트워크)이 맞는지에 대한 가설을 함께 냅니다.
- 0\~2주차의 Rust 문법 고생은 적성 신호로 보지 않습니다. 보는 것은 세 가지입니다. 예측이 틀렸을 때 "왜"를 파고드는지, 같은 종류의 버그를 두 번째엔 더 빨리 잡는지, 힌트 의존이 줄어드는지.

### 꺾일 때

"꺾임 + 한 줄 상황"만 보내면, 원인을 같이 짚고 그날 목표를 줄여 바로 다시 굴러가게 합니다.

| 유형 | 신호 | 첫 처방 |
| --- | --- | --- |
| 완벽주의 | 돌아가기도 전에 리팩터링, push 미루기, 하루 빠지면 "망했다" | 핵심이 돌고 테스트가 통과하면 완료. 60분 타이머가 울리면 그 상태로 커밋. 리뷰는 "필수"만 고치기 |
| AI 무가치론 | "AI면 10초면 짜는데 내가 왜?" | 목표는 코드가 아니라 판정하는 능력. 끝낸 뒤 내 버전과 AI 버전을 비교해 틀린 곳 찾기 |
| 나태 | 시작을 미룸, "오늘은 피곤하니까" | 최소 목표를 "D번호 시작" 보내기로 낮추기. 다음 날 통과시킬 실패 테스트를 남기고 끝내기 |
| 막힘 | 한 버그에 1시간 넘게 매달림 | 15분이면 힌트 1단계, 2시간이면 힌트 3단계로 그날 마무리. 버그 일지(증상 → 원인 → 교훈) 남기기 |
| Rust 벽 (0\~2주차) | borrow checker와 싸우며 "C였으면 5분인데" | 초반엔 clone() 허용. 같은 컴파일 에러를 세 번 만나면 미니 강의 요청 |
| 중반 늪 (4\~6주차) | 신선함은 떨어졌는데 난이도는 최고 | 버퍼 주를 앞당겨 쓰기. 3주 전 내 코드와 비교하기 |
| 공백 후 복귀 | 며칠 끊긴 뒤 다시 열기가 무서움 | 따라잡지 말고 일정을 통째로 미루기. 첫날은 퀴즈와 가장 작은 유닛 하나 |

규칙은 하나, 정해 둔 휴식일 말고는 이틀 연속으로 빠지지 않기입니다. 무기력이 몇 주씩 이어지면 공부보다 컨디션 문제일 수 있으니, 그때는 쉬는 게 먼저입니다.

## 환경과 규칙

Linux x86-64 네이티브 환경이라 CSAPP 실습을 그대로 재현할 수 있습니다. 시스템 콜은 libc로 직접 부르고, 안전한 래퍼는 직접 만듭니다.

### 도구

- Rust: rustup(stable + nightly, Miri·ASan용), rust-analyzer, clippy, rustfmt, cargo-show-asm(`cargo asm`)
- C·바이너리: gcc, make, binutils(readelf·objdump·nm), gdb(rust-gdb)
- 관찰·측정: strace, ltrace, valgrind, perf, hyperfine
- 그래프·네트워크: gnuplot 또는 python3 + matplotlib, curl, nc, wrk

### 크레이트 정책

- 기본은 std + libc입니다.
- 개념을 감추는 크레이트(nix, memmap2, crossbeam, tokio 등)는 직접 구현을 끝낸 뒤 비교와 코드 리딩에만 씁니다.
- 허용: rustc-demangle(2주차), rayon(8주차 비교), mio·tokio(9주차). clap·criterion은 선택입니다.

### 저장소 구조

Cargo 워크스페이스 하나로 9주를 끝까지 끌고 갑니다. sysx는 3주차부터 매주 자라고, 셸·웹 서버·프록시가 모두 그 위에 섭니다.

```text
csapp-rs/
  Cargo.toml        # 가상 매니페스트: resolver·공통 에디션·린트·릴리스 프로필
  Cargo.lock        # 루트에 하나, 커밋함
  README.md         # Day 인덱스
  templates/        # day-README.md: 명세 + 기록 양식
  days/dNN-이름/    # 날마다 패키지 하나: cargo new days/dNN-이름 --name 이름 (README·BRIEF·check.sh·REVIEW)
  concepts/         # dNN-주제.md: 그날 과제가 쓰는 CSAPP 개념 문서
  crates/sysx/      # 개인 시스템 라이브러리: fd, rio, proc, signal, mmap, net, sync
  crates/cachesim/  # 1주차 → 5주차 vmsim에서 재사용
  crates/elf/       # 2주차 → 9장 로딩 관찰에 재사용
  labs/             # CMU 핸드아웃 (cache, shell, malloc, proxy)
  papers/           # 논문 5줄 노트 (P1.md …)
```

처음 세팅할 때 두 가지를 지킵니다. `days/` 폴더를 먼저 만든 뒤 `cargo new`를 해야 패키지 안에 `.git`이 또 생기지 않습니다. 부모 폴더가 없으면 cargo가 바깥 저장소 안이라는 걸 알아채지 못하기 때문입니다. 그리고 `days/` 안에는 패키지만 둡니다. `Cargo.toml`이 없는 폴더가 하나라도 있으면 `members = ["days/*"]` 때문에 워크스페이스 전체 빌드가 실패합니다.

이름·커밋·기록 같은 저장소 규칙은 저장소의 `RULES.md`가 기준이고, 리뷰할 때 함께 확인합니다. 커밋은 `영역: 한 일` 형식(`D7`, 크레이트 이름, `repo`)이고, 미완성은 끝에 `(WIP)`를 붙입니다.

### CMU 공식 랩 활용

[CS:APP3e 랩 페이지](https://csapp.cs.cmu.edu/3e/labs.html)의 Self-Study Handout을 받아 구현은 Rust로, 채점은 공식 드라이버로 합니다. 해답은 강사에게만 제공됩니다.

| 랩 | 쓰는 날 | Rust로 붙이는 방법 |
| --- | --- | --- |
| Cache Lab | D6 | 핸드아웃의 printSummary가 남기는 결과 파일 형식을 똑같이 쓰면 test-csim으로 채점 (x86-64 필수) |
| Shell Lab | D27\~D28 | sdriver.pl이 실행 파일만 보므로 Rust tsh를 그대로 테스트 |
| Malloc Lab | D41 | staticlib으로 mm\_init·mm\_malloc·mm\_free·mm\_realloc을 내보내고, Makefile에서 mm.o 대신 링크 (7장 복습) |
| Proxy Lab | D57\~D61 | driver.sh가 ./proxy 바이너리를 테스트 |

### Rust 2024 에디션 주의

cargo new의 기본 에디션(1.85부터)이고, 시스템 코드에서 바로 부딪히는 변경점입니다. 예전 블로그 예제와 다르게 써야 합니다.

- extern 블록은 `unsafe extern "C" { ... }`로 씁니다.
- `#[no_mangle]`은 `#[unsafe(no_mangle)]`로 씁니다. export\_name·link\_section도 같습니다.
- `static mut`에 대한 참조는 금지됩니다. 원자 타입이나 직접 만든 래퍼를 씁니다.
- `std::env::set_var`·`remove_var`가 unsafe입니다. 멀티스레드에서 환경 변수 접근이 불건전할 수 있기 때문이며, 12장 스레드 안전성의 실제 사례입니다.
- unsafe fn 안에서도 unsafe 연산은 `unsafe { }`로 감싸야 경고가 없습니다.

출처: [Rust 2024 에디션 가이드](https://doc.rust-lang.org/edition-guide/rust-2024/index.html), [새로 unsafe가 된 함수](https://doc.rust-lang.org/edition-guide/rust-2024/newly-unsafe-functions.html)

## C 개발자를 위한 Rust 대응표

C와 어셈블리를 이미 아니, Rust는 "C에서 사람이 지키던 규칙을 컴파일러가 검사한다"는 관점으로 배우는 것이 가장 빠릅니다. 브리핑도 이 표를 기준으로 설명합니다.

| C에서는 | Rust에서는 | 핵심 차이 |
| --- | --- | --- |
| malloc/free 책임 규칙 | 소유권 + Drop | 해제 시점을 컴파일러가 정함 |
| const T\* / T\* | &T / &mut T | &mut는 유일해야 함 (restrict가 강제되는 셈) |
| 포인터 + 길이 | 슬라이스 &\[T\] | 길이가 타입에 붙고 경계 검사 |
| NULL | Option\<T> | Option<&T>는 포인터 크기 그대로 |
| -1 + errno | Result\<T, io::Error> | ? 연산자로 전파 |
| tagged union | enum + match | 빠진 분기는 컴파일 에러 |
| 함수 포인터 구조체(vtable) | dyn Trait | 제네릭은 단형화로 인라인 |
| goto cleanup | Drop (RAII) | 조기 반환에도 정리 보장 |
| 전역 변수 | static + 원자 타입·Mutex | static mut 참조는 금지 |
| 스레드 안전은 문서의 약속 | Send / Sync | 컴파일러가 검사 |
| 어디서나 가능한 위험 연산 | unsafe 블록 | 위험을 작은 구역에 가두고 안전한 API로 감쌌 |

생성 코드가 궁금하면 언제든 `cargo asm`으로 어셈블리를 열어 봅니다. 3장을 아는 것이 여기서 큰 무기가 됩니다.

## 0주차 — Rust 기초 (시작 전 주말)

C를 아는 상태에서 소유권·빌림·에러 처리를 이틀 만에 몸에 붙이는 주간입니다. 여기서 만든 xxd-lite는 2주차 ELF 분석 때 디버깅 도구로 계속 씁니다. 막히는 문법은 Rustlings로 보충해도 좋습니다(선택).

### D0-토 ★ xxd-lite — 헥스 덤프 도구

- **읽기**: The Book 1\~4장 (설치 \~ 소유권)
- **개념**: 파일은 바이트열이고, 정수는 리틀 엔디언으로 저장된다
- **Rust**: cargo, let/mut, 정수 타입과 as 캐스팅, Vec\<u8>, String vs &str, 소유권 이동과 빌림, chunks(16), 포맷 지정자 {:08x} {:02x}
- **만들 것**: `xxd-lite <파일> [-s 시작] [-l 길이]` — 오프셋·헥스·ASCII 3열 출력, 실제 xxd 출력과 diff로 비교
- **확장**: 4바이트씩 묶어 리틀 엔디언 정수로 보여 주는 옵션

### D0-일 ★ wc-lite — 에러 처리와 테스트가 있는 CLI

- **읽기**: The Book 5\~9장, 11장 (구조체·열거형·모듈·컨렉션·에러·테스트)
- **Rust**: struct Counts + impl, enum으로 옵션 표현, Result와 ?, Box\<dyn Error>, mod로 파일 분리, #\[test\]
- **만들 것**: `wc-lite [-l|-w|-c] 파일...` — GNU wc와 출력이 같은지 테스트, 없는 파일은 에러를 출력하고 다음 파일로 계속, 종료 코드 1
- **확장**: 표준 입력 지원, 큰 파일에서 read\_to\_string과 BufReader 속도 비교 (10장에서 직접 만든 RIO와 다시 비교)

## 1주차 — 메모리 계층 (6장)

평일에 만든 조각(주소 분해·트레이스 파서·LRU 세트)이 토요일 캐시 시뮬레이터로 조립되고, 일요일에는 그 시뮬레이터로 내 코드의 미스를 쌁니다. Rust는 구조체·트레잇·테스트·모듈을 익힙니다. 읽기: The Book 10장(제네릭·트레잇), 12장, 14.3절(워크스페이스).

**CSAPP 읽기**: D1 6.4.1\~6.4.2 · D2 6.1.1, 6.2, 6.3, 6.6.1 · D3 6.3.1 · D4 6.4.3\~6.4.4 · D5 6.1.2\~6.1.4 · D6 6.4.5\~6.4.7 · D7 6.5, 6.6.2\~6.6.3

**논문 각주** (참고 자료 표): P1 (D5) · P2·P3 (D6) · P4·P5 (D7)

### D1 월 · addr-split — 캐시 주소 분해기

- **개념**: 캐시 구성 S=2^s, E, B=2^b, m / 캐시 크기 C = S×E×B / 주소 = tag | set index | block offset, t = m − s − b
- **Rust**: u64·usize, 시프트·마스크, std::env::args, u64::from\_str\_radix, {:#x}·{:b} 포맷
- **만들 것**: `addr-split 0x7ff000a4 -s 4 -E 2 -b 5` → tag·set·offset과 C 출력
- **확장**: 같은 세트에 매핑되는 주소 5개 자동 생성 (충돌 실험용)
- **키워드**: 캐시 구성(S, E, B, m), tag / set index / block offset

### D2 화 · mountain — 메모리 마운틴

- **개념**: 시간·공간 지역성, stride-k 참조, 메모리 계층 구조, SRAM(캐시)과 DRAM(메인 메모리)의 지연 차이
- **Rust**: Vec의 소유권, &\[T\] 슬라이스로 빌려주기, Instant, std::hint::black\_box, release와 debug 빌드의 차이
- **만들 것**: 크기 16KB\~256MB × stride 1\~16의 읽기 처리량(MB/s)을 CSV로 출력 → 3D 그래프 → L1·L2·L3·DRAM 능선을 `lscpu`의 캐시 크기와 대조
- **확장**: CSAPP처럼 4×4 언롤링과 다중 누산기 적용 전후 비교 (5장 복습)
- **키워드**: 지역성, stride-1 참조, 메모리 계층 구조, SRAM vs DRAM, 메모리 마운틴

### D3 수 · trace-parse — 메모리 트레이스 파서

- **개념**: 캐시 시뮬레이션의 입력은 메모리 접근 트레이스(I·L·S·M), 생성은 valgrind lackey
- **Rust**: enum Op, struct Access, match, Option·Result, ?, lines()·split, 에러가 난 줄 번호 보고
- **만들 것**: `valgrind --tool=lackey --trace-mem=yes ls`로 트레이스 생성 → 파싱 후 접근 종류별 개수와 주소 범위 출력 (I 줄은 무시)
- **확장**: 서로 다른 64B 블록 수 세기(HashSet) → 그 프로그램의 작업 집합에 대한 첫 감각
- **키워드**: 지역성 관찰, 캐시 시뮬레이터 입력

### D4 목 · lru-set — 캐시 한 세트와 LRU

- **개념**: hit·miss·eviction, valid 비트, LRU 교체 / direct-mapped(E=1)·set associative·fully associative(S=1)는 같은 구조의 특수한 경우
- **Rust**: struct + impl, &self와 &mut self, Vec\<Line>, iter().position(), min\_by\_key, #\[test\]
- **만들 것**: `CacheSet::access(tag) -> Outcome { Hit, Miss, MissEvict }` + 테스트 3개 (E=1 충돌, E=2 LRU 순서, 콜드 미스)
- **확장**: ReplacementPolicy 트레잇으로 LRU·FIFO·Random을 갈아끼울 수 있게
- **키워드**: 캐시 hit/miss, LRU, direct-mapped / set associative / fully associative

### D5 금 · disk-model — 디스크와 SSD

- **개념**: 디스크 구조(플래터·트랙·섹터), 접근 시간 = 탐색(seek) + 회전 지연(rotational latency) + 전송(transfer), SSD(페이지 단위 읽기·쓰기, 블록 단위 지우기, 웨어 레벨링), 순차 vs 랜덤 접근
- **Rust**: mod로 파일 분리, f64 계산, const, std::os::unix::fs::FileExt::read\_at
- **만들 것**: CSAPP 공식으로 접근 시간 계산기 + 2GB 파일을 만들고 `sync; echo 3 | sudo tee /proc/sys/vm/drop_caches`로 캐시를 비운 뒤 4KB 순차 읽기와 랜덤 읽기 시간 비교, 캐시가 따뜻할 때(DRAM의 페이지 캐시)와도 비교
- **확장**: 외부 크레이트 없이 xorshift 난수 생성기를 직접 만들어 랜덤 오프셋에 사용
- **키워드**: 디스크 접근 시간(seek / rotational / transfer), SSD, 메모리 계층 구조(저장장치 층)

### D6 토 ★ cachesim — 캐시 시뮬레이터 (Cache Lab Part A)

- **개념**: D1·D3·D4의 조립 + 미스 분류 3C(cold / conflict / capacity) + 쓰기 정책(write-through / write-back, write-allocate / no-write-allocate, dirty 비트)
- **Rust**: crates/cachesim 라이브러리와 바이너리 분리, 제네릭·트레잇, CLI 파싱(-s -E -b -t -v), 통합 테스트
- **단계**:
  1. 평일 코드를 합쳐 hits·misses·evictions 출력 → Cache Lab 핸드아웃의 test-csim으로 csim-ref와 일치 확인
  2. 3C 분류: 같은 용량의 fully associative LRU 캐시를 나란히 돌려, 처음 보는 블록 = cold, FA에서도 미스 = capacity, FA에서는 히트 = conflict
  3. 쓰기 정책 4가지 조합 → 메모리로 내려간 쓰기 바이트 수 비교
- **완료 기준**: test-csim 만점, 3C 합계 = 전체 미스 수
- **키워드**: 캐시 구성, tag/set/offset, hit/miss, cold/conflict/capacity miss, 매핑 방식 3종, LRU, write-through/write-back, write-allocate
- **코드 리딩**: std Vec의 내부 구조 (용량을 키우는 방식)

### D7 일 ★ blocking — 루프 순서와 블로킹

- **개념**: 행렬곱 6가지 루프 순서(ijk·jik / jki·kji / kij·ikj)와 내부 루프 stride, 블로킹(타일링), 전치에서 생기는 대각선 충돌 미스
- **Rust**: 1차원 Vec + 인덱스 헬퍼, 경계 검사가 성능에 미치는 영향(`cargo asm`으로 확인), chunks\_exact
- **단계**:
  1. 6가지 순서를 n = 64\~2048에서 측정 → 내부 루프 반복당 시간 그래프를 CSAPP 그림과 비교
  2. 블로킹 행렬곱으로 큰 n에서 개선 확인
  3. 자가 Part B: Rust 전치 함수의 접근 주소를 lackey 형식으로 직접 기록 → 내 cachesim(s=5, E=1, b=5)에 넣어 32×32 전치 미스 300 미만 도전. A·B 시작 주소를 1KB 배수로 두어 같은 세트 충돌을 재현
- **키워드**: 루프 순서와 blocking, stride-1, conflict miss

## 2주차 — 링킹 (7장)

ELF 파서를 매일 한 층씩 키우며 수명(lifetime)과 이터레이터를 익히고, 목요일에 첫 FFI를 링커와 함께 배웁니다. 일요일에는 동적 링킹과 인터포지셔닝을 직접 만듭니다. 읽기: The Book 10.3절(수명), 13장(클로저·이터레이터), 20.1절(Unsafe Rust).

**CSAPP 읽기**: D8 7.1\~7.3 · D9 7.4 · D10 7.5 · D11 7.6 · D12 7.7 · D13 7.8\~7.9, 7.14 · D14 7.10\~7.13

**논문 각주** (참고 자료 표): P6 (D14)

### D8 월 · elf-header — 컴파일 드라이버와 ELF 헤더

- **개념**: 컴파일 드라이버(cpp → cc1 → as → ld, `gcc -v -save-temps`), rustc 파이프라인(`--emit=asm,obj`, `--print link-args`), 목적 파일 3종(재배치 가능·실행 가능·공유)
- **Rust**: fs::read, 슬라이스 범위 인덱싱, from\_le\_bytes + try\_into, match로 e\_type 해석
- **만들 것**: `elf-header <파일>` — magic·class·type(REL/EXEC/DYN)·machine·entry·섹션 헤더 위치 출력. C와 Rust 산출물(.o·실행 파일·.so)로 검증하고 `readelf -h`와 비교
- **확장**: PIE 실행 파일이 왜 DYN으로 나오는지 확인
- **키워드**: 컴파일 드라이버, 재배치 가능 목적 파일, 실행·공유 목적 파일

### D9 화 · elf-sections — 섹션 헤더 테이블

- **개념**: .text .rodata .data .bss .symtab .rela.text .strtab .shstrtab, .bss가 파일 공간을 차지하지 않는 이유, Rust의 static·const·문자열 리터럴은 어느 섹션에 가나
- **Rust**: 수명 — `struct Elf<'a> { data: &'a [u8] }`, 복사 없이 &'a str 이름 반환, 사용자 정의 에러 enum + Display
- **만들 것**: `readelf -S` 축약판 (이름·타입·주소·오프셋·크기)
- **키워드**: ELF 섹션, 재배치 가능 목적 파일

### D10 수 · nm-lite — 심볼 테이블

- **개념**: 전역·외부·지역 심볼, binding(LOCAL / GLOBAL / WEAK), 타입(FUNC / OBJECT), 특수 섹션 인덱스(UND / ABS / COMMON), C의 static 지역 변수가 만드는 지역 심볼
- **Rust**: Iterator 직접 구현(심볼 엔트리 순회), TryFrom\<u8>, 클로저와 filter·map, 첫 외부 크레이트 rustc-demangle
- **만들 것**: nm 스타일 출력 + Rust 심볼 디맹글
- **키워드**: 심볼 해석(심볼의 종류), 심볼 테이블

### D11 목 · link-rules — strong/weak 규칙과 정적 라이브러리

- **개념**: 중복 심볼 규칙(strong 2개 = 에러, strong + weak = strong, weak 여럿 = 임의 선택), GCC 10부터 -fno-common이 기본이라 책의 COMMON 예제는 -fcommon으로 재현, 정적 라이브러리(ar)와 링커의 왼쪽→오른쪽 스캔(E·U·D 집합) → 링크 순서 문제
- **Rust**: build.rs(`cargo:rustc-link-lib=static=...`, `cargo:rustc-link-search=...`), `unsafe extern "C"` 선언, 첫 unsafe 호출
- **만들 것**: C 파일로 규칙 3가지 재현(예측 → 실행), 일부러 링크 순서 에러를 내고 고치기, C 정적 라이브러리를 Rust에서 링크해 호출 → 내 nm-lite로 심볼 확인
- **키워드**: 심볼 해석, strong / weak 심볼 규칙, 정적 라이브러리(.a)

### D12 금 · reloc — 재배치 엔트리

- **개념**: .rela.text 엔트리(offset·type·symbol·addend), R\_X86\_64\_PC32·PLT32(상대) vs R\_X86\_64\_32(절대), 재배치 계산식
- **Rust**: wrapping\_add·wrapping\_sub, as 캐스팅의 부호 확장·절단, HashMap<&str, u64>
- **만들 것**: CSAPP의 main.c + sum.c로 .o의 재배치 엔트리 출력 → 최종 실행 파일의 섹션·심볼 주소로 패치될 바이트를 직접 계산 → `objdump -d` 결과와 자동 비교. `-no-pie`로 빌드하면 책과 같은 절대 주소가 나오고, 최신 툴체인은 함수 호출에 PC32 대신 PLT32를 씁니다
- **키워드**: 재배치(relocation entry), PC 상대 / 절대 주소

### D13 토 ★ elfinspect — 통합 ELF 분석기와 로딩

- **개념**: 섹션 vs 세그먼트(프로그램 헤더), PT\_LOAD·PT\_INTERP·PT\_DYNAMIC, 실행 파일 로딩(\_start → \_\_libc\_start\_main → main), 로더가 세그먼트를 메모리에 매핑하는 과정(9장 예고), .dynamic·.dynsym·.rela.plt 미리 보기
- **Rust**: crates/elf 라이브러리로 정리, 서브커맨드 enum, 에러 타입의 From 구현, 모듈 설계
- **단계**:
  1. D8\~D12 코드를 한 크레이트로 합치고 header·sections·segments·syms·relocs·dynamic 서브커맨드 구성
  2. 각 서브커맨드 출력을 readelf와 대조하는 통합 테스트
  3. 실행 중인 프로세스의 /proc/\<pid>/maps와 PT\_LOAD 세그먼트를 나란히 비교
- **키워드**: 실행 파일 로딩, 실행 가능 목적 파일, ELF 섹션, 재배치
- **코드 리딩**: gimli-rs/object 크레이트의 ELF 파서와 내 설계 비교

### D14 일 ★ dynlink — 공유 라이브러리, PIC, GOT/PLT, 인터포지셔닝

- **개념**: 공유 라이브러리와 동적 링커(ld-linux), 런타임 로딩(dlopen·dlsym), PIC, GOT/PLT, lazy binding, 인터포지셔닝 3종(컴파일 타임·링크 타임·런타임)
- **Rust**: crate-type = cdylib, `#[unsafe(no_mangle)] pub extern "C" fn`, CStr·CString, 함수 포인터 타입, OnceLock으로 찾은 심볼 캐시
- **단계**:
  1. C 공유 라이브러리(-shared -fPIC)를 Rust에서 링크 + Rust cdylib 플러그인을 dlopen으로 불러오는 호스트 → ldd, `readelf -d`로 확인
  2. gdb로 첫 호출 전후 GOT 엔트리 변화 관찰. 배포판 기본값에 따라 즉시 바인딩이 켜져 있을 수 있으니 `-Wl,-z,lazy`로 빌드하고 LD\_BIND\_NOW·LD\_DEBUG=bindings와 비교 (최신 툴체인에서는 .plt.sec가 함께 보일 수 있음)
  3. 인터포지셔닝: C로 컴파일 타임(매크로)·링크 타임(`-Wl,--wrap`) 버전, Rust cdylib + LD\_PRELOAD로 런타임 버전 (rand·time 같은 단순 함수 대상, dlsym(RTLD\_NEXT))
- **키워드**: 공유 라이브러리, 동적 링킹, PIC, GOT/PLT, lazy binding, library interpositioning
- **다음 연결**: malloc 인터포지셔닝은 6주차 D42에서 심화

## 3주차 — 시스템 수준 I/O (10장) + 예외·프로세스 (8장)

이번 주부터 개인 시스템 라이브러리 sysx를 키웁니다. 평일에는 fd·RIO·메타데이터·파일 공유·리다이렉션을, 주말에는 예외와 프로세스를 다룹니다. Rust는 unsafe·RAII(Drop)·std I/O 트레잇이 핵심입니다. 읽기: The Book 15장(스마트 포인터·Drop), Rustonomicon FFI 장.

**CSAPP 읽기**: D15 10.1\~10.4 · D16 10.5 · D17 10.6\~10.7 · D18 10.8 · D19 10.9\~10.11 · D20 8.1, 8.2.4\~8.2.5 · D21 8.2.1\~8.2.3, 8.3\~8.4

**논문 각주** (참고 자료 표): P7 (D19) · P8 (D21)

### D15 월 · fd — 파일 디스크립터 RAII 래퍼

- **개념**: Unix I/O(모든 것은 파일), fd = 프로세스별 디스크립터 테이블의 인덱스, 0·1·2, open 플래그·모드·umask, 실패 = -1 + errno
- **Rust**: libc 크레이트, unsafe의 계약과 `// SAFETY:` 주석, Drop에서 close, io::Error::last\_os\_error, CString(경로 안의 NUL 문제)
- **만들 것**: sysx::Fd(open·read·write) + 이걸로 `cat` 구현 → std의 OwnedFd 설계와 비교
- **키워드**: Unix I/O, 파일 디스크립터, open / read / write / close

### D16 화 · rio — short count와 RIO

- **개념**: short count가 생기는 경우(EOF, 터미널, 파이프·소켓), EINTR, rio\_readn·rio\_writen, 내부 버퍼를 둔 rio\_readlineb·rio\_readnb
- **Rust**: &mut \[u8\]을 앞으로 밀며 채우기, 내 Fd에 Read·Write 트레잇을 구현해 std와 조합(io::copy)
- **만들 것**: sysx::rio(readn·writen·RioReader::read\_line) + pipe로 short count를 재현하는 테스트
- **키워드**: short count, RIO 패키지

### D17 수 · ls-lite — 메타데이터와 디렉터리

- **개념**: stat 구조체(st\_mode·st\_size·st\_ino·st\_nlink), 파일 타입(일반·디렉터리·링크·소켓·FIFO), 권한 비트, opendir·readdir·closedir
- **Rust**: MaybeUninit, Iterator를 구현한 DirIter(Drop에서 closedir), CStr::from\_ptr
- **만들 것**: `ls -l` 축약판(drwxr-xr-x 문자열 직접 생성) → std::fs::read\_dir + MetadataExt 버전과 비교
- **키워드**: stat(메타데이터), 디렉터리

### D18 목 · fd-sharing — 세 개의 테이블

- **개념**: 디스크립터 테이블(프로세스별) / 파일 테이블(오프셋·참조 수) / v-node 테이블, 같은 파일을 두 번 open vs dup vs fork
- **Rust**: libc::dup, libc::fork 반환값 match, /proc/self/fdinfo 읽기
- **만들 것**: 시나리오 4개(두 번 open, dup, fork 후 읽기, fork 후 쓰기)의 출력 예측표 → 실행 검증 → fdinfo의 pos로 오프셋 공유 확인 + 시나리오별 테이블 그림
- **키워드**: descriptor table / file table / v-node table, 파일 공유

### D19 금 · redirect-buf — dup2와 표준 I/O 버퍼링

- **개념**: dup2(old, new)의 정확한 의미, 셸의 > < 2>&1 구현 원리, 버퍼링 모드(full·line·none), C stdio vs Rust Stdout·BufWriter, 소켓에 stdio를 쓰지 않는 이유
- **Rust**: BufWriter, LineWriter, Write 트레잇, flush, Drop에서 flush 에러가 무시되는 문제
- **만들 것**: (1) 프로세스 안에서 stdout을 파일로 dup2한 뒤 println! 확인 (2) `strace -c`로 println! 1만 번 vs stdout().lock() vs BufWriter의 write 호출 수 비교 (3) "fork 전에 비우지 않은 버퍼가 두 번 출력되는" 고전 버그를 C와 Rust(BufWriter)로 각각 재현
- **키워드**: I/O 리다이렉션(dup2), 표준 I/O 버퍼링

### D20 토 ★ trap-lab — 예외와 시스템 콜

- **개념**: 예외 4종(interrupt·trap·fault·abort)과 동기·비동기, 예외 번호와 예외 테이블, 사용자/커널 모드, 리눅스 시스템 콜 ABI(rax = 번호, rdi·rsi·rdx·r10·r8·r9, syscall 명령, rcx·r11 파괴), 문맥 전환
- **Rust**: core::arch::asm!, read\_volatile, getrusage, taskset
- **단계**:
  1. libc 없이 asm!으로 write·getpid·exit 시스템 콜을 직접 호출 (trap)
  2. fault 유발: null 역참조 → SIGSEGV, ud2 → SIGILL, 0으로 나누는 div → SIGFPE (Rust의 산술 검사를 피하려면 asm 사용), 새 페이지 접근 시 minflt 증가 (fault는 복구되기도 한다는 증거). abort는 개념으로만 정리
  3. interrupt 관찰: /proc/interrupts의 타이머·장치 카운트 변화
  4. 측정: 함수 호출 vs getppid 시스템 콜 비용, 파이프 핑퓁으로 문맥 전환 비용(같은 CPU에 고정), time의 user·sys 해석, /proc/\<pid>/status의 ctxt\_switches
- **키워드**: 예외 종류, 예외 테이블, 시스템 콜, 사용자/커널 모드, 문맥 전환

### D21 일 ★ proc-lab — 프로세스 생성과 수거

- **개념**: 프로세스(사적 주소 공간 + 논리적 제어 흐름이라는 두 환상), 동시 흐름, fork(한 번 호출·두 번 리턴), execve(리턴 없음, argv·envp), waitpid(옵션·상태 해석), exit, 좀비와 reaping, 고아와 init
- **Rust**: CString 배열과 null로 끝나는 포인터 배열(임시값의 포인터는 즉시 덱글링), libc::\_exit vs exit, 멀티스레드에서의 fork 주의(cargo test는 스레드로 돌므로 `--test-threads=1`)
- **단계**:
  1. fork 트리 퀴즈 5개의 출력 예측 → 실행 검증(프로세스 그래프 그리기)
  2. 좀비를 만들어 ps로 Z 상태 확인 → waitpid로 수거, 고아의 부모가 바뀌는 것 확인
  3. sysx::proc::spawn(argv) → Child, Child::wait() 직접 구현. exec 실패는 CLOEXEC 파이프로 부모에게 전달
- **키워드**: 프로세스, 논리적 제어 흐름과 동시성, fork / execve / waitpid / exit, 좀비와 reaping
- **코드 리딩**: std::process::Command의 유닉스 구현과 내 spawn 비교

## 4주차 — 시그널과 셸 (8장)

평일 5일에 시그널의 함정을 하나씩 재현하고 고친 뒤, 주말 이틀 동안 잡 컨트롤이 되는 셸을 완성합니다. Rust에서는 "핸들러와 공유하는 전역 상태"를 어떻게 안전하게 설계하느냐가 이번 주의 핵심입니다. 읽기: `man 7 signal`, `man 7 signal-safety`.

**CSAPP 읽기**: D22 8.5.1\~8.5.3 · D23 8.5.4, 8.5.5 중 Correct Signal Handling · D24 8.5.5 중 Safe Signal Handling · D25 8.5.6\~8.5.7 · D26 8.6 · D27\~D28 8.4.6 복습, 8.7, Shell Lab 설명서

**논문 각주** (참고 자료 표): P9 (D25)

### D22 월 · sig-basics — 첫 시그널 핸들러

- **개념**: 시그널 종류(SIGINT·SIGTERM·SIGKILL·SIGCHLD·SIGSEGV·SIGALRM·SIGPIPE), 보내기(kill·alarm·키보드), 받기(기본 동작·무시·핸들러), sigaction
- **Rust**: extern "C" fn 핸들러, mem::zeroed로 sigaction 초기화, static AtomicUsize, 핸들러 안 println! 금지 이유(stdout 락 → 데드락)
- **만들 것**: Ctrl-C를 세 번 눌러야 종료되는 프로그램 + SIGUSR1을 받으면 카운터 출력 + alarm 1초 틱
- **키워드**: 시그널, 시그널 핸들러

### D23 화 · sig-queue — 시그널은 큐잉되지 않는다

- **개념**: pending 비트벡터(종류당 최대 1개), blocked 비트벡터, 전달 시점, 처리 중인 시그널은 자동으로 블록
- **Rust**: sigset\_t 다루기(sigemptyset·sigaddset·sigismember), sigpending
- **만들 것**: CSAPP의 잘못된 SIGCHLD 핸들러(waitpid 한 번) 재현 → 좀비 확인 → `while waitpid(-1, WNOHANG) > 0` 루프로 수정
- **키워드**: pending / blocked 비트, 시그널은 큐잉되지 않음, reaping

### D24 수 · sig-safe — 안전한 핸들러

- **개념**: async-signal-safe 함수, errno 저장·복원, 공유 전역에 접근할 때 시그널 블록, sig\_atomic\_t와 Rust 원자 타입, SA\_RESTART와 EINTR (3주차 RIO가 EINTR을 처리한 이유)
- **Rust**: 할당 없는 정수→문자열 변환(스택 버퍼 + core::fmt::Write 구현), errno 원시 접근
- **만들 것**: (1) 핸들러 안 println!로 데드락 재현(메인도 println! 루프, 셸에서 SIGUSR1 폭격) (2) sio\_puts·sio\_putl을 구현해 해결 (3) errno를 보존하는 핸들러 래퍼
- **키워드**: async-signal-safe, 시그널 핸들러

### D25 목 · sig-race — 경쟁 조건과 sigsuspend

- **개념**: fork 직후 자식이 먼저 끝나 deletejob이 addjob보다 먼저 실행되는 경쟁, fork 전 SIGCHLD 블록, 명시적 대기 3가지(스핀 / pause의 경쟁 / sigsuspend의 원자성)
- **Rust**: SigBlockGuard(생성 시 블록, Drop 시 복원) RAII 타입 설계
- **만들 것**: 경쟁을 sleep으로 넓혀 재현 → sigprocmask로 수정 → sigsuspend로 포그라운드 대기 구현
- **키워드**: 경쟁 조건, sigprocmask / sigsuspend

### D26 금 · nonlocal — setjmp/longjmp와 Rust의 대안

- **개념**: setjmp(한 번 호출·여러 번 리턴)·longjmp, sigsetjmp·siglongjmp로 Ctrl-C 소프트 재시작, 비지역 점프와 예외의 관계, Rust가 setjmp를 지원하지 않는 이유(Drop을 건너뛰고 "두 번 리턴"을 모델링하지 못함)
- **Rust**: panic과 catch\_unwind, Drop 로그로 언와인딩 관찰, panic = "abort" 설정과의 차이
- **만들 것**: C로 CSAPP restart 예제 작성 → Rust에서는 핸들러가 원자 플래그만 세우고 메인 루프가 처리하는 구조로 같은 동작 구현 → catch\_unwind로 깊은 호출 탈출과 비교
- **키워드**: setjmp / longjmp(비지역 점프)

### D27 토 ★ tsh 1일차 — 셸 뼈대 (Shell Lab)

- **개념**: 읽기-평가 루프, 내장 명령, 포그라운드·백그라운드 잡, 프로세스 그룹(자식에서 setpgid(0, 0)을 하는 이유), 잡 리스트
- **Rust**: 모듈 분리(parser·jobs·signals·exec), 시그널 핸들러와 공유하는 전역 잡 테이블 설계(블록 규율), enum JobState
- **단계**:
  1. Shell Lab 핸드아웃을 받고 tshref의 동작부터 관찰
  2. 명령줄 파싱과 builtin(quit·jobs·bg·fg)
  3. fork·exec(SIGCHLD 블록 포함) → sigsuspend 기반 waitfg
  4. trace01\~08 통과 (tshref 출력과 비교)
- **키워드**: 셸 구현, 프로세스 그룹, fork / execve / waitpid, sigprocmask / sigsuspend, 경쟁 조건

### D28 일 ★ tsh 2일차 — 잡 컨트롤 완성

- **단계**:
  1. SIGCHLD 핸들러(WNOHANG | WUNTRACED, 정지·종료·시그널 종료 구분)
  2. SIGINT·SIGTSTP를 포그라운드 그룹 전체에 전달(kill(-pgid, sig))
  3. bg·fg와 SIGCONT → trace01\~16 전부 통과
  4. 확장: < > | (dup2·pipe, 3주차 코드 재사용)
- **키워드**: 시그널 종합, 좀비와 reaping, I/O 리다이렉션, 셸 구현
- **코드 리딩**: signal-hook 크레이트가 핸들러를 안전하게 감싸는 방법 (self-pipe 패턴)

## 5주차 — 가상 메모리 1부: 번역과 매핑 (9장)

주소 번역을 손으로, 리눅스에서 눈으로, 시뮬레이터로 세 번 확인합니다. 1주차 캐시 시뮬레이터가 토요일에 TLB로 재사용되고, 일요일에는 4주차 시그널과 메모리 보호가 만납니다. Rust는 원시 포인터와 "안전한 API 뒤에 unsafe를 가두는" 건전성이 핵심입니다. 읽기: Rustonomicon의 원시 포인터·정렬 부분.

**CSAPP 읽기**: D29 9.1\~9.3, 9.6.1\~9.6.2, 9.6.4 · D30 9.4\~9.5, 9.7.2 · D31 9.3.4\~9.3.6 복습 · D32 9.6.2\~9.6.3, 9.7.1 · D33 9.8 · D34 9.6 전체 복습 · D35 9.7.2의 페이지 폴트 처리, 8.5 복습

**논문 각주** (참고 자료 표): P10 (D32) · P11 (D33) · P12·P13 (D34) · P14 (D35)

### D29 월 · vaddr — 주소 번역 손계산기

- **개념**: 가상·물리 주소, 페이지, VPN·VPO와 PPN·PPO, 페이지 테이블과 PTE(valid·권한·dirty·accessed), MMU, page hit와 page fault의 처리 순서
- **Rust**: 비트 필드 접근 함수, const 배열로 테이블 데이터 표현
- **만들 것**: CSAPP 9.6.4의 작은 시스템(14비트 VA, 12비트 PA, 64B 페이지, 16엔트리 4-way TLB, direct-mapped 캐시)을 코드로 만들고 책의 주소 번역 연습문제를 자동으로 풀기
- **키워드**: 가상/물리 주소, 페이지, 페이지 테이블과 PTE, MMU, 주소 번역(VPN, VPO, PPN), TLB, page hit / page fault

### D30 화 · vmmap — 주소 공간 지도와 메모리 보호

- **개념**: 리눅스 프로세스 주소 공간(text·data·bss·heap·mmap·stack·vdso), 영역(area)별 권한, 잘못된 주소 · 권한 위반 · 정상 fault를 커널이 가르는 순서
- **Rust**: /proc/self/maps 파싱, 지역 변수·static·Box·함수의 주소 얻기(as \*const \_ as usize)
- **만들 것**: 내 프로세스의 지도를 출력하고, 각 변수가 어느 영역·어느 권한에 있는지 자동 분류 → 2주차 세그먼트 정보와 대조
- **키워드**: 메모리 보호, 주소 공간, 실행 파일 로딩(재방문)

### D31 수 · demand — 요구 페이징 관찰

- **개념**: demand paging, minor·major fault, 익명 페이지와 zero page, RSS, working set
- **Rust**: libc::mmap이 돌려주는 포인터 다루기, ptr.add + write\_volatile
- **만들 것**: 1GB 익명 매핑 후 페이지를 하나씩 건드리며 RSS(/proc/self/statm)와 minflt 그래프 → vec\!\[0u8; N\]과 vec\!\[1u8; N\] 비교(왜 0이면 즉시 메모리를 안 먹나) → 파일 매핑 + 캐시 비우기로 major fault 관찰
- **키워드**: demand paging, page fault, working set

### D32 목 · tlb — TLB와 다단계 페이지 테이블

- **개념**: TLB(PTE의 캐시, set associative), TLB reach, x86-64 4단계 페이지 테이블(9비트 × 4 + 12비트 오프셋), 다단계가 메모리를 아끼는 원리, huge page
- **Rust**: 1주차 측정 코드를 라이브러리로 추출해 재사용
- **만들 것**: 페이지당 1바이트씩 접근하며 페이지 수를 늘려 ns/접근의 계단 관찰 → madvise(MADV\_HUGEPAGE)로 비교 → `perf stat -e dTLB-load-misses` 확인 + 48비트 주소를 4단계 인덱스로 분해(D1 addr-split 확장)
- **키워드**: TLB, 다단계 페이지 테이블, 주소 번역

### D33 금 · mmap-lab — 메모리 매핑과 copy-on-write

- **개념**: 파일 기반·익명 매핑, 공유 객체 vs 사적 객체(MAP\_SHARED / MAP\_PRIVATE), copy-on-write, fork·execve 재방문
- **Rust**: sysx::Mmap(Deref\<Target=\[u8\]>, Drop에서 munmap), 건전성 — memmap2가 매핑 함수를 unsafe로 둔 이유(다른 프로세스가 파일을 바꾸면 &\[u8\]의 불변성이 깨짐)
- **만들 것**: (1) mmap으로 파일을 stdout에 복사(CSAPP 연습문제) (2) fork 후 MAP\_SHARED 카운터는 공유되고 MAP\_PRIVATE는 분리되는 것 확인 (3) 큰 영역을 터치한 뒤 fork → 자식이 쓸 때 minflt 증가로 COW 관찰
- **키워드**: 메모리 매핑(mmap), 공유 객체, copy-on-write

### D34 토 ★ vmsim — 페이징 시뮬레이터

- **개념**: TLB + 다단계 페이지 테이블 + 물리 프레임 + 페이지 교체 + 스왑 + thrashing 종합
- **Rust**: 워크스페이스에서 cachesim을 의존성으로 재사용(TLB = 내 캐시), 재귀 자료구조(Option\<Box\<Table>>), Replacer 트레잇(LRU·Clock·FIFO)
- **단계**:
  1. 1주차 valgrind 트레이스를 입력으로 TLB hit률·page fault·스왑 횟수 출력
  2. 프레임 수를 줄여 가며 fault 곡선을 그려 working set과 thrashing 지점 확인
  3. 보호 비트 위반(읽기 전용 페이지에 쓰기) 시뮬레이션
- **키워드**: 페이지 테이블과 PTE, 다단계 페이지 테이블, TLB, demand paging, working set과 thrashing, 메모리 보호, MMU

### D35 일 ★ wtrack — mprotect + SIGSEGV 쓰기 추적기

- **개념**: fault → 커널 → 시그널로 이어지는 경로(8장 연결), 사용자 공간에서 메모리 보호 활용(GC 쓰기 장벽, 디버거 워치포인트, 증분 스냅샷), SA\_SIGINFO와 si\_addr
- **Rust**: 인자 3개짜리 sa\_sigaction 핸들러, siginfo\_t의 si\_addr(), static 원자 비트맵, 4주차 SigBlockGuard 재사용
- **단계**:
  1. 영역을 PROT\_READ로 바꾼다
  2. 쓰기가 일어나면 핸들러가 페이지를 기록하고 mprotect(RW) 후 복귀 → 같은 명령이 다시 실행되며 성공
  3. "바뀐 페이지만 저장하는 증분 스냅샷" 라이브러리로 완성하고 오버헤드 측정
  4. 주의: mprotect는 POSIX async-signal-safe 목록에 없지만, 리눅스에서는 단순 시스템 콜이라 이 용도로 관용적으로 씁니다
- **키워드**: 메모리 보호, page fault, 시그널(8장 복습), demand paging 응용
- **코드 리딩**: memmap2 크레이트

## 6주차 — 가상 메모리 2부: 동적 메모리 할당 (9장)

평일에 할당기의 부품(정렬·블록 포맷·배치·연결)을 하나씩 만들고, 토요일에 Malloc Lab 채점기로 완성본을 만듭니다. 내 할당기를 Rust 프로그램 전체의 기본 할당기로 거는 것이 이번 주의 하이라이트입니다. 할당기 로직은 Vec\<u8> 기반 가짜 힙 위에서 먼저 만들어 Miri로 검사할 수 있게 합니다.

**CSAPP 읽기**: D36 9.9.1\~9.9.4 · D37 9.9.3, 9.9.5 · D38 9.9.6\~9.9.9 · D39 9.9.10\~9.9.12 · D40 9.11 · D41 9.9.13\~9.9.14, Malloc Lab 설명서 · D42 9.10, 7.13.3 복습

**논문 각주** (참고 자료 표): P15 (D40) · P16 (D41)

### D36 월 · heap-peek — 힙과 brk, 단편화

- **개념**: 힙과 brk·sbrk, 큰 할당은 mmap(glibc 임계값은 기본 128KiB에서 동적으로 조정), 할당기 요구사항(임의 요청 순서·즉시 응답·정렬·할당된 블록은 옮기지 않음), 처리량 vs 이용도, 내부·외부 단편화
- **Rust**: libc::sbrk, `strace -e brk,mmap`
- **만들 것**: 크기를 바꿔 가며 할당해 brk 이동과 mmap으로 바뀌는 지점 관찰 + 요청 열에서 내부·외부 단편화를 계산하는 함수
- **키워드**: 힙과 brk, malloc / free, 내부/외부 단편화

### D37 화 · bump — 범프 할당기와 #\[global\_allocator\]

- **개념**: 정렬 요구, 가장 단순한 할당기(free 없음 = 처리량 최고, 이용도 최악)
- **Rust**: unsafe impl GlobalAlloc, Layout, #\[global\_allocator\], &self에서 상태를 바꾸려면 원자 타입이나 UnsafeCell이 필요한 이유
- **만들 것**: 큰 mmap 영역 위의 범프 할당기 → 내 cachesim을 이 할당기로 돌리고 총 사용량 출력
- **키워드**: malloc / free(할당기 설계), 정렬

### D38 수 · implicit — 암시적 가용 리스트

- **개념**: 블록 포맷(header = size | alloc 비트), 암시적 가용 리스트, first fit, splitting
- **Rust**: Vec\<u8> 기반 가짜 힙, 원시 포인터 헬퍼(책의 HDRP·FTRP·NEXT\_BLKP·PREV\_BLKP에 해당하는 함수)
- **만들 것**: alloc·free + 모든 블록을 출력하는 힙 워커
- **키워드**: implicit free list, first fit, splitting

### D39 목 · coalesce — 경계 태그와 연결

- **개념**: boundary tag(footer), 즉시 연결의 4가지 경우, next fit·best fit 비교
- **Rust**: `cargo +nightly miri test`, 힙 검사기의 불변식(인접한 가용 블록 없음, header == footer, 정렬)
- **만들 것**: 연결 4가지 케이스 테스트 + 배치 정책 3종을 같은 랜덤 요청 열로 돌려 이용도 비교
- **키워드**: coalescing, boundary tag, first / next / best fit

### D40 금 · mem-bugs — 흔한 메모리 버그 동물원

- **개념**: CSAPP 9.11의 버그들 — 잘못된 포인터 역참조, 초기화 안 된 메모리 읽기, 스택 버퍼 오버플로, 포인터와 객체 크기 혼동, off-by-one, 포인터 산술 실수, 사라진 지역 변수 참조, 해제된 블록 참조, 누수
- **Rust**: 같은 버그를 safe Rust로 쓰면 어느 것이 컴파일 에러가 되는지, unsafe로 쓰면 Miri·ASan(nightly `-Zsanitizer=address`)이 잡는지
- **만들 것**: C 버전을 valgrind·ASan으로 진단 → Rust 대응표 작성(컴파일 거부 / 런타임 패닉 / unsafe에서만 가능)
- **키워드**: 흔한 메모리 버그

### D41 토 ★ mm — 할당기 완성 (Malloc Lab)

- **개념**: explicit free list(LIFO vs 주소 순), segregated free list(크기 클래스), 처리량·이용도 점수
- **Rust**: crate-type = staticlib로 mm\_init·mm\_malloc·mm\_free·mm\_realloc 내보내기, C 쪽 mem\_sbrk 호출(7장 링킹 복습), 같은 코어를 GlobalAlloc으로도 노출
- **단계**:
  1. implicit(D38\~D39)을 mdriver에 붙여 기준 점수 기록
  2. explicit free list로 바꾸고 점수 비교
  3. segregated free list로 바꾸고 점수 비교
  4. 최종본을 #\[global\_allocator\]로 걸고 2주차 elfinspect 실행 (멀티스레드 대비 락 추가)
- **키워드**: implicit / explicit / segregated free list, splitting, coalescing, boundary tag, 단편화, malloc / free
- **코드 리딩**: linked\_list\_allocator 또는 dlmalloc 크레이트

### D42 일 ★ gc — malloc 추적기와 mark & sweep

- **개념**: 런타임 인터포지셔닝 심화, 가비지 컨렉션, 도달 가능성 그래프, 루트, 보수적 GC
- **Rust**: 할당 없는 코드, const로 초기화한 thread\_local!, 아레나 + 인덱스 핸들 패턴(Rust에서 그래프를 다루는 정석, 대형 코드베이스에 흔함)
- **단계**:
  1. Rust cdylib로 malloc·free·calloc·realloc을 LD\_PRELOAD 인터포즈 → 실제 프로그램의 요청 크기 히스토그램
  2. 함정 해결: 출력·포맷이 malloc을 다시 부르는 재귀, dlsym이 내부에서 할당할 수 있는 부트스트랩 문제, 스레드 안전
  3. 내 mm 힙에 mark 비트 추가 → 루트 집합 등록 → 블록 안의 워드를 포인터 후보로 보는 보수적 mark → sweep으로 free
  4. 비교: 같은 객체 그래프를 아레나 + 인덱스 핸들로 만들고 정밀 GC로 수거
- **키워드**: library interpositioning(런타임), 가비지 컨렉션, mark & sweep, 보수적 GC

## 7주차 — 네트워크 프로그래밍 (11장) + 동시성 진입 (12장)

소켓도 fd라는 사실 덕분에 3주차 sysx가 그대로 쓰입니다. 토요일 Tiny 웹 서버는 지금까지 만든 것(HTTP 파서·RIO·Mmap·spawn·dup2)을 총동원하고, 일요일에는 반복형 서버의 한계를 넘어 12장으로 들어갑니다. 읽기: The Book 21.1절(단일 스레드 웹 서버).

**CSAPP 읽기**: D43 11.1\~11.2, 11.3.1 · D44 11.3.2, 11.4.7 · D45 11.3.3, 11.4.1\~11.4.6, 11.4.8 · D46 11.4.9 · D47 11.5.1\~11.5.3 · D48 11.5.4, 11.6 · D49 12.1\~12.2

**논문 각주** (참고 자료 표): P17 (D49)

### D43 월 · ipaddr — IP 주소와 바이트 순서

- **개념**: 클라이언트-서버 트랜잭션 4단계, 네트워크 계층 개요(LAN·라우터·칡슐화), IP 주소, 네트워크 바이트 순서(빅 엔디언), htonl·ntohl, inet\_pton·inet\_ntop
- **Rust**: to\_be\_bytes·from\_be\_bytes, std::net::Ipv4Addr, FromStr 직접 구현
- **만들 것**: hex2dd·dd2hex(CSAPP 연습문제) + libc inet\_pton 버전 비교 + 빅 엔디언 직렬화 헬퍼(내일 재사용)
- **키워드**: 클라이언트-서버 모델, IP 주소, 네트워크 바이트 순서

### D44 화 · hostinfo — DNS와 getaddrinfo

- **개념**: 도메인 이름 계층, DNS, 하나의 이름과 여러 주소, getaddrinfo·getnameinfo(프로토콜 독립·재진입 가능), addrinfo 연결 리스트
- **Rust**: C 연결 리스트를 순회하는 Iterator(수명으로 소유자에 묶기), Drop에서 freeaddrinfo
- **만들 것**: CSAPP hostinfo를 Rust로
- **확장**: UDP로 DNS 쿼리 패킷을 직접 만들어 보내고 A 레코드 파싱
- **키워드**: DNS, 도메인 이름, getaddrinfo / getnameinfo

### D45 수 · sockets — 소켓 인터페이스

- **개념**: 소켓과 소켓 쌍(cliaddr:cliport, servaddr:servport), socket → connect / socket → bind → listen → accept 흐름, 듣기 디스크립터 vs 연결 디스크립터, SO\_REUSEADDR, sockaddr 캐스팅
- **Rust**: \*const sockaddr 캐스팅, socklen\_t, 후보 주소를 순회하며 에러 처리
- **만들 것**: sysx::net::{open\_clientfd, open\_listenfd} → `ss -tnp`로 소켓 쌍 확인
- **키워드**: 소켓 쌍, socket / bind / listen / accept / connect, open\_clientfd / open\_listenfd

### D46 목 · echo — 반복형 echo 서버

- **개념**: 반복형 서버, 연결의 EOF, 소켓에서 short count가 일상인 이유
- **Rust**: sysx의 Fd·RIO·net 재사용 → std::net::TcpListener로 다시 작성해 비교
- **만들 것**: echoserveri·echoclient → nc 여러 개로 "두 번째 클라이언트가 기다리는" 현상 확인 (12장의 동기)
- **키워드**: echo 서버, 클라이언트-서버 모델

### D47 금 · http — HTTP 파서

- **개념**: HTTP 요청 라인·헤더·빈 줄, 응답 라인·상태 코드·Content-type·Content-length, MIME, URI, 정적 vs 동적 콘텐츠
- **Rust**: 복사 없는 파서 Request<'a>(2주차 ELF 파서 패턴 재사용), 테스트 주도 개발
- **만들 것**: 요청 파서 + 응답 빌더, `curl -v`·telnet으로 실제 서버와 형식 대조
- **키워드**: HTTP 요청/응답, 정적/동적 콘텐츠

### D48 토 ★ tiny — Tiny 웹 서버

- **개념**: Tiny 구조(doit·read\_requesthdrs·parse\_uri·serve\_static·serve\_dynamic·clienterror), CGI(환경 변수로 인자 전달, stdout으로 응답)
- **Rust**: 재사용 총동원 — HTTP 파서(D47), RIO(D16), Mmap(D33), spawn·dup2(D19·D21). CGI 자식의 환경은 set\_var(2024 에디션에서 unsafe) 대신 execve의 envp로 넘김
- **단계**:
  1. 정적 콘텐츠(mmap) 제공
  2. 에러 응답(404·403·501)
  3. CGI adder(Rust 바이너리)로 동적 콘텐츠
  4. 확장: HEAD 메서드, SIGCHLD로 CGI 자식 수거, mmap 대신 읽기+쓰기, SIGPIPE·EPIPE 처리
- **키워드**: Tiny 웹 서버, CGI, HTTP, 정적/동적 콘텐츠

### D49 일 ★ echo-concurrent — 프로세스 기반 + 이벤트 기반 서버

- **개념**: 동시성 접근 3가지 비교, 프로세스 기반 서버에서 부모가 connfd를 닫아야 하는 이유(파일 테이블 참조 수 — 10장), SIGCHLD 수거(8장), I/O 멀티플렉싱(select), 이벤트 기반 서버 = 상태 머신
- **Rust**: fd\_set과 FD\_SET·FD\_ISSET, Vec\<Option\<Client>> 슬랩 패턴, enum 상태 머신
- **단계**:
  1. echoserverp(fork)
  2. echoservers(select + pool)
  3. 줄을 반만 보내는 클라이언트로 select 서버가 막히는지 실험(블로킹 readline의 함정)
  4. 확장: epoll 버전
- **키워드**: 프로세스 기반 동시성, I/O 멀티플렉싱(select), 이벤트 기반 서버
- **코드 리딩**: httparse 크레이트(복사 없는 HTTP 파서)와 내 D47 파서 비교

## 8주차 — 동시성 (12장)

C에서 문서로만 지키던 동시성 규칙을 Rust 컴파일러가 어디까지 대신 지켜 주는지 확인하는 주입니다. 평일에 만든 Semaphore·Sbuf·RW 락이 토요일 프리스레딩 서버와 9주차 프록시의 부품이 됩니다. 읽기: The Book 16장, Rust Atomics and Locks 1\~2장.

**CSAPP 읽기**: D50 12.3 · D51 12.4 · D52 12.5.1\~12.5.3 · D53 12.5.4 앞부분(생산자-소비자) · D54 12.5.4 뒷부분(readers-writers) · D55 12.5.5, 12.7 · D56 12.6

**논문 각주** (참고 자료 표): P18 (D55)

### D50 월 · threads — 스레드 기초

- **개념**: 스레드 = 프로세스 안의 논리 흐름(자기 스택·레지스터·TID, 나머지는 공유), 스레드 문맥 전환이 더 싼 이유, pthread\_create·join·detach·exit, joinable vs detached
- **Rust**: libc::pthread\_create에 Box::into\_raw로 인자 넘기기 → std::thread::spawn·JoinHandle, move 클로저, 'static 바운드
- **만들 것**: 같은 일을 raw pthread와 std로 각각 구현 → 스레드 기반 echo 서버(detach). CSAPP의 &connfd 경쟁이 Rust에서는 move 때문에 애초에 생기지 않음을 확인
- **키워드**: 스레드 기반 동시성, Pthreads(create / join / detach)

### D51 화 · sharing — 공유 변수와 메모리 모델

- **개념**: 스레드 메모리 모델, 전역·지역 static·지역 자동 변수 중 무엇이 공유되나(CSAPP sharing.c 표), 다른 스레드의 스택 참조
- **Rust**: Send·Sync, Arc, thread::scope(스택 변수를 안전하게 공유), Rc가 스레드를 넘지 못하는 이유
- **만들 것**: sharing.c를 C로 실행해 표 채우기 → Rust로 옮기며 컴파일러가 막는 지점 기록 → scope·Arc·원자 타입으로 같은 공유 구현
- **키워드**: 공유 변수와 스레드 메모리 모델

### D52 수 · badcnt — 경쟁과 진행 그래프

- **개념**: cnt++의 Load·Update·Store, 크리티컬 섹션, 진행 그래프(궤적, 불안전 영역), 상호 배제
- **Rust**: 원시 포인터와 unsafe로 badcnt를 재현하고 왜 UB인지 설명 → AtomicU64::fetch\_add·Mutex로 수정, `cargo asm`으로 lock xadd 확인
- **만들 것**: 진행 그래프 시뮬레이터 — 두 스레드 명령열(H·L·U·S·T)의 모든 인터리빙을 열거해 각 궤적의 최종 cnt와 불안전 궤적 비율 출력 → 세마포어를 넣으면 불안전 궤적이 0이 됨을 확인
- **키워드**: 경쟁(race), 크리티컬 섹션, 진행 그래프, 뮤텍스

### D53 목 · sbuf — 세마포어와 생산자-소비자

- **개념**: 세마포어(P·V, s ≥ 0 불변식), 이진 세마포어 = 뮤텍스, 카운팅 세마포어, 생산자-소비자(mutex + slots + items)
- **Rust**: Mutex + Condvar로 Semaphore 구현(std에는 없음), wait\_while과 가짜 깨어남, 획득 시 가드를 돌려주는 RAII 버전, 제네릭 Sbuf\<T>
- **만들 것**: Semaphore + Sbuf\<T> + 생산자 N·소비자 M 테스트(모든 아이템이 정확히 한 번 소비) → std::sync::mpsc::sync\_channel과 비교
- **키워드**: 세마포어(P / V), 뮤텍스, 생산자-소비자

### D54 금 · rwlock — readers-writers

- **개념**: 1종(reader 우선, writer 기아), 2종(writer 우선), CSAPP 구현(readcnt + mutex + w)
- **Rust**: ReadGuard·WriteGuard에 Deref·DerefMut 구현 → 내 락을 std 락처럼 쓰기
- **만들 것**: 1종 구현 → writer 기아 재현(reader를 계속 투입하며 writer 대기 시간 측정) → 2종 구현 → std::sync::RwLock 문서(정책을 보장하지 않음)와 리눅스 구현 코드 확인
- **키워드**: readers-writers, 세마포어

### D55 토 ★ prethreaded — 프리스레딩, 스레드 안전성, 교착상태

- **단계**:
  1. 프리스레딩 echo 서버: main은 accept 후 Sbuf에 넣는 생산자, worker는 소비자. echo\_cnt 초기화는 OnceLock(pthread\_once에 해당)
  2. 스레드 불안전 함수 4종(공유 변수 미보호 / 호출 간 상태 유지(rand) / 정적 버퍼 포인터 반환(ctime) / 불안전 함수 호출)을 C로 재현. rand vs rand\_r, strtok vs strtok\_r로 재진입 개념, lock-and-copy → Rust 타입 시스템이 어느 종류를 막는지 정리(set\_var가 unsafe가 된 이유도 여기서)
  3. 두 뮤텍스를 역순으로 잡는 데드락 재현 → gdb `thread apply all bt` → 진행 그래프의 교착 영역 그리기 → 락 순서 규칙으로 해결. Rust 특유 사례: 같은 Mutex 재획득, RefCell 이중 대여
- **키워드**: prethreading, 생산자-소비자, thread-safe vs reentrant, 교착상태, 경쟁
- **코드 리딩**: std Mutex·Condvar의 리눅스 futex 구현, std mpsc 구현

### D56 일 ★ psum — 병렬성과 false sharing

- **개념**: 동시성 vs 병렬성, speedup S\_p = T\_1 / T\_p, efficiency E\_p = S\_p / p, 강·약 스케일링, 동기화 비용, false sharing(6장 캐시 라인으로 귀환)
- **Rust**: thread::scope, chunks\_mut, AtomicU64(Relaxed), #\[repr(align(64))\], rayon
- **단계**:
  1. psum-mutex·psum-array·psum-local을 스레드 1·2·4·8개로 측정해 표와 그래프
  2. psum-array의 false sharing을 패딩으로 제거하고 다시 측정
  3. 1주차 블로킹 행렬곱을 병렬화
  4. rayon 버전과 코드량·성능 비교
- **키워드**: 병렬성과 speedup, 스레드 기반 동시성, 캐시 라인(6장)

## 9주차 — 캡스톤: 동시 캐싱 프록시 (6·10·11·12장 종합)

Proxy Lab을 평일 5일에 나눠 쌓고 driver.sh 만점(70점)을 목표로 합니다. 주말에는 같은 프록시를 async로 다시 쓰고, 그동안 만든 것과 대응되는 실제 대형 코드를 읽습니다. 읽기: The Book 17장(async), 21장(멀티스레드 웹 서버).

**CSAPP 읽기**: D57\~D61 Proxy Lab 설명서, 11.5\~11.6·12.5.5 복습 · D62 12.2 복습 · D63 각 장의 Summary 절(6.7, 7.15, 8.8, 9.12, 10.12, 11.7, 12.8)

**논문 각주** (참고 자료 표): P3 다시 (D60) · P19·P20 (D63)

### D57 월 · proxy-parse — 프록시 요청 변환

- **개념**: 프록시의 역할(클라이언트에게는 서버, 서버에게는 클라이언트), 절대 URI(http://host:port/path), 헤더 재작성(Host·User-Agent·Connection: close·Proxy-Connection: close)
- **Rust**: D47 HTTP 파서 확장, 단위 테스트 다수
- **만들 것**: Proxy Lab 핸드아웃 받기 + 클라이언트 요청을 원 서버용 요청으로 바꾸는 함수와 테스트
- **키워드**: HTTP, 클라이언트-서버 모델

### D58 화 · proxy-seq — 순차 프록시

- **만들 것**: 클라이언트 → 원 서버 중계(바이너리 본문도 안전하게, readnb), driver.sh의 Basic 통과
- **키워드**: 소켓, RIO, short count

### D59 수 · proxy-conc — 동시성 추가

- **만들 것**: 프리스레딩(D55 Sbuf 재사용) 적용 + SIGPIPE 무시, EPIPE·ECONNRESET 처리 → Concurrency 통과
- **키워드**: prethreading, 시그널(SIGPIPE), 스레드 안전

### D60 목 · proxy-cache-design — 캐시 설계

- **개념**: 핸드아웃이 정한 최대 캐시 크기(약 1MiB)와 객체 크기(약 100KiB), LRU 근사(1주차 LRU 재사용), 읽기가 많은 공유 자료구조에는 readers-writers
- **만들 것**: Cache 트레잇과 자료구조 설계 + 단일 스레드 테스트
- **키워드**: LRU, readers-writers

### D61 금 · proxy-cache — 캐시 완성

- **만들 것**: 캐시를 프록시에 결합하고 동시 접근 테스트 → driver.sh 70/70 목표
- **키워드**: 동시성·캐시 종합

### D62 토 ★ proxy-async — 이벤트 기반에서 async로

- **개념**: epoll 기반 이벤트 루프, Rust async의 Future = 컴파일러가 만든 상태 머신(D49 이벤트 서버의 연장), 리액터와 실행기
- **단계**:
  1. mio로 이벤트 기반 프록시
  2. tokio로 재작성
  3. 프로세스·스레드·이벤트·async 4가지 모델을 같은 부하(wrk)로 비교한 짧은 리포트
- **키워드**: 이벤트 기반 서버, I/O 멀티플렉싱, 동시성 모델 비교

### D63 일 ★ code-reading — 대형 코드 읽기와 회고

- **단계**:
  1. mio(epoll 래핑), tokio 런타임(I/O 드라이버·스케줄러), std의 유닉스 구현(fd·process·thread)을 "공부 방법"의 읽는 법대로 읽기
  2. 각 코드베이스가 내 sysx의 어느 부분에 해당하는지 지도 그리기
  3. 내 워크스페이스 전체 리팩터링: 중복 제거, 공개 API 정리, README
- **키워드**: 총복습

## 개념 재사용 지도

앞에서 만든 것 17개가 뒤에서 다시 쓰입니다. 대충 만들면 반드시 되돌아오므로, 왼쪽 항목은 테스트와 문서 주석을 갖춰 둡니다.

| 만든 것 | 처음 | 다시 쓰이는 곳 |
| --- | --- | --- |
| 주소 분해기 | D1 | cachesim D6 → 4단계 인덱스 분해 D32 → vmsim의 TLB D34 |
| 측정 코드 | D2 | TLB 측정 D32 → psum D56 |
| 트레이스 파서 | D3 | 자가 Part B D7 → vmsim 입력 D34 |
| LRU 세트 | D4 | vmsim 교체 정책 D34 → 프록시 캐시 D60 |
| 캐시 라인 개념 | D6 | false sharing D56 |
| 수명 기반 바이너리 파서 | D9 | HTTP 파서 D47 → 프록시 D57 |
| build.rs·staticlib 링크 | D11 | Malloc Lab 채점기 연결 D41 |
| 런타임 인터포지셔닝 | D14 | malloc 추적기 D42 |
| Fd·RIO | D15\~D16 | 셸 D27 → echo·Tiny D46·D48 → 프록시 D58 |
| dup2 | D19 | 셸 리다이렉션 D28 → CGI D48 |
| spawn | D21 | 셸 D27 → CGI D48 |
| SIGCHLD 수거 | D23 | 셸 D28 → Tiny·fork 서버 D48·D49 |
| SigBlockGuard | D25 | 쓰기 추적기 D35 |
| Mmap | D33 | Tiny 정적 콘텐츠 D48 |
| 할당기 | D41 | GC D42 |
| select 이벤트 서버 | D49 | async 프록시 D62 |
| Sbuf·RW 락 | D53\~D54 | 프리스레딩 D55 → 프록시 D59\~D61 |

## 키워드 커버리지

앞서 나열한 6\~12장 핵심 키워드는 모두 최소 한 번, 대부분은 두 번 이상 프로젝트에 등장합니다. 복습할 때 해당 날의 README로 바로 돌아가면 됩니다.

- **6장**: 캐시 구성·tag/set/offset D1·D6 · 지역성·stride-1 D2·D7 · 메모리 계층·SRAM vs DRAM D2·D5 · 메모리 마운틴 D2 · 디스크 접근 시간·SSD D5 · hit/miss·LRU·매핑 방식 3종 D4·D6 · cold/conflict/capacity D6·D7 · 쓰기 정책 D6 · 루프 순서와 blocking D7·D56
- **7장**: 컴파일 드라이버 D8 · 재배치 가능 목적 파일 D8·D9 · ELF 섹션 D9·D13 · 심볼 해석 D10·D11 · strong/weak·정적 라이브러리 D11 · 재배치 D12·D13 · 실행 파일 로딩 D13·D30 · 공유 라이브러리·동적 링킹·PIC·GOT/PLT·lazy binding D14 · 인터포지셔닝 D14·D42
- **8장**: 예외 종류·예외 테이블·시스템 콜·사용자/커널 모드·문맥 전환 D20 · 프로세스·논리적 제어 흐름 D21 · fork/execve/waitpid/exit·좀비 D21·D23 · 시그널·핸들러 D22·D24 · pending/blocked·큐잉 안 됨 D23 · async-signal-safe D24 · 경쟁 조건·sigprocmask/sigsuspend D25 · setjmp/longjmp D26 · 셸 구현 D27·D28
- **9장**: 가상/물리 주소·페이지·PTE·MMU·주소 번역 D29 · 메모리 보호 D30·D35 · demand paging·page fault D31·D34 · TLB·다단계 페이지 테이블 D32·D34 · working set·thrashing D31·D34 · mmap·공유 객체·COW D33 · 힙과 brk·단편화 D36 · malloc/free D36\~D41 · implicit/explicit/segregated D38·D41 · fit 정책·splitting·coalescing·boundary tag D38·D39 · 흔한 메모리 버그 D40 · mark & sweep D42
- **10장**: Unix I/O·fd·open/read/write/close D15 · short count·RIO D16·D46 · stat D17 · 세 테이블·파일 공유 D18·D49 · dup2 D19·D28 · 표준 I/O 버퍼링 D19
- **11장**: 클라이언트-서버·IP 주소·바이트 순서 D43 · DNS·getaddrinfo D44 · 소켓 쌍·소켓 함수·open\_clientfd/open\_listenfd D45 · echo 서버 D46 · HTTP·정적/동적 콘텐츠 D47·D48 · CGI·Tiny D48
- **12장**: 프로세스 기반·select·이벤트 기반 D49 · 스레드·Pthreads D50 · 공유 변수·메모리 모델 D51 · 경쟁·크리티컬 섹션·진행 그래프 D52 · 세마포어·뮤텍스·생산자-소비자 D53 · readers-writers D54 · prethreading·thread-safe vs reentrant·교착상태 D55 · 병렬성과 speedup D56

## 시스템 연구와의 연결

CSAPP 6\~12장은 교과서에서 끝나지 않고 지금 가장 활발한 시스템 연구로 바로 이어집니다. 최근 연구의 공통 흐름은 두 가지입니다. 하드웨어가 빨라지면서 시스템 콜·복사·락 같은 소프트웨어 비용이 병목이 됐고, AI 인프라가 페이징·캐시·블로킹 같은 고전 개념을 다시 가져다 쓰고 있습니다.

| 장 | 이어지는 연구 분야 (주요 학회) | 요즘 흐름 (각주) |
| --- | --- | --- |
| 6 메모리 계층 | 컴퓨터 구조·캐시·스토리지·하드웨어 보안 (ISCA, MICRO, ASPLOS, FAST, USENIX Security) | 단순한 FIFO 계열 교체 정책의 재발견, GPU 메모리 계층을 고려한 AI 커널, 프리페처 사이드 채널 (P1\~P5) |
| 7 링킹 | 툴체인·바이너리 분석·공급망 보안 (PLDI, CGO, USENIX Security, CCS) | 동적 링킹 기능을 악용한 공급망 공격 (P6) |
| 8 예외적 제어 흐름 | OS 커널·스케줄링·런타임 (SOSP, OSDI, EuroSys, USENIX ATC, NSDI) | 마이크로초 단위 선점, 사용자 수준 인터럽트, fork의 대안 (P8, P9) |
| 9 가상 메모리 | OS 메모리 관리·DB 버퍼 관리·AI 서빙 (ASPLOS, OSDI, SOSP, SIGMOD, VLDB) | TLB reach, mmap 논쟁, LLM KV 캐시 페이징, 데이터센터 규모 할당기 (P10\~P16) |
| 10 시스템 수준 I/O | 스토리지 시스템·DB 엔진 (FAST, VLDB, SIGMOD) | NVMe와 io\_uring으로 소프트웨어 오버헤드 줄이기, SSD 쓰기 증폭 (P1, P7, P17) |
| 11 네트워크 | 데이터센터 네트워킹 (NSDI, SIGCOMM) | 커널 우회 대 io\_uring, 제로 카피 송수신 (P17) |
| 12 동시성 | OS·프로그래밍 언어·검증 (SOSP, OSDI, PLDI) | Rust 안전성 실증 연구, Rust로 만든 커널, 별칭 모델 (P15, P18\~P20) |

연구 논문의 뼈대는 대개 "측정으로 병목을 찾고, 고전 개념을 새 환경에 맞게 바꾸고, 다시 측정해 증명한다"입니다. 매일 하는 예측 → 측정 → 설명이 그 축소판이라, 9주를 마치면 논문의 실험 절을 읽는 눈이 생깁니다.

특히 P4·P12·P13은 지금 AI 서비스를 떠받치는 핵심 기술인데, 바탕은 D7의 블로킹과 D31\~D34의 페이징입니다. 각주의 읽는 날짜와 링크는 맨 아래 참고 자료의 "논문 각주"에 있습니다.

## 참고 자료

교재는 CSAPP 3판을 그대로 쓰고, Rust 쪽은 The Book을 주차에 맞춰 읽습니다. 나머지는 필요한 주에만 펼칩니다.

### The Book 장 매핑

| 주차 | 읽을 장 |
| --- | --- |
| 0 | 1\~9장, 11장 |
| 1 | 10장(제네릭·트레잇), 12장, 14.3절(워크스페이스) |
| 2 | 10.3절(수명), 13장(클로저·이터레이터), 20.1절(Unsafe Rust) |
| 3 | 15장(스마트 포인터·Drop·Deref) |
| 7 | 21.1절(단일 스레드 웹 서버) |
| 8 | 16장(동시성) |
| 9 | 17장(async), 21장(멀티스레드 웹 서버) |

### 그 밖의 자료

- [CS:APP3e 랩 페이지](https://csapp.cs.cmu.edu/3e/labs.html) — Cache·Shell·Malloc·Proxy Lab 자습용 핸드아웃
- [Rust Atomics and Locks](https://mara.nl/atomics/) (Mara Bos) — 웹에서 무료로 읽을 수 있고 한국어판도 있음. 8주차에 1\~2장, D54\~D55 무렵 8\~9장(OS 프리미티브, 직접 만드는 락)
- [The Rustonomicon](https://doc.rust-lang.org/nomicon/) — unsafe·FFI·원시 포인터, 3주차부터
- [Rust 2024 에디션 가이드](https://doc.rust-lang.org/edition-guide/rust-2024/index.html) — 예전 예제가 컴파일되지 않을 때
- [libc 크레이트 문서](https://docs.rs/libc)와 man 2·3·7 페이지 — 시스템 콜 시그니처와 에러 코드
- [Rustlings](https://github.com/rust-lang/rustlings) — 문법이 막힐 때 보충 연습(선택)

### 논문 각주

그날까지 배운 것만으로 핵심을 읽을 수 있는 논문 20편입니다. 처음에는 초록 → 서론 → 그림 → 결론 순서로 30분만 읽고, 막히는 용어는 다음 브리핑 때 질문하세요. 대부분 2022\~2026년 논문이고, 2019년의 P8은 지금도 OS 수업에서 토론 교재로 쓰여서 넣었습니다.

| 각주 | 읽는 날 | 논문 (학회 · 연도) | 배운 것과의 연결 |
| --- | --- | --- | --- |
| P1 | D5 | [How to Write to SSDs](https://arxiv.org/abs/2603.09927) — VLDB 2026 | SSD가 쓰기를 내부에서 몇 배로 불리는 이유(쓰기 증폭)와 DB가 그걸 줄이는 법. D5의 "블록 단위 지우기"가 실제로 치르는 비용 |
| P2 | D6 | [FIFO Queues are All You Need for Cache Eviction](https://pdl.cmu.edu/PDL-FTP/Storage/FIFOqueues-SOSP23_abs.shtml) — SOSP 2023 | FIFO 큐 3개만으로 LRU보다 낮은 미스율. 핵심 관찰은 한 번 쓰이고 버려지는 객체가 대부분이라는 것 |
| P3 | D6, D60 | [SIEVE is Simpler than LRU](https://www.usenix.org/conference/nsdi24/presentation/zhang-yazhuo) — NSDI 2024 | 히트 때 리스트를 옮기지 않아 락이 필요 없는 교체 정책. D60 프록시 캐시를 설계할 때 다시 읽기 |
| P4 | D7 | [FlashAttention](https://arxiv.org/abs/2205.14135) — NeurIPS 2022 | 어텐션 계산을 타일로 쪼개 GPU의 빠른 SRAM 안에서 끝내는 기법. D7의 블로킹이 AI 인프라의 핵심이 된 사례. 서론과 그림 1까지 |
| P5 | D7 | [GoFetch](https://www.usenix.org/conference/usenixsecurity24/presentation/chen-boru) — USENIX Security 2024 | 프리페처가 메모리의 데이터를 주소로 여기고 미리 가져오는 동작 때문에 암호 키가 새는 공격. 캐시의 보안 측면. 서론·배경까지 |
| P6 | D14 | [On the critical path to implant backdoors… Early learnings from XZ](https://arxiv.org/abs/2404.08987) — arXiv 2024 | 2024년 xz 백도어가 IFUNC·동적 링커·GOT를 악용한 경로. D14의 GOT/PLT가 실제 공격 표면이 된 사례 |
| P7 | D19 | [What Modern NVMe Storage Can Do, And How To Exploit It](https://vldb.org/pvldb/vol16/p2090-haas.pdf) — VLDB 2023 | 최신 NVMe SSD 성능을 소프트웨어가 못 따라가는 이유와 I/O 인터페이스 비교 |
| P8 | D21 | [A fork() in the road](https://www.microsoft.com/en-us/research/publication/a-fork-in-the-road/) — HotOS 2019 | fork가 왜 현대 OS에 부담인지 주장하는 짧은 논문. 방금 직접 구현한 spawn과 비교하며 읽기 |
| P9 | D25 | [The Benefits and Limitations of User Interrupts for Preemptive Userspace Scheduling](https://www.usenix.org/conference/nsdi25/presentation/guo) — NSDI 2025 | 타이머 시그널로 하던 사용자 공간 선점을 인텔 사용자 인터럽트로 바꾸면 무엇이 달라지는지. 후속 하드웨어 제안 xUI는 ASPLOS 2025 최우수 논문 |
| P10 | D32 | [Mosaic Pages: Big TLB Reach with Small Pages](https://dspace.mit.edu/handle/1721.1/150362) — ASPLOS 2023 | huge page 없이 TLB 엔트리 하나에 여러 변환을 압축해 TLB reach를 늘리는 설계. D32 실험의 계단이 왜 연구 주제인지 |
| P11 | D33 | [Are You Sure You Want to Use MMAP in Your DBMS?](https://db.cs.cmu.edu/mmap-cidr2022/) — CIDR 2022 | DB가 mmap으로 파일을 다룰 때 생기는 정확성·성능 문제. 읽기 쉬운 편이라 첫 논문으로 추천 |
| P12 | D34 | [Efficient Memory Management for LLM Serving with PagedAttention](https://arxiv.org/abs/2309.06180) — SOSP 2023 | OS의 페이징을 GPU의 KV 캐시에 옮겨 단편화를 없앤 vLLM. 블록 테이블 = 페이지 테이블, 공유 = copy-on-write |
| P13 | D34 | [vAttention](https://www.microsoft.com/en-us/research/publication/vattention-dynamic-memory-management-for-serving-llms-without-pagedattention/) — ASPLOS 2025 | P12의 반론. KV 캐시를 가상 주소로는 연속으로 두고, 물리 메모리는 요구 시 할당(demand paging) |
| P14 | D35 | [Virtual-Memory Assisted Buffer Management](https://doi.org/10.1145/3588687) — SIGMOD 2023 | P11과 짝. mmap에 맡기지 않고 가상 메모리 기능을 직접 다뤄 버퍼 관리를 단순하고 빠르게 |
| P15 | D40 | [Tree Borrows](https://pldi25.sigplan.org/details/pldi-2025-papers/42/Tree-Borrows) — PLDI 2025 | Miri가 검사하는 Rust 별칭 규칙의 새 모델. unsafe 코드가 언제 UB가 되는지. 2025년 서울 개최 PLDI의 우수 논문. 1\~2장 예제까지 |
| P16 | D41 | [Characterizing a Memory Allocator at Warehouse Scale](https://research.google/pubs/characterizing-a-memory-allocator-at-warehouse-scale/) — ASPLOS 2024 | 구글 TCMalloc을 데이터센터 규모에서 분석. 크기 클래스·할당기 캐시 계층·단편화가 실제로 어떻게 보이는지 |
| P17 | D49 | [High-Performance DBMSs with io\_uring: When and How to Use It](https://arxiv.org/abs/2512.04859) — VLDB 2026 | 준비 기반 epoll 대 완료 기반 io\_uring, 공유 링 버퍼와 배칭으로 시스템 콜 비용을 나누는 법. 그냥 바꾸기만 하면 이득이 작다는 결론이 핵심 |
| P18 | D55 | [Understanding and Detecting Real-World Safety Issues in Rust](https://par.nsf.gov/biblio/10509785) — IEEE TSE 2024 | 실제 Rust 프로젝트의 메모리·동시성 버그 분석. 데드락처럼 safe Rust에서도 생기는 버그 |
| P19 | D63 | [An Empirical Study of Rust-for-Linux](https://www.usenix.org/conference/atc24/presentation/li-hongyu) — USENIX ATC 2024 | 리눅스 커널에 Rust를 넣으며 생긴 성공·불만·타협. 안전 추상화와 FFI의 비용. 최우수 논문 |
| P20 | D63 | [Asterinas](https://www.usenix.org/conference/atc25/presentation/peng-yuke) — USENIX ATC 2025 | unsafe를 작은 TCB 안에 가두는 Rust 기반 리눅스 호환 OS. 9주 동안 sysx에서 한 일을 커널 규모로 한 설계 |

각 논문의 가치는 `docs/PAPERS-ANSWERS.md`에 답안지로 따로 적었습니다. 파일 위쪽의 질문만 먼저 보고 논문을 읽은 뒤, 노트를 쓰고 나서 아래쪽 가치와 비교하세요.

### 논문 읽는 법

- **언제**: 평일엔 읽지 않습니다. 각주가 달린 주의 주말 코드 리딩 시간(30\~60분)에 한 편씩 읽습니다. 주 1편이면 충분하고, 건너뛰어도 진행에는 지장이 없습니다.
- **3단계 읽기**: 1회독(10분)은 제목·초록·서론·그림·결론만 보고 "문제와 아이디어"를 한 줄로 씁니다. 2회독(30\~60분)은 그림과 실험 위주로 읽고 증명·세부 구현은 건너뜁니다. 3회독은 특히 끌리는 논문만 합니다. USENIX 논문은 발표 자료가 공개되니 발표 영상부터 보면 시작이 쉽습니다.
- **5줄 노트**: papers/P11.md 같은 파일에 문제, 핵심 아이디어, 기대고 있는 Dn 개념, 비교 대상, 한계·반론을 적고 `docs/PAPERS-ANSWERS.md`와 비교합니다.
- **미니 재현**: P2·P3은 내 cachesim에 S3-FIFO·SIEVE를 추가해 내 트레이스로 미스율 비교, P8은 프로세스 메모리를 키워 가며 fork와 posix\_spawn 시간 비교, P11은 내 Mmap과 Fd로 랜덤 읽기 비교, P15는 내 할당기 테스트를 Miri의 Tree Borrows 모드로 실행.
- **짝 읽기와 토론**: P11과 P14, P12와 P13은 같은 문제에 다른 답을 냅니다. "누가 옳은가"가 아니라 "어떤 조건에서 옳은가"를 적어 보고, "P11 토론"이라고 보내면 제가 심사위원 역할로 질문합니다.

출처(확인한 페이지): [CS:APP3e 랩 페이지](https://csapp.cs.cmu.edu/3e/labs.html), [The Book 목차](https://doc.rust-lang.org/book/toc.html), [Rust 2024 에디션 목차](https://doc.rust-lang.org/edition-guide/toc.html), [새로 unsafe가 된 함수](https://doc.rust-lang.org/edition-guide/rust-2024/newly-unsafe-functions.html), [Rust Atomics and Locks](https://mara.nl/atomics/)

날짜별 CSAPP 읽기 범위는 [CS:APP3e 목차](https://csapp.cs.cmu.edu/3e/pieces/preface3e.pdf)의 절 번호를 기준으로 했습니다.
