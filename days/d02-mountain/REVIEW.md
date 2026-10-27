# D2 리뷰

## 2026-10-27 · 1차

| 항목 | 평가 | 근거 |
|---|---|---|
| 정확성 | ○ | check.sh OK 55 · FAIL 0(시간 지역성 s8 5.81배, 공간 지역성 5.76배, 기본 실행 7.1초), `cargo test` 3개 통과. 단, 넘침 외의 경계 테스트가 n−1을 못 봄(아래 필수 1) |
| 견고성 | ○ | 추가 입력 16개(`-\xff`, `--`, `-`, `16KK`, `16MK`, `0K`, `' 16K'`, 값 없는 `-M`·`-S`, 남는 인자 등)에서 패닉 없음, 종료 코드 1. `-\xff`만 명세(E2 unknown option)와 달리 usage |
| 구조 | ○ | `parse_value`(값·UTF-8) / `parse_size` / `parse_stride` / `write_mountain(out: &mut impl Write, …)` / `measure` 모듈. `main`은 조립만(1-1), 출력은 인자로(1-2) |
| 성능 | ○ | `black_box`를 데우기와 반복 모두에서 입력·결과에(F4), 10ms 묶음, `vec![1u64; n]`로 모든 페이지를 씀(최대 RSS 264192KB), `BufWriter` + 끝에서 `flush` |
| 이름 | △ | `MIN_SIZE`·`MAX_SIZE`·`multiplier`·`digits`는 좋음. `InvalidUTF`(std 관례는 `Utf8`), `DEFAULT_STRIDE = 1 << 4`(stride는 2의 거듭제곱 개념이 아님), u64 크기 8이 세 곳에 따로 |
| 관용구 | ○ | `iter().step_by` + `wrapping_add`, `strip_suffix` 사슬, `checked_mul` + `ok_or_else`, `(a..=b).contains`, `trailing_zeros` 지수 루프. clippy 0, fmt 통과. pedantic 2개(정수 → f64 정밀도, 학습용) |
| 규칙 준수 | △ | D2가 아직 커밋 전인데 루트 README가 `완료`. 워크스페이스 clippy 경고 1(`d00-wc-lite/src/counts.rs:22`, D1부터). 기록의 결과 숫자(튜터가 잰 실행)와 `results/mountain.csv`(학습자 실행)가 서로 다른 실행 |

### 반드시 고칠 것
- 명세의 테스트 요구 "길이를 나누지 않는 stride(마지막 원소가 읽히는 경우)": `undivisible_stride`는 길이 8, stride 3이라 0·3·6만 읽고 마지막 원소 7을 읽지 않는다. 그래서 `while i < data.len() - 1` 같은 n−1 경계 버그를 못 잡는다(튜터가 scratchpad에서 확인: 길이 8은 정답·버그 모두 73, 길이 7은 정답 73·버그 9). 길이 7, stride 3으로 바꾼다
- 커밋: 워크스페이스 clippy 경고를 0으로(wc-lite는 따로 커밋) → D2 커밋(`Cargo.lock`, 루트 README 포함). 루트 README `완료`는 커밋과 함께

### 원칙
- 6-2: 경계값 n−1(위 필수)
- 4-4: `InvalidUTF` → `InvalidUtf8`(std의 `Utf8Error`, `from_utf8`처럼 약어도 한 단어로)
- 3-3: `u64` 하나 = 8바이트라는 사실이 `main.rs` 56·135줄과 `measure.rs` 25줄(`8f64`)에 흩어져 있음 → `size_of::<u64>()` 한 곳
- 2-3 (선택): `-\xff`가 `usage`로 나옴. 명세 E2는 `-`로 시작하는 나머지를 unknown option으로(lossy 허용)

### 개념 정정
- 예측 ② "debug 마운틴이 더 차이가 클 것": 반대. debug는 원소마다 명령어 비용(796MB/s ÷ 8B ≈ 초당 1억 번, 약 10ns)이 커서 캐시와 DRAM의 차이를 덮는다. `-M 64M -S 16`에서 s8 열 16KB÷64MB가 debug 1.14배, release 6.0배. 최적화는 메모리 차이를 숨기는 게 아니라 드러낸다
- 예측 ① "1/2씩 떨어지다 고정": 방향은 맞음. 실제 0.64·0.55·0.63·0.77배. s1→s2가 절반보다 덜 떨어지는 것은 s1에서 루프 자체의 속도 한계(L1에서도 약 14GB/s)에 가까워서 DRAM 대역폭이 다 드러나지 않기 때문으로 보인다. s8 뒤에도 떨어지는 이유(프리페치, DRAM 행 버퍼)는 가설이고 확인하지 않았다

### 퀴즈
- 1.5 / 5 (○ 1, △ 1, ✕ 3)
  - ✕ `black_box(for …)`가 끝나지 않은 이유: `for`의 값은 `()`라 `black_box`가 받는 건 빈 값이고, `read_stride` 결과는 버려져 호출이 지워진다 → 잰 시간이 0에 가까워 10ms에 닿지 않음 → `repeat`이 끝없이 두 배 → release에서 넘쳐 0이 되어 무한 루프. 답은 "repeat이 증가하지 않아서"로 반대
  - △ `vec![0u64; n]`만 읽기: 평평해진다는 결과는 맞음. 원인은 컴파일러·캐시가 0을 알아서가 아니라, OS가 쓰지 않은 페이지를 전부 물리 0 페이지 하나에 매핑해서(256MB를 읽어도 4KB 한 장). 최대 RSS 약 2MiB가 빠짐(참조 구현으로 확인)
  - ✕ `-S 64`의 L1d 실효 크기: 세트 = (주소 ÷ 64) mod 64라 512바이트마다 세트가 8씩 늘어 64개 중 8개만 씀 → 8세트 × 8줄 × 64B = 4KiB. D2 브리핑 퀴즈 1에 이어 두 번째 ✕ → 다음 브리핑 퀴즈에 다시 넣는다
  - ○ `parse` 타입 추론: 결과 타입을 `let n: u64`나 `parse::<u64>()`로 알려 준다
  - ✕ `ok_or` vs `ok_or_else`(Some일 때): 결과는 둘 다 `Ok(값)`으로 같다. `ok_or`의 인자는 호출 전에 먼저 만들어져 `String` 할당이 매번 일어났다 버려지고, `ok_or_else`의 클로저는 `None`일 때만 실행된다. D1의 `map_err` 퀴즈와 같은 지연 평가
