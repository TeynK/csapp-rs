# csapp-rs

CSAPP(Computer Systems: A Programmer's Perspective, 3판) 6~12장을 Rust로 구현하며 배우는 저장소. 책의 모든 절을 개념 문서로 다루고, CMU 15-213의 랩을 Rust로 푼다. 커리큘럼은 [docs/CURRICULUM.md](docs/CURRICULUM.md)에 있다.

| 마일스톤 | CSAPP | 쌓이는 코드 | 완료 기준 | 상태 |
|---|---|---|---|---|
| M1 메모리 계층 | 6장 | cachesim, csim | Cache Lab | 준비 |
| M2 링킹 | 7장 | elf, elfdump | readelf와 일치 | 준비 |
| M3 시스템 수준 I/O와 예외적 제어 흐름 | 10장, 8장 | sysx(fd·rio·proc·signal), tsh | Shell Lab | 준비 |
| M4 가상 메모리 | 9장 | vmsim, sysx::mmap, alloc | Malloc Lab | 준비 |
| M5 네트워크 프로그래밍 | 11장 | sysx::net, http, tiny | Tiny 동작 | 준비 |
| M6 동시성 | 12장 | sysx::sync, proxy | Proxy Lab | 준비 |

## 폴더

| 폴더 | 내용 |
|---|---|
| `crates/` | 마일스톤을 넘어 쌓이는 라이브러리 |
| `apps/` | 실행 파일 |
| `experiments/` | 실험 |
| `concepts/` | 개념 문서(자작 설명과 문제) |
| `milestones/` | 마일스톤별 명세, 기록, 질문 노트, 리뷰 |
| `papers/` | 논문 세션 기록 |
| `docs/` | 커리큘럼, 저장소 규칙, 이름 사전 |
