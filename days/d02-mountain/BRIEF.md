# D2 브리핑 · mountain

2026-10-22. 명세는 `README.md`, 개념은 `concepts/d02-memory-mountain.md`.

D1에서 넘어온 것: 리뷰의 "반드시 고칠 것"은 65c1c62에서 해결됐다(check.sh OK 60 · FAIL 0, `cargo test` 4개 통과, D1 clippy 경고 0, `cargo fmt --check` 통과). 워크스페이스 clippy 경고가 하나 남아 있다: `days/d00-wc-lite/src/counts.rs:22`(`collapsible_match`). 오늘 커밋 전에 `cargo clippy -q --workspace`를 0으로 만들려면 따로 고쳐서 따로 커밋한다.

## 1. 복습 퀴즈 (D1)
1. 이 머신의 L1d(s = 6, E = 8, b = 6)에서 `u64` 배열을 stride 64(512바이트 간격)로 읽으면, 연속된 읽기의 세트 인덱스는 어떻게 바뀌나? 그러면 L1d 32KiB 중 몇 바이트어치 줄만 쓸 수 있나? stride 8(64바이트 간격)이면?
2. D1의 버그 `addr.checked_shr(slice_bits).unwrap_or_default();`는 왜 `addr`를 바꾸지 못했나? 오늘 `sum.wrapping_add(x);`라고 쓰면 컴파일러가 경고를 내는데, D1의 그 줄에서는 왜 아무 말이 없었나?

## 2. 명세 요점
```
mountain [-M <최대 크기>] [-S <최대 stride>]     # 기본 -M 256M -S 16
```
- `u64` 배열 하나를 한 번만 만들고 **모든 원소에 0이 아닌 값을 쓴다.** 크기 16K, 32K, …, M마다 앞부분 슬라이스 `&data[..n/8]`를 빌려준다
- 칸마다 `throughput`: 한 번 데우고, r = 1부터 두 배씩 늘려 r번 연달아 읽는 시간이 10ms 이상이 되면 MB/s = r × ⌈길이/k⌉ × 8 ÷ 초 ÷ 10^6. 슬라이스와 합은 `black_box`에 통과시킨다
- 출력은 CSV: `size,s1,…,sS` 머리줄 + 크기마다 한 줄(MB/s 정수). 표준 에러는 비어 있다
- 오류 E1~E4: `mountain: …` 한 줄, 종료 코드 1, 표준 출력 비움. 값 오류에는 옵션 이름과 받은 값
- 제약: `src/measure.rs`의 `read_stride` + `throughput`, 테스트 3개 이상(stride 1, 나누어떨어지지 않는 stride, 넘침), std만, unsafe 없음, `args_os`, enum + `Display`, `writeln!` + `flush`
- 완료 기준: check.sh(release 빌드). 모양·오류 검사에 더해 기본 실행에서 s8 열의 16KB ÷ 256MB ≥ 3, 256MB 행의 s1 ÷ s16 ≥ 3, 실행 시간 ≤ 20초
- 결과물: `results/mountain.csv`, `results/mountain.png`, 기록에 환경과 능선 대조
- 확장: `-u`(4×4 언롤링, `EXT=1`), `taskset`으로 코어 고정

