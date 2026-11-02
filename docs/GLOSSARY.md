# 용어·이름 사전

골격과 학습자 코드의 이름은 이 사전을 따른다. 이름을 고민하는 데 시간을 쓰지 않게 하려는 파일이다.

- 새 이름이 필요하면 튜터가 먼저 여기에 적고 골격에 쓴다.
- 학습자가 보조 함수를 직접 만들 때도 아래 관례를 따르면 된다. 리뷰에서 이름은 지적하지 않는다.
- CSAPP 기호(S, E, B, s, b, t, m 같은)는 주석에 함께 적고, 식별자는 마일스톤 표의 이름을 쓴다.

## 공통 관례

| 뜻 | 형태 | 예 |
|---|---|---|
| 비트 수 | `*_bits` | `set_bits`, `block_bits` |
| 바이트 크기 | `*_size` | `block_size`, `page_size` |
| 개수 | `*_count` | `set_count`, `line_count` |
| 배열 위치 | `*_index` | `set_index`, `line_index` |
| 주소 | `addr`, `*_addr` | `vaddr`, `paddr` |
| 바이트 오프셋 | `offset`, `*_offset` | `block_offset` |
| 참·거짓 | `is_*`, `has_*` | `is_dirty`, `has_empty_line` |
| 묶음(컬렉션) | 복수 명사 | `sets`, `lines`, `jobs` |
| 생성 | `new`, `with_*` | `Cache::new`, `Vec::with_capacity` |
| 실패할 수 있는 생성 | `try_new`, `TryFrom` | `Geometry::try_new` |
| 변환 | `from_*`, `to_*`, `as_*`, `into_*`(std 관례) | `u64::from_le_bytes` |
| 통계 묶음 | `Stats` | `Stats { hits, misses, evictions }` |
| 오류 enum | `<무엇>Error` | `ParseError`, `ElfError` |
| 결과 enum | `Outcome` | `Outcome::Hit` |

- 짧은 이름은 짧은 범위에만 쓴다: 루프 변수 `i`, 짧은 클로저의 인자 정도. 함수 인자와 필드는 역할로 짓는다.
- 한 개념에는 한 단어만 쓴다. 예를 들어 캐시의 한 줄은 어디서나 `line`이고 `entry`나 `slot`으로 바꿔 부르지 않는다.

## M1 메모리 계층

M1 시작 때 채운다.

## M2 링킹

M2 시작 때 채운다.

## M3 시스템 수준 I/O와 예외적 제어 흐름

M3 시작 때 채운다.

## M4 가상 메모리

M4 시작 때 채운다.

## M5 네트워크 프로그래밍

M5 시작 때 채운다.

## M6 동시성

M6 시작 때 채운다.
