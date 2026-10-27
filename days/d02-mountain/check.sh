#!/usr/bin/env bash
# D2 mountain 완료 기준
# 처리량은 실행마다 달라서 숫자를 그대로 비교할 수 없다. 그래서 세 가지를 본다.
#  - 정상 케이스: CSV 모양(머리줄, 행 수, 크기 열, 양의 정수), 빈 표준 에러, 종료 코드 0
#  - 능선: 기본 실행(256M, stride 16)에 시간 지역성과 공간 지역성이 보이는지. 문턱은 참조 구현으로 재서 넉넉하게 잡았다
#  - 오류 케이스: 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄(접두사와 맥락), 패닉 없음 (PRINCIPLES 6-2)
# 측정하는 도구라서 --release로 빌드한다 (CLAUDE.md 규칙 5).
# 사용: ./days/d02-mountain/check.sh
#       X=다른/바이너리 ./days/d02-mountain/check.sh  (빌드와 단위 테스트 없이 그 바이너리만 검사)
#       EXT=1 ./days/d02-mountain/check.sh           (확장 -u도 검사)
set -u
if [ -n "${X:-}" ]; then
  [ -x "$X" ] || { echo "X=$X: 실행 파일이 아니다"; exit 1; }
  X=$(realpath "$X")
fi
cd "$(dirname "$0")/../.." || exit 1

# 능선 문턱 (기본 실행의 CSV에서). 참조 구현은 2026-10-22 이 머신에서 시간 6.98~7.23배, 공간 6.21~6.64배, 6.8~7.2초
MIN_TEMPORAL=3   # s8 열: 16384 행 ÷ 268435456 행 (L1 대 DRAM)
MIN_SPATIAL=3    # 268435456 행: s1 ÷ s16 (DRAM에서 stride 1 대 16)
MAX_SECONDS=20   # 기본 실행 한 번에 걸리는 시간의 상한. 실행 하나는 그 두 배에서 끊는다(timeout)

unit=
if [ -z "${X:-}" ]; then
  cargo build -q --release -p mountain || exit 1
  X=target/release/mountain
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

# 표준 입력은 /dev/null로 주고 실행한다. 걸린 시간(초)은 $T/secs에 남긴다
got() {
  local t0=$EPOCHREALTIME
  timeout $((MAX_SECONDS * 2)) "$X" "$@" < /dev/null > "$T/out" 2> "$T/err"
  echo $? > "$T/code"
  awk -v a="$t0" -v b="$EPOCHREALTIME" 'BEGIN { printf "%.1f\n", b - a }' > "$T/secs"
}

# 패닉이면 위치 줄과 그다음 메시지 줄을 한 줄로 보여 준다 (패닉 출력은 빈 줄로 시작한다)
panic_msg() { grep -m 1 -A 1 'panicked' "$T/err" | tr '\n' ' '; }

# csv_problems 행수 stride수 < CSV
#   명세의 CSV 모양과 다른 점을 한 줄에 하나씩 쓴다 (최대 6줄). 맞으면 아무것도 쓰지 않는다
csv_problems() {
  awk -F, -v rows="$1" -v k="$2" '
    function say(msg) { if (++n <= 6) print msg }
    NR == 1 {
      want = "size"
      for (j = 1; j <= k; j++) want = want ",s" j
      if ($0 != want) say("머리줄 기대=\"" want "\" 실제=\"" $0 "\"")
      next
    }
    {
      size = sprintf("%d", 16384 * 2 ^ (NR - 2))
      if ($1 != size) say((NR) "번째 줄: 크기 기대=" size " 실제=\"" $1 "\"")
      if (NF != k + 1) say((NR) "번째 줄: 칸 수 기대=" (k + 1) " 실제=" NF)
      for (j = 2; j <= NF; j++)
        if ($j !~ /^[1-9][0-9]*$/) { say((NR) "번째 줄 " j "번째 칸: 양의 정수(MB/s)가 아님 \"" $j "\""); break }
    }
    END {
      if (NR == 0) say("표준 출력이 비어 있음")
      else if (NR - 1 != rows) say("행 수(머리줄 제외) 기대=" rows " 실제=" (NR - 1))
    }'
}