## 3. 개념 핵심 (CSAPP 6.1.1, 6.2, 6.3, 6.6.1)
- **SRAM과 DRAM (6.1.1)**: SRAM은 비트마다 트랜지스터 6개라 빠르고 비싸다(캐시). DRAM은 비트마다 축전기 하나라 싸지만 느리고, 주기적으로 다시 써 줘야 한다(메인 메모리). DRAM은 행을 통째로 행 버퍼에 올리므로 같은 행을 이어 읽는 것이 싸다
- **지역성 (6.2)**: 같은 곳을 곧 다시 쓰면 시간 지역성, 근처를 곧 쓰면 공간 지역성. stride-k 참조에서 k가 작을수록 공간 지역성이 좋다. C 2차원 배열은 행 우선이라 행을 따라 훑어야 stride-1이다
- **메모리 계층 (6.3)**: 층 k는 층 k+1의 캐시다. 블록 단위로 옮기고, 미스는 cold·conflict·capacity. 작업 집합이 캐시보다 크면 capacity 미스가 쏟아진다
- **메모리 마운틴 (6.6.1)**: 같은 배열을 되풀이해 읽으니 크기 = 작업 집합이다. 크기 축에는 층마다 평평한 시간 지역성의 **능선**, stride 축에는 공간 지역성의 **비탈**이 생긴다. 하드웨어 프리페처는 작은 stride의 순차 패턴을 미리 가져와 지연을 숨긴다
- **이 머신**: L1d 32KiB(코어마다), L2 2MiB(코어 4개가 함께), L3 6MiB, 블록 64바이트 = `u64` 8개. `lscpu`의 "L1d 128 KiB (4 instances)"는 4코어의 합이다
- **연습문제**: 예측 전에 6.7(3차원 배열을 stride-1로 훑게 루프 순서 바꾸기)과 6.8(세 함수의 공간 지역성 순위)을 손으로 푼다. 결과를 해석할 때는 6.21의 방법(처리량 → 사이클/읽기, 개념 문서 4절)으로 내 L1 값을 사이클로 바꿔 본다

자세한 내용: `concepts/d02-memory-mountain.md`

## 4. 오늘 쓸 Rust 문법
아래 출력은 모두 이 머신(rustc 1.99.1)에서 돌려 본 것이다.

1. **`Vec`은 주인이 하나, 슬라이스는 빌린 (포인터, 길이).** C에서는 `malloc`한 포인터와 길이를 따로 넘기고, 길이를 틀려도 아무도 모른다. Rust의 `&v[..n]`은 둘을 묶은 16바이트짜리 값이고, 범위를 넘으면 UB가 아니라 패닉이다.
   ```rust
   fn mean(xs: &[f64]) -> f64 {
       xs.iter().sum::<f64>() / xs.len() as f64
   }

   let temps: Vec<f64> = (0..48).map(|h| 20.0 + f64::from(h) * 0.5).collect();
   mean(&temps)                              // 31.75  전체를 빌려준다
   mean(&temps[..24])                        // 25.75  앞 24개만. 복사 없음
   std::mem::size_of::<&[f64]>()             // 16     포인터 + 길이
   temps.as_ptr() == temps[..24].as_ptr()    // true   같은 메모리
   &temps[..100]   // 패닉: range end index 100 out of range for slice of length 48
   let moved = temps;  // 소유권 이동. 이 뒤에 temps.len()은 E0382 (borrow of moved value)
   ```
   함수가 `Vec<f64>`를 받으면 소유권을 가져가고, `&[f64]`를 받으면 빌리기만 한다(PRINCIPLES 3-1). `rustc --explain E0382`

2. **정수: 넘침은 debug에서 패닉, `wrapping_*`·`checked_*`로 뜻을 밝힌다.** C의 unsigned 덧셈은 조용히 감긴다. Rust는 debug(`cargo test` 포함)에서 패닉하고 release에서 감긴다.
   ```rust
   let x: u8 = black_box(250);
   x.wrapping_add(10)          // 4
   x.checked_add(10)           // None
   x + 10                      // debug: 패닉 "attempt to add with overflow" / release: 4
   u64::MAX.checked_mul(2)     // None
   4096u64.is_power_of_two()   // true
   4096u64.trailing_zeros()    // 12  (2의 거듭제곱의 log2)
   10_000usize.div_ceil(4096)  // 3   ((a + b - 1) / b로 쓰면 clippy::manual_div_ceil 경고)
   (0..20).step_by(5)          // 0, 5, 10, 15
   [10, 11, 12, 13, 14, 15, 16].iter().step_by(3)   // 10, 13, 16
   "250ms".strip_suffix("ms")  // Some("250")
   "3s".strip_suffix("ms")     // None
   "".parse::<u64>()           // Err(ParseIntError { kind: Empty })
   "1.5".parse::<u64>()        // Err(ParseIntError { kind: InvalidDigit })
   ```
   정수 메서드는 값을 바꾸지 않고 새 값을 돌려준다. `total.wrapping_add(addr);`처럼 결과를 버리면 `warning: unused return value of ... wrapping_add that must be used`가 뜬다.

