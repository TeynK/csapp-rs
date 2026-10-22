# D1 브리핑 · addr-split

2026-10-19에 채팅으로 보낸 브리핑을 옮긴 것이다. 명세는 `README.md`, 개념은 `concepts/d01-cache-organization.md`.

## 1. 복습 퀴즈 (D0-일)
1. wc-lite 파일 루프에서 `let data = fs::read(path)?;`라고 썼다면 `wc-lite -l a.txt nofile b.txt`(a, b는 정상 파일)의 표준 출력, 표준 에러, 종료 코드는? 명세와 무엇이 다른가?
2. `run`이 `Result<bool, Box<dyn Error>>`를 돌려줄 때 `Err(CliError::Usage)?`가 컴파일되려면 `CliError`에 무엇이 구현돼 있어야 하나? `?`는 그걸로 무슨 변환을 하나?

## 2. 명세 요점
```
addr-split <주소> -s <s> -E <E> -b <b> [-m <m>]     # m 기본 64
```
- 주소는 `0x`/`0X`면 16진수, 아니면 10진수. 주소 < 2^m
- 6줄 출력: `address`, `bits`(`tag|set|offset` 2진수, 폭 0인 필드는 빈 문자열이라 `|`는 언제나 2개), `tag`, `set`, `offset`, `cache`(S, E, B, C)
- S, B, C는 u64를 넘을 수 있다(s + b = 64). 넘쳐도 맞는 값을 쓴다
- 오류 E1~E6: 모두 `addr-split: …` 한 줄, 종료 코드 1, 표준 출력 비움. 메시지에 맥락을 담는다(PRINCIPLES 2-3)
- 제약: `src/geometry.rs`의 `Geometry::split(&self, addr) -> Parts` + 테스트 3개 이상(첫 예시, s = 0, t = 0), 오류는 enum + `Display`, `args_os`, `writeln!` + `flush`
- 확장: `-n N` 같은 세트 주소 생성(`EXT=1`)

## 3. 개념 핵심 (CSAPP 6.4.1~6.4.2)
- 캐시는 (S, E, B, m): 세트 S = 2^s, 세트마다 줄 E, 줄마다 valid + tag + 블록 B = 2^b바이트. C = S × E × B는 데이터 바이트만 센다
- 주소 = tag(t = m − s − b) | set index(s) | offset(b)
- 직접 사상(E = 1): 세트 선택 → 줄 매칭(valid && tag) → 워드 선택. miss면 그 줄을 통째로 교체
- 같은 세트로 가는 두 블록을 번갈아 쓰면 빈 세트가 있어도 서로 쫓아낸다(conflict miss, dotprod 예, 연습문제 6.10)
- 세트 인덱스가 중간 비트인 이유: 연속된 블록을 모든 세트에 퍼뜨리려고(연습문제 6.11)
- 이 머신(sysfs): L1d 32KiB = 64세트 × 8-way × 64B(s = 6, E = 8, b = 6). L3는 12-way(E가 2의 거듭제곱이 아니어도 된다). L1d의 s + b = 12 = 4KiB 페이지 오프셋 비트 수(D32에서 다시)
- 연습문제 6.9를 손으로 풀고 도구로 C를 검산한다

자세한 내용: `concepts/d01-cache-organization.md`

## 4. 오늘 쓸 Rust 문법
1. **정수 타입은 저절로 섞이지 않는다.** C의 정수 승격이 없다. `u64 + u32`는 `E0308` + `E0277`(cannot add `u32` to `u64`). 시프트는 예외로 `x_u64 << s_u32`가 된다. 넓히기는 `u128::from(x_u64)`, 좁히기는 `u32::try_from(x)`
2. **넘침 다루기.** C의 unsigned는 조용히 wrap하고, 폭 이상 시프트는 UB다. Rust(이 머신에서 확인):
   ```rust
   let px: u64 = 1 << 40;
   px.checked_mul(px)               // None
   u128::from(px) * u128::from(px)  // 1208925819614629174706176
   1u64.checked_shl(64)             // None
   ```
3. **문자열 → 수.** C의 `strtoul(s, &end, 16)`은 `0x`를 받아 주지만 Rust의 `from_str_radix`는 아니다.
   ```rust
   let mode = "0755";
   let digits = mode.strip_prefix('0').unwrap_or(mode); // Option<&str>
   let n = u32::from_str_radix(digits, 8)?;             // 493
   ```
4. **포맷.** `w$`는 C의 `%0*d`.
   ```rust
   let g = (0x12_34_56u32 >> 8) & 0xff;
   println!("{g:#x} {g:08b} {n:#o}");              // 0x34 00110100 0o755
   format!("[{:0w$b}] [{:>w$}]", 5u8, "ab", w = 6) // [000101] [    ab]
   ```

## 5. 흔한 함정
1. m = 64가 기본값이다. 범위 검사를 `1u64 << m`처럼 쓰면 정상 실행마다 debug에서 `attempt to shift left with overflow`. t = 0의 `>> 64`, s = 64의 마스크도 같다. release는 조용히 `1u64 << 64 == 1`
2. S × E × B를 u64로 계산하면 `attempt to multiply with overflow`. `-s 4294967295 -b 1`의 `s + b`도 넘친다
3. `{:0w$b}`는 w = 0이어도 0을 `0`으로 찍는다. 그대로 쓰면 빈 필드가 `|0|`이 된다
4. `from_str_radix`는 `0x`도 `0X`도 모른다. `0x`만 떼면 빈 문자열이고 결과는 `Err(Empty)`
5. `std::env::args()`는 UTF-8이 아닌 인자에서 패닉하고, `println!`은 `/dev/full`에서 `failed printing to stdout: No space left on device`로 패닉한다. 둘 다 check.sh에 케이스가 있다

## 6. 예측 (구현 전에 README `예측:`에)
1. `addr-split 0x0E34 -m 13 -s 3 -E 2 -b 2`의 bits 줄과 tag·set·offset을 손으로 구한다(CSAPP 연습문제 6.12~6.13의 캐시와 주소. 책 뒤의 답은 보지 않는다)
2. 명세 첫 예시에서 `-E 2`만 `-E 4`로 바꾸면 6줄 중 어느 줄이 어떻게 바뀌나? 이유는?

## 7. 진행
- 순서: ① `geometry.rs`의 `split` + 테스트 3개(`cargo test -p addr-split`) ② 인자 파싱 ③ 6줄 출력 ④ 오류 E1~E6
- 90분이 넘으면 그 상태로 커밋. 컴파일이 안 되면 끝에 `(WIP)`
- 15분 넘게 막히면 "힌트 1". 끝나면 `./days/d01-addr-split/check.sh` → "D1 리뷰"