# shape 행수 stride수 인자...
#   CSV 모양이 맞고, 표준 에러가 비어 있고, 종료 코드가 0인지. 표준 출력은 $T/out에 남는다
shape() {
  local rows=$1 k=$2 why=() line
  shift 2
  got "$@"
  while IFS= read -r line; do why+=("$line"); done < <(csv_problems "$rows" "$k" < "$T/out")
  [ -s "$T/err" ] && why+=("stderr가 비어 있어야 함: '$(grep -v '^$' "$T/err" | head -n 2 | tr '\n' ' ')'")
  [ "$(cat "$T/code")" = 0 ] || why+=("종료 코드 기대=0 실제=$(cat "$T/code")")
  [ "$(cat "$T/code")" = 124 ] && why+=("$((MAX_SECONDS * 2))초 안에 끝나지 않아 끊음. 재는 반복이 지워졌는지(black_box, 함정 2) 확인")
  local name
  name="$(label "$@") → ${rows}행 × s1..s${k}"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

# fails '맥락1|맥락2' 인자...
#   종료 코드 1, 표준 출력 비어 있음, 표준 에러 첫 줄이 "mountain: "으로 시작하고 맥락 문자열을 모두 담음, 패닉 없음
#   맥락이 ''이면 담는지는 보지 않는다
fails() {
  local words=() word why=() first
  IFS='|' read -ra words <<< "$1"
  shift
  got "$@"
  first=$(grep -m 1 . "$T/err")
  [ "$(cat "$T/code")" = 1 ] || why+=("종료 코드 기대=1 실제=$(cat "$T/code")")
  [ -s "$T/out" ] && why+=("stdout이 비어 있어야 함: '$(head -n 1 "$T/out")'")
  [[ "$first" == "mountain: "* ]] || why+=("stderr 첫 줄 기대='mountain: …' 실제='$first'")
  for word in "${words[@]}"; do
    [[ "$first" == *"$word"* ]] || why+=("stderr 첫 줄에 '$word'가 있어야 함 (PRINCIPLES 2-3): '$first'")
  done
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  [ "$(cat "$T/code")" = 124 ] && why+=("$((MAX_SECONDS * 2))초 안에 끝나지 않아 끊음. 잘못된 인자는 재기 전에 거른다")
  local name
  name="오류 $(label "$@")"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

# full 인자...: E4 — 표준 출력이 /dev/full일 때 종료 코드 1, stderr가 "mountain:"으로 시작, 패닉 없음
full() {
  local why=() code first
  timeout $((MAX_SECONDS * 2)) "$X" "$@" < /dev/null > /dev/full 2> "$T/err"; code=$?
  first=$(grep -m 1 . "$T/err")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [[ "$first" == "mountain:"* ]] || why+=("stderr 기대='mountain:…' 실제='$first'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  local name
  name="> /dev/full: $(label "$@")"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

echo "── 단위 테스트: measure 모듈"
if [ -n "$unit" ]; then
  f=days/d02-mountain/src/measure.rs
  if [ -f "$f" ]; then
    pass "src/measure.rs 있음"
  else
    miss "src/measure.rs 있음" "read_stride와 throughput은 src/measure.rs에 둔다 (명세 제약)"
  fi
  cargo test -q -p mountain -- measure:: > "$T/test.out" 2>&1
  code=$?
  n=$(grep -o '[0-9]* passed' "$T/test.out" | awk '{ s += $1 } END { print s + 0 }')
  if [ "$code" = 0 ] && [ "$n" -ge 3 ]; then
    pass "cargo test: measure 모듈 테스트 ${n}개 통과 (debug 빌드)"
  else
    why=("종료 코드=$code, 통과=${n}개 (cargo test -p mountain으로 확인)")
    grep -q 'panicked' "$T/test.out" && why+=("$(grep -m 1 -A 1 'panicked' "$T/test.out" | tr '\n' ' ')")
    miss "cargo test: measure 모듈 테스트 3개 이상 통과" "${why[@]}"
  fi
  # #[cfg(test)] 아래에 #[test]가 3개 이상이고, read_stride를 부르는 줄이 있는지
  tests=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c '#\[test\]')
  calls=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c 'read_stride(')
  if [ "$tests" -ge 3 ] && [ "$calls" -ge 1 ]; then
    pass "테스트 ${tests}개가 read_stride를 검사함"
  else
    miss "테스트 3개 이상이 read_stride를 검사함" "#[test] ${tests}개, read_stride를 부르는 줄 ${calls}개 (stride 1, 길이를 나누지 않는 stride, 넘침)"
  fi
else
  echo "SKIP (X를 지정하면 건너뜀)"
fi

echo "── F1·F5: 작은 실행의 CSV 모양 (최소 크기, 접미사, 순서, 중복 옵션, 최대 stride)"
shape 1 1 -M 16K -S 1
shape 1 1 -M 16384 -S 1
shape 1 1 -S 1 -M 16K
shape 2 64 -M 32K -S 64
shape 7 4 -M 1M -S 4
shape 7 4 -M 1024K -S 4
shape 7 4 -M 1048576 -S 4
shape 1 2 -M 1M -S 4 -M 16K -S 2
shape 3 16 -M 64K

echo "── F2~F5: 기본 실행 (-M 256M -S 16)"
before=$fail
shape 15 16
secs=$(cat "$T/secs")
cp "$T/out" "$T/mountain.csv"
if [ "$(cat "$T/code")" = 124 ]; then
  miss "기본 실행 시간 ≤ ${MAX_SECONDS}초" "$((MAX_SECONDS * 2))초에 끊음. 재는 반복이 지워졌는지(black_box, 함정 2) 확인"
elif [ "$fail" -gt "$before" ]; then
  miss "기본 실행 시간 ≤ ${MAX_SECONDS}초" "기본 실행이 위에서 실패해서 판정하지 않음"
elif awk -v s="$secs" -v max="$MAX_SECONDS" 'BEGIN { exit !(s <= max) }'; then
  pass "기본 실행 시간 ${secs}초 ≤ ${MAX_SECONDS}초"
else
  miss "기본 실행 시간 ≤ ${MAX_SECONDS}초" "실제 ${secs}초. 한 칸을 재는 시간이 명세 F4(10ms 이상이 될 때까지 두 배씩)보다 긴지 확인"
fi

# ridge 이름 식: CSV에서 두 칸의 비를 구해 문턱과 비교한다
ridge() {
  local name=$1 min=$2 r1=$3 c1=$4 r2=$5 c2=$6 hint=$7 got_ratio
  got_ratio=$(awk -F, -v r1="$r1" -v c1="$c1" -v r2="$r2" -v c2="$c2" '
    $1 == r1 { a = $(c1 + 1) } $1 == r2 { b = $(c2 + 1) }
    END { if (a > 0 && b > 0) printf "%.2f", a / b; else print "-" }' "$T/mountain.csv")
  if [ "$got_ratio" = - ]; then
    miss "$name: ${min}배 이상이어야 함" "CSV에서 ${r1}행 s${c1}, ${r2}행 s${c2} 칸을 찾지 못해 비를 구할 수 없음 (위의 기본 실행 FAIL부터 고친다)"
  elif awk -v g="$got_ratio" -v m="$min" 'BEGIN { exit !(g >= m) }'; then
    pass "$name: ${got_ratio}배 ≥ ${min}배"
  else
    miss "$name: ${min}배 이상이어야 함" "실제 ${got_ratio}배" "$hint"
  fi
}
echo "── 능선: 기본 실행의 CSV에서"
ridge "시간 지역성 (s8: 16KB ÷ 256MB)" "$MIN_TEMPORAL" 16384 8 268435456 8 \
  "L1과 DRAM이 구별되지 않는다. 배열에 값을 썼는지(함정 1), black_box를 썼는지(함정 2) 확인"
ridge "공간 지역성 (256MB: s1 ÷ s16)" "$MIN_SPATIAL" 268435456 1 268435456 16 \
  "stride가 커져도 처리량이 그대로다. 읽은 바이트를 stride에 맞게 셌는지(F4) 확인"

echo "── E1~E3: 오류"
fails usage foo
fails usage -M 1M foo
fails usage 16K
fails "-x" -x
fails "-m" -m 1M
fails "-s" -s 4
fails "-M" -M
fails "-S" -S
fails "-S" -M 1M -S
fails "-M" -M ''
fails "-M|abc" -M abc
fails "-M|0" -M 0
fails "-M|1" -M 1
fails "-M|8K" -M 8K
fails "-M|16383" -M 16383
fails "-M|1000" -M 1000
fails "-M|24K" -M 24K
fails "-M|512M" -M 512M
fails "-M|268435457" -M 268435457
fails "-M|1G" -M 1G
fails "-M|1k" -M 1k
fails "-M|1m" -M 1m
fails "-M|K" -M K
fails "-M|16K16" -M 16K16
fails "-M|1.5M" -M 1.5M
fails "-M|-1" -M -1
fails "-M|18446744073709551616" -M 18446744073709551616
fails "-M|18014398509481984K" -M 18014398509481984K
fails "-M|17592186044416M" -M 17592186044416M
fails "-S|0" -M 16K -S 0
fails "-S|65" -M 16K -S 65
fails "-S|-1" -M 16K -S -1
fails "-S|abc" -M 16K -S abc
fails "-S|4K" -M 16K -S 4K
fails "-S|18446744073709551617" -M 16K -S 18446744073709551617
fails "-M" -M $'\xff'
fails "-S" -M 16K -S $'\xff'
fails '' $'-\xff'

echo "── E4: 출력 실패"
full -M 16K -S 1

if [ -n "${EXT:-}" ]; then
  echo "── 확장: -u (4×4 언롤링)"
  shape 7 4 -u -M 1M -S 4
  shape 7 4 -M 1M -u -S 4
  shape 1 3 -M 16K -S 3 -u
fi

echo
echo "OK $ok · FAIL $fail"
[ "$fail" -eq 0 ]