3. **`Instant`와 `Duration`.** C에서는 `clock_gettime(CLOCK_MONOTONIC, &ts)`를 두 번 부르고 `timespec`을 직접 뺐다. Rust는 뺄셈과 단위 변환을 타입이 해 준다. 이 머신에서 `Instant::now()`는 vDSO로 처리되어 시스템 콜이 없다(strace로 확인).
   ```rust
   use std::time::{Duration, Instant};
   let start = Instant::now();
   names.sort();
   let dt: Duration = start.elapsed();
   println!("{:.3} ms", dt.as_secs_f64() * 1e3);
   if dt < Duration::from_millis(10) { /* … */ }
   ```

4. **`std::hint::black_box`: "이 값을 컴파일러가 모르게, 그리고 쓰이게".** C에서는 `volatile` 변수에 쓰거나 빈 `asm volatile`을 썼다. 결과를 아무도 안 쓰면 release 빌드는 계산을 통째로 지운다.
   ```rust
   fn collatz_steps(mut n: u64) -> u32 { /* n이 1이 될 때까지 세기 */ }

   for _ in 0..10_000_000 { collatz_steps(27); }                         // 결과 버림
   for _ in 0..10_000_000 { black_box(collatz_steps(black_box(27))); }   // 입력·결과 모두 black_box
   ```
   release(`rustc -O`)에서 세 번 재니 위 루프는 매번 0.000ms, 아래 루프는 1519~1547ms였다. 위 루프는 지워졌다.

5. **release와 debug.** `cargo build`·`cargo run`·`cargo test`는 dev 프로필(최적화 없음, 넘침 검사 켬)이고, `--release`는 최적화를 켜고 넘침 검사를 끈다. 바이너리도 `target/debug/`와 `target/release/`로 갈린다. 측정은 언제나 `--release`로 한다(CLAUDE.md 규칙 5). 얼마나 다른지는 오늘 예측 2다.

## 5. 흔한 함정
check.sh의 힌트가 "함정 1", "함정 2"라고 부르는 것이 아래 1·2번이다.
1. **값을 안 쓴 배열.** `vec![0u64; n]`만 하고 원소를 쓰지 않으면, 읽기만 하는 페이지가 전부 같은 0 페이지를 가리킨다. 참조 구현을 이렇게 고쳐 보니 마운틴이 모든 크기에서 평평했고 최대 RSS가 약 2MiB였다. 모든 원소에 0이 아닌 값을 쓴다(개념 문서 7절 4번, D31)
2. **`black_box`를 빼면 프로그램이 끝나지 않는다.** 재는 루프가 지워져 시간이 0에 가까우니 "10ms가 될 때까지 r을 두 배"가 끝나지 않는다. release에서는 r이 넘쳐 0으로 감긴 뒤 영원히 돈다(참조 구현으로 확인). check.sh는 40초에 끊는다. 슬라이스에만 `black_box`를 쓰고 합을 버려도 읽기가 사라진다. **슬라이스와 합 둘 다** 통과시킨다
3. **`cargo run`은 debug다.** 측정 결과를 볼 때는 `cargo run --release -p mountain` 또는 `target/release/mountain`. check.sh는 알아서 release로 빌드한다
4. **넘침 테스트는 debug에서 돈다.** `read_stride`에서 `sum += x`로 더하면 release 바이너리는 멀쩡하지만, `u64::MAX`를 넣은 테스트가 `cargo test`에서 `attempt to add with overflow`로 패닉한다
5. **처리량의 분자는 실제로 읽은 바이트다.** stride와 상관없이 `길이 × 8`로 세면 큰 stride가 오히려 빨라 보인다. 참조 구현을 이렇게 고치면 256MB 행의 s1 ÷ s16이 0.42가 되어 check.sh의 공간 지역성 검사에서 FAIL이다. ⌈길이 ÷ k⌉는 `div_ceil`

