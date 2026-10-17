# 저장소 규칙

애매하면 멈추지 말고 가까운 쪽으로 정한 뒤, 필요하면 이 파일을 고친다.

## 이름
- Day 폴더는 `days/dNN-도구이름`: 두 자리 번호, 소문자, 단어는 `-`로 연결 (예: `days/d01-addr-split`)
- 패키지 이름은 도구 이름: `cargo new days/d01-addr-split --name addr-split`
- 여러 날 이어지는 프로그램은 첫날 번호 폴더 하나에서 계속 (예: `days/d27-tsh`)
- 뒤에서 재사용할 라이브러리는 `crates/이름`: 번호 없이 한 단어 (예: `crates/cachesim`). 명세에 `crates/`라고 적힌 날은 처음부터 여기에 만든다
- Rust 코드: 파일·모듈·함수·변수는 `snake_case`, 타입·트레잇은 `UpperCamelCase`, 상수는 `SCREAMING_SNAKE_CASE`
- 식별자는 영어, 주석과 문서는 한국어

## 파일 배치
- Day 폴더에는 `README.md`(명세와 기록), `check.sh`(완료 기준), `REVIEW.md`(리뷰 요지)를 둔다
- 문서는 `docs/`에 둔다: `CURRICULUM.md`(커리큘럼 원본), `SYNTAX.md`, `PAPERS-ANSWERS.md`, `CHECKPOINTS.md`
- 튜터 설정은 `CLAUDE.md`와 `.claude/`
- 통합 테스트는 `tests/`, 테스트 입력 파일은 `tests/data/`
- 측정 결과(작은 CSV·PNG)는 패키지의 `results/`에 두고 커밋
- 1MB가 넘는 생성물(valgrind 트레이스, 큰 테스트 파일)은 `scratch/`에 둔다. 커밋되지 않는다
- 논문 노트는 `papers/P11.md`처럼 각주 번호 그대로
- 버그 일지는 루트 `BUGS.md` 하나

## 커밋
- 형식은 `영역: 한 일`. 한 줄 요약은 50자 안팎
  - Day 작업은 `D7`, 공용 라이브러리는 크레이트 이름(`sysx`, `cachesim`), 저장소 설정·문서는 `repo`
  - 예: `D0: F1~F4 기본 덤프`, `D0: F5 -s 옵션`, `sysx: Fd에 Read 구현`, `repo: 규칙 추가`
- 명세의 기능 번호(F1…)를 적는다. 리뷰 때 어디까지 했는지 바로 보인다
- 미완성도 커밋한다. 컴파일이 안 되면 끝에 `(WIP)`
- 리뷰 반영은 `D0: 리뷰 반영 - 오류 경로의 unwrap 제거`
- 브랜치는 `main` 하나

## 코드
- 코드 원칙과 예시는 `PRINCIPLES.md`를 따른다
- 커밋 전(WIP 제외): `cargo fmt` → `cargo clippy -q --workspace` 경고 0
- 모든 `unsafe` 위에 `// SAFETY:` 주석 (clippy가 검사)
- 사용자 입력이 닿는 경로에는 `unwrap()`·`expect()`를 쓰지 않는다. 테스트, 그리고 실패할 수 없는 게 자명한 곳만 허용
- 외부 크레이트는 루트 `[workspace.dependencies]`에 버전을 적고, 멤버는 `이름.workspace = true`로 가져온다

## Day 시작과 끝
- 시작: `cargo new` → `cp templates/day-README.md days/dNN-이름/README.md` 후 명세 붙이기 → 루트 README 표에 행 추가 (상태 `진행 중`)
- 끝: 완료 기준 확인 → 패키지 README 기록 채우기 → 루트 README 상태를 `완료`(전부 통과) 또는 `미완(사유)`로 → 커밋·push → "Dn 리뷰"

## 기록
- 날짜는 `YYYY-MM-DD`
- 측정한 날은 기록에 환경 한 줄: CPU 모델(`lscpu`), 커널(`uname -r`), 빌드(`--release`)
- `BUGS.md`는 한 줄에 하나: `날짜 · Dn · 증상 → 원인 → 교훈`
