#!/usr/bin/env bash
# D1 addr-split 완료 기준
# 비교할 실제 도구가 없어서, 기대 출력은 참조 구현으로 만들어 아래에 적었다.
# 정상 케이스는 표준 출력·표준 에러(비어 있음)·종료 코드(0)를 모두 보고,
# 오류 케이스는 종료 코드 1·빈 표준 출력·표준 에러 첫 줄(접두사와 맥락)·패닉 없음을 본다 (PRINCIPLES 6-2).
# 사용: ./days/d01-addr-split/check.sh
#       X=다른/바이너리 ./days/d01-addr-split/check.sh  (빌드와 단위 테스트 없이 그 바이너리만 검사)
#       EXT=1 ./days/d01-addr-split/check.sh           (확장 -n도 검사)
set -u
if [ -n "${X:-}" ]; then
  [ -x "$X" ] || { echo "X=$X: 실행 파일이 아니다"; exit 1; }
  X=$(realpath "$X")
fi
cd "$(dirname "$0")/../.." || exit 1

unit=
if [ -z "${X:-}" ]; then
  cargo build -q -p addr-split || exit 1
  X=target/debug/addr-split
  unit=1
fi

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
ok=0
fail=0

# ── 판정 도구 ──────────────────────────────────────────────
pass() { ok=$((ok + 1)); echo "OK   $1"; }
miss() { fail=$((fail + 1)); echo "FAIL $1"; shift; for why in "$@"; do echo "       $why"; done; }