## 6. 예측 (구현 전에 README `예측:`에)
1. 기본 실행의 256MB 행(DRAM 영역)에서 stride를 1 → 16으로 늘리면 처리량은 어떤 모양으로 떨어질까? 어느 stride 근처에서 꺾이고, s16은 s1의 몇 분의 1쯤일까? 개념 문서 2절의 방법에 원소 8바이트, 블록 64바이트를 넣어 따져 본다
2. 16KB 행·stride 1 칸을 debug 빌드로 재면 release보다 몇 배 느릴까? 그리고 debug 빌드로 그린 마운틴에서는 L1과 DRAM의 차이(능선의 높이 차)가 커질까, 작아질까?

## 7. 진행
1. `src/measure.rs`에 `read_stride`와 테스트 3개 → `main.rs`에 `mod measure;` → `cargo test -p mountain`
2. `throughput`: `Instant`, `black_box`, r을 두 배씩. `main`에서 작은 `Vec`로 한 칸만 찍어 본다
3. `main`: 배열 한 번 할당·채우기 → 크기 × stride 루프 → `BufWriter`로 CSV
4. 인자와 오류 E1~E4(D1의 파싱 구조를 다시 쓴다)
5. `./days/d02-mountain/check.sh`
6. 결과:
   - `cargo run -q --release -p mountain > days/d02-mountain/results/mountain.csv`
   - 그래프: `sudo apt install gnuplot-nox`(이 머신에는 아직 gnuplot이 없다). 아래 스크립트를 `days/d02-mountain/results/mountain.gp`로 저장하고 실행한다. 같은 버전(gnuplot 6.0.0, apt의 gnuplot-nox)을 설치하지 않고 풀어서, 참조 구현의 CSV로 PNG가 그려지는 것을 확인했다
     ```gnuplot
     set datafile separator comma
     set terminal pngcairo size 1100,800
     set output png
     set title 'Memory mountain'
     set xlabel 'stride (x8 bytes)' offset 0,-1
     set ylabel 'size (bytes)' offset 8,0
     set zlabel 'MB/s' rotate parallel
     set view 60, 30
     set xrange [*:*] reverse
     set yrange [*:*] reverse
     set xyplane 0
     set grid
     set pm3d depthorder border lc 'black'
     set palette rgbformulae 33,13,10
     unset colorbox
     splot csv matrix columnheaders rowheaders using 1:2:3 with pm3d notitle
     ```
     ```sh
     R=days/d02-mountain/results
     gnuplot -e "csv='$R/mountain.csv'; png='$R/mountain.png'" $R/mountain.gp
     ```
   - 능선 대조: CSV의 s8 열을 위에서 아래로 읽으며 크게 떨어지는 크기를 찾아 L1d 32KiB, L2 2MiB, L3 6MiB와 맞춰 본다
   - 예측 2 확인: `cargo run -q -p mountain -- -M 64M -S 16`(debug)과 `cargo run -q --release -p mountain -- -M 64M -S 16`을 비교한다. 참조 구현은 둘 다 6초 안팎이었다(칸마다 10ms 넘게 재는 규칙 때문에 시간은 비슷하다)
7. 기록: 예측 / 결과 / 배운 것과 숫자 세 개. 결과 줄에 환경 한 줄(`lscpu | grep 'Model name'`, `uname -r`, `--release`)을 붙인다

- 90분이 넘으면 그 상태로 커밋한다. 컴파일이 안 되면 끝에 `(WIP)`
- 15분 넘게 막히면 "힌트 1". 끝나면 `./days/d02-mountain/check.sh` → "D2 리뷰"