# 케이스 이름: 인자를 셸에 다시 넣을 수 있는 모양으로 ('' 는 빈 인자, $'\377' 은 0xff 바이트)
label() {
  if [ $# -eq 0 ]; then echo "(인자 없음)"; return; fi
  local s
  s=$(printf '%q ' "$@")
  echo "${s% }"
}

# 표준 입력은 /dev/null로 주고 실행한다
got() { "$X" "$@" < /dev/null > "$T/out" 2> "$T/err"; echo $? > "$T/code"; }

# 패닉이면 위치 줄과 그다음 메시지 줄을 한 줄로 보여 준다 (패닉 출력은 빈 줄로 시작한다)
panic_msg() { grep -m 1 -A 1 'panicked' "$T/err" | tr '\n' ' '; }

# same 인자... <<'EOF' … EOF
#   표준 입력으로 받은 기대 출력과 표준 출력이 같고, 표준 에러가 비어 있고, 종료 코드가 0인지
same() {
  local why=() line
  cat > "$T/want"
  got "$@"
  if ! cmp -s "$T/want" "$T/out"; then
    why+=("stdout이 다름 (- 기대, + 실제):")
    while IFS= read -r line; do why+=("  $line"); done < <(diff -u "$T/want" "$T/out" | tail -n +3 | head -n 16)
  fi
  [ -s "$T/err" ] && why+=("stderr가 비어 있어야 함: '$(grep -v '^$' "$T/err" | head -n 2 | tr '\n' ' ')'")
  [ "$(cat "$T/code")" = 0 ] || why+=("종료 코드 기대=0 실제=$(cat "$T/code")")
  if [ ${#why[@]} -eq 0 ]; then pass "$(label "$@")"; else miss "$(label "$@")" "${why[@]}"; fi
}

# fails 맥락 인자...
#   종료 코드 1, 표준 출력 비어 있음, 표준 에러 첫 줄이 "addr-split: "로 시작하고 맥락 문자열을 담음, 패닉 없음
#   맥락이 ''이면 담는지는 보지 않는다
fails() {
  local word=$1 why=() first
  shift
  got "$@"
  first=$(grep -m 1 . "$T/err")
  [ "$(cat "$T/code")" = 1 ] || why+=("종료 코드 기대=1 실제=$(cat "$T/code")")
  [ -s "$T/out" ] && why+=("stdout이 비어 있어야 함: '$(head -n 1 "$T/out")'")
  [[ "$first" == "addr-split: "* ]] || why+=("stderr 첫 줄 기대='addr-split: …' 실제='$first'")
  [[ "$first" == *"$word"* ]] || why+=("stderr 첫 줄에 '$word'가 있어야 함 (PRINCIPLES 2-3): '$first'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  local name="오류 $(label "$@")"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

# full 인자...: E6 — 표준 출력이 /dev/full일 때 종료 코드 1, stderr가 "addr-split:"로 시작, 패닉 없음
full() {
  local why=() code first
  "$X" "$@" < /dev/null > /dev/full 2> "$T/err"; code=$?
  first=$(grep -m 1 . "$T/err")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [[ "$first" == "addr-split:"* ]] || why+=("stderr 기대='addr-split:…' 실제='$first'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  local name="> /dev/full: $(label "$@")"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

echo "── 단위 테스트: geometry 모듈"
if [ -n "$unit" ]; then
  f=days/d01-addr-split/src/geometry.rs
  if [ -f "$f" ]; then
    pass "src/geometry.rs 있음"
  else
    miss "src/geometry.rs 있음" "Geometry와 split은 src/geometry.rs에 둔다 (명세 제약)"
  fi
  cargo test -q -p addr-split -- geometry:: > "$T/test.out" 2>&1
  code=$?
  n=$(grep -o '[0-9]* passed' "$T/test.out" | awk '{ s += $1 } END { print s + 0 }')
  if [ "$code" = 0 ] && [ "$n" -ge 3 ]; then
    pass "cargo test: geometry 모듈 테스트 ${n}개 통과"
  else
    miss "cargo test: geometry 모듈 테스트 3개 이상 통과" "종료 코드=$code, 통과=${n}개 (cargo test -p addr-split로 확인)"
  fi
  # #[cfg(test)] 아래에 #[test]가 3개 이상이고, split을 부르는 줄이 있는지 (공용 헬퍼를 거쳐도 된다)
  tests=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c '#\[test\]')
  calls=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c 'split(')
  if [ "$tests" -ge 3 ] && [ "$calls" -ge 1 ]; then
    pass "테스트 ${tests}개가 split을 검사함"
  else
    miss "테스트 3개 이상이 split을 검사함" "#[test] ${tests}개, split을 부르는 줄 ${calls}개 (명세 예시, s = 0, t = 0을 검사한다)"
  fi
else
  echo "SKIP (X를 지정하면 건너뜀)"
fi

A=0x7ff000a4

echo "── F1~F4: 명세 예시와 입력 모양 (순서, 10진수, 대문자, 앞의 0, -m 64, 중복 옵션)"
for args in \
  "$A -s 4 -E 2 -b 5" \
  "-s 4 -E 2 -b 5 $A" \
  "-b 5 $A -E 2 -s 4" \
  "2146435236 -s 4 -E 2 -b 5" \
  "0X7FF000A4 -s 4 -E 2 -b 5" \
  "0x000000000000000007ff000a4 -s 4 -E 2 -b 5 -m 64" \
  "$A -s 9 -s 4 -E 2 -b 5"; do
  # shellcheck disable=SC2086 # 인자를 공백으로 나누려고 일부러 따옴표를 뺐다
  same $args <<'EOF'
address 0x7ff000a4 (m=64)
bits    0000000000000000000000000000000001111111111100000000000|0101|00100
tag     0x3ff800 (t=55)
set     0x5 (s=4)
offset  0x4 (b=5)
cache   S=16 E=2 B=32 C=1024
EOF
done

echo "── F1: 주소 경계 (m = 13에서 0, 1, 2^m − 1 / m = 64에서 u64 최댓값)"
same 0x0 -m 13 -s 3 -E 2 -b 2 <<'EOF'
address 0x0 (m=13)
bits    00000000|000|00
tag     0x0 (t=8)
set     0x0 (s=3)
offset  0x0 (b=2)
cache   S=8 E=2 B=4 C=64
EOF
same 1 -m 13 -s 3 -E 2 -b 2 <<'EOF'
address 0x1 (m=13)
bits    00000000|000|01
tag     0x0 (t=8)
set     0x0 (s=3)
offset  0x1 (b=2)
cache   S=8 E=2 B=4 C=64
EOF
same 0x1fff -m 13 -s 3 -E 2 -b 2 <<'EOF'
address 0x1fff (m=13)
bits    11111111|111|11
tag     0xff (t=8)
set     0x7 (s=3)
offset  0x3 (b=2)
cache   S=8 E=2 B=4 C=64
EOF
for addr in 0xffffffffffffffff 18446744073709551615; do
  same "$addr" -s 4 -E 2 -b 5 <<'EOF'
address 0xffffffffffffffff (m=64)
bits    1111111111111111111111111111111111111111111111111111111|1111|11111
tag     0x7fffffffffffff (t=55)
set     0xf (s=4)
offset  0x1f (b=5)
cache   S=16 E=2 B=32 C=1024
EOF
done

echo "── F2: 폭이 0인 필드 (s = 0, b = 0, t = 0, m = 1)"
same 0xdeadbeef -m 32 -s 0 -E 32 -b 5 <<'EOF'
address 0xdeadbeef (m=32)
bits    110111101010110110111110111||01111
tag     0x6f56df7 (t=27)
set     0x0 (s=0)
offset  0xf (b=5)
cache   S=1 E=32 B=32 C=1024
EOF
same 0xff -s 6 -E 8 -b 0 <<'EOF'
address 0xff (m=64)
bits    0000000000000000000000000000000000000000000000000000000011|111111|
tag     0x3 (t=58)
set     0x3f (s=6)
offset  0x0 (b=0)
cache   S=64 E=8 B=1 C=512
EOF
same 0x2a -m 6 -s 2 -E 1 -b 4 <<'EOF'
address 0x2a (m=6)
bits    |10|1010
tag     0x0 (t=0)
set     0x2 (s=2)
offset  0xa (b=4)
cache   S=4 E=1 B=16 C=64
EOF
same 1 -m 1 -s 0 -E 1 -b 0 <<'EOF'
address 0x1 (m=1)
bits    1||
tag     0x1 (t=1)
set     0x0 (s=0)
offset  0x0 (b=0)
cache   S=1 E=1 B=1 C=1
EOF
same 1 -m 1 -s 1 -E 1 -b 0 <<'EOF'
address 0x1 (m=1)
bits    |1|
tag     0x0 (t=0)
set     0x1 (s=1)
offset  0x0 (b=0)
cache   S=2 E=1 B=1 C=2
EOF
same 1 -m 1 -s 0 -E 1 -b 1 <<'EOF'
address 0x1 (m=1)
bits    ||1
tag     0x0 (t=0)
set     0x0 (s=0)
offset  0x1 (b=1)
cache   S=1 E=1 B=2 C=2
EOF

echo "── F2·F3: s + b = 64 (시프트 64, S·B·C가 u64를 넘음, E = u64 최댓값)"
same 0xffffffffffffffff -s 58 -E 1 -b 6 <<'EOF'
address 0xffffffffffffffff (m=64)
bits    |1111111111111111111111111111111111111111111111111111111111|111111
tag     0x0 (t=0)
set     0x3ffffffffffffff (s=58)
offset  0x3f (b=6)
cache   S=288230376151711744 E=1 B=64 C=18446744073709551616
EOF
same 0x8000000000000001 -s 64 -E 1 -b 0 <<'EOF'
address 0x8000000000000001 (m=64)
bits    |1000000000000000000000000000000000000000000000000000000000000001|
tag     0x0 (t=0)
set     0x8000000000000001 (s=64)
offset  0x0 (b=0)
cache   S=18446744073709551616 E=1 B=1 C=18446744073709551616
EOF
same 0x8000000000000001 -s 0 -E 18446744073709551615 -b 64 <<'EOF'
address 0x8000000000000001 (m=64)
bits    ||1000000000000000000000000000000000000000000000000000000000000001
tag     0x0 (t=0)
set     0x0 (s=0)
offset  0x8000000000000001 (b=64)
cache   S=1 E=18446744073709551615 B=18446744073709551616 C=340282366920938463444927863358058659840
EOF

echo "── F5: 이 머신의 캐시 (Intel N150: L1d 64세트 8-way 64B, L3 8192세트 12-way 64B)"
same 0x7ffd1234abcd -s 6 -E 8 -b 6 <<'EOF'
address 0x7ffd1234abcd (m=64)
bits    0000000000000000011111111111110100010010001101001010|101111|001101
tag     0x7ffd1234a (t=52)
set     0x2f (s=6)
offset  0xd (b=6)
cache   S=64 E=8 B=64 C=32768
EOF
same 0x7ffd1234abcd -s 13 -E 12 -b 6 <<'EOF'
address 0x7ffd1234abcd (m=64)
bits    000000000000000001111111111111010001001000110|1001010101111|001101
tag     0xfffa246 (t=45)
set     0x12af (s=13)
offset  0xd (b=6)
cache   S=8192 E=12 B=64 C=6291456
EOF

echo "── E1: 사용법 (인자 없음, 주소 없음, 주소 2개)"
fails usage
fails usage -s 4 -E 2 -b 5
fails usage 0x10 0x20 -s 4 -E 2 -b 5

echo "── E2: 옵션 (모르는 옵션, 대소문자, 값 없음, 빠진 옵션)"
fails -x 0x10 -s 4 -E 2 -b 5 -x
fails -S 0x10 -S 4 -E 2 -b 5
fails -e 0x10 -s 4 -e 2 -b 5
fails -b 0x10 -s 4 -E 2 -b
fails -m 0x10 -s 4 -E 2 -b 5 -m
fails -s 0x10 -E 2 -b 5
fails -E 0x10 -s 4 -b 5
fails -b 0x10 -s 4 -E 2
fails '' 0x10

echo "── E3: 값 (정수 아님, 음수, 타입 넘침, 범위 밖, UTF-8 아님)"
fails abc 0x10 -s abc -E 2 -b 5
fails -1 0x10 -s -1 -E 2 -b 5
fails 4294967296 0x10 -s 4294967296 -E 1 -b 1
fails -E 0x10 -s 4 -E 0 -b 5
fails 18446744073709551616 0x10 -s 4 -E 18446744073709551616 -b 5
fails -m 0x10 -s 0 -E 1 -b 0 -m 0
fails 65 0x10 -s 4 -E 2 -b 5 -m 65
fails -s 0x10 -s $'\xff' -E 2 -b 5

echo "── E4: 구성 (s + b = m + 1, 더하다가 넘치는 값)"
fails 13 0x10 -s 8 -E 1 -b 6 -m 13
fails 33 0x10 -s 32 -E 1 -b 33
fails 65 0x10 -s 65 -E 1 -b 0
fails 4294967295 0x10 -s 4294967295 -E 1 -b 1

echo "── E5: 주소 (형식, u64 + 1, UTF-8 아님, 2^m)"
fails 0xZZ 0xZZ -s 4 -E 2 -b 5
fails 0x 0x -s 4 -E 2 -b 5
fails 12a 12a -s 4 -E 2 -b 5
fails 0x10000000000000000 0x10000000000000000 -s 4 -E 2 -b 5
fails 18446744073709551616 18446744073709551616 -s 4 -E 2 -b 5
fails '' '' -s 4 -E 2 -b 5
fails '' $'\xff' -s 4 -E 2 -b 5
fails 0x2000 0x2000 -m 13 -s 3 -E 2 -b 2
fails 0x2 0x2 -m 1 -s 0 -E 1 -b 0

echo "── E6: 출력 실패"
full "$A" -s 4 -E 2 -b 5

if [ -n "${EXT:-}" ]; then
  echo "── 확장: -n (같은 세트 주소, m비트에서 멈춤, u64 넘침에서 멈춤, t = 0)"
  same "$A" -s 4 -E 2 -b 5 -n 5 <<'EOF'
address 0x7ff000a4 (m=64)
bits    0000000000000000000000000000000001111111111100000000000|0101|00100
tag     0x3ff800 (t=55)
set     0x5 (s=4)
offset  0x4 (b=5)
cache   S=16 E=2 B=32 C=1024
same    0x7ff002a4
same    0x7ff004a4
same    0x7ff006a4
same    0x7ff008a4
same    0x7ff00aa4
EOF
  same "$A" -s 4 -E 2 -b 5 -n 0 <<'EOF'
address 0x7ff000a4 (m=64)
bits    0000000000000000000000000000000001111111111100000000000|0101|00100
tag     0x3ff800 (t=55)
set     0x5 (s=4)
offset  0x4 (b=5)
cache   S=16 E=2 B=32 C=1024
EOF
  same 0x1f00 -m 13 -s 3 -E 2 -b 2 -n 10 <<'EOF'
address 0x1f00 (m=13)
bits    11111000|000|00
tag     0xf8 (t=8)
set     0x0 (s=3)
offset  0x0 (b=2)
cache   S=8 E=2 B=4 C=64
same    0x1f20
same    0x1f40
same    0x1f60
same    0x1f80
same    0x1fa0
same    0x1fc0
same    0x1fe0
EOF
  same 0xfffffffffffffc00 -s 4 -E 2 -b 5 -n 3 <<'EOF'
address 0xfffffffffffffc00 (m=64)
bits    1111111111111111111111111111111111111111111111111111110|0000|00000
tag     0x7ffffffffffffe (t=55)
set     0x0 (s=4)
offset  0x0 (b=5)
cache   S=16 E=2 B=32 C=1024
same    0xfffffffffffffe00
EOF
  same 0x5 -s 58 -E 1 -b 6 -n 3 <<'EOF'
address 0x5 (m=64)
bits    |0000000000000000000000000000000000000000000000000000000000|000101
tag     0x0 (t=0)
set     0x0 (s=58)
offset  0x5 (b=6)
cache   S=288230376151711744 E=1 B=64 C=18446744073709551616
EOF
  fails abc "$A" -s 4 -E 2 -b 5 -n abc
  fails -n "$A" -s 4 -E 2 -b 5 -n
fi

echo
echo "OK $ok · FAIL $fail"
[ "$fail" -eq 0 ]
