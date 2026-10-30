#!/usr/bin/env bash
# D3 trace-parse 완료 기준
#  - 정상 케이스: 작은 트레이스 파일을 만들어 표준 출력 전체를 기대값과 비교하고, 빈 표준 에러와 종료 코드 0을 본다
#  - 실제 트레이스: valgrind lackey로 /bin/true의 트레이스를 만들고, grep으로 센 줄 수와 sort로 찾은 최솟값·최댓값과 비교한다
#    작은 트레이스가 모두 통과한 뒤에만 돈다
#  - 오류 케이스: 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄(접두사와 맥락), 패닉 없음 (PRINCIPLES 6-2)
#    해석 오류(E3)는 첫 줄이 "trace-parse: <파일>:<줄 번호>: <이유>"인지 본다
# 사용: ./days/d03-trace-parse/check.sh
#       X=다른/바이너리 ./days/d03-trace-parse/check.sh  (빌드와 단위 테스트 없이 그 바이너리만 검사)
#       EXT=1 ./days/d03-trace-parse/check.sh           (확장 -w도 검사)
#       VALGRIND=경로 ./days/d03-trace-parse/check.sh   (PATH에 없는 valgrind를 쓸 때. 설치하지 않고 푼 것이면 VALGRIND_LIB도 준다)
set -u
if [ -n "${X:-}" ]; then
  [ -x "$X" ] || { echo "X=$X: 실행 파일이 아니다"; exit 1; }
  X=$(realpath "$X")
fi
cd "$(dirname "$0")/../.." || exit 1

unit=
if [ -z "${X:-}" ]; then
  cargo build -q -p trace-parse || exit 1
  X=$PWD/target/debug/trace-parse
  unit=1
fi
VALGRIND=${VALGRIND:-valgrind}
LIMIT=30   # 실행 하나에 주는 시간(초). 넘으면 끊고 FAIL로 센다

T=$(mktemp -d)
D=$T/d     # 트레이스 파일을 두고 프로그램을 실행하는 곳. 그래서 오류 메시지의 경로가 'yi.trace'처럼 짧다
mkdir "$D"
trap 'rm -rf "$T"' EXIT
ok=0
fail=0

# ── 판정 도구 ──────────────────────────────────────────────
pass() { ok=$((ok + 1)); echo "OK   $1"; }
miss() { fail=$((fail + 1)); echo "FAIL $1"; shift; for why in "$@"; do echo "       $why"; done; }

# 케이스 이름: 인자를 셸에 다시 넣을 수 있는 모양으로
label() {
  if [ $# -eq 0 ]; then echo "(인자 없음)"; return; fi
  local s
  s=$(printf '%q ' "$@")
  echo "${s% }"
}

# mk 파일 내용: $D/파일에 내용을 그대로 쓴다. 내용은 $'…'로 주므로 \n, \r, \xff가 그 바이트가 된다
mk() { printf '%s' "$2" > "$D/$1"; }

# 명세의 여섯 줄 요약 (끝 줄 바꿈 없이). 확장의 blocks 줄은 부르는 쪽이 붙인다
summary() { printf 'instr %s\nload %s\nstore %s\nmodify %s\nmin %s\nmax %s' "$@"; }

# $D에서 실행한다. 표준 입력은 /dev/null
got() {
  (cd "$D" && timeout "$LIMIT" "$X" "$@") < /dev/null > "$T/out" 2> "$T/err"
  echo $? > "$T/code"
}

# 패닉이면 위치 줄과 그다음 메시지 줄을 한 줄로 보여 준다
panic_msg() { grep -m 1 -A 1 'panicked' "$T/err" | tr '\n' ' '; }

# same 기대출력 인자...
#   표준 출력이 기대 + 줄 바꿈과 바이트까지 같고, 표준 에러가 비어 있고, 종료 코드가 0인지
#   FAIL이면 줄 바꿈을 |로 바꿔 보여 준다
same() {
  local want=$1 why=() code
  shift
  got "$@"
  printf '%s\n' "$want" > "$T/want"
  if ! cmp -s "$T/want" "$T/out"; then
    why+=("stdout 기대: $(tr '\n' '|' < "$T/want")")
    why+=("       실제: $(head -c 400 "$T/out" | tr '\n' '|')")
  fi
  [ -s "$T/err" ] && why+=("stderr가 비어 있어야 함: '$(grep -m 2 . "$T/err" | tr '\n' ' ')'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  code=$(cat "$T/code")
  [ "$code" = 0 ] || why+=("종료 코드 기대=0 실제=$code")
  [ "$code" = 124 ] && why+=("${LIMIT}초 안에 끝나지 않아 끊음")
  if [ ${#why[@]} -eq 0 ]; then pass "$(label "$@")"; else miss "$(label "$@")" "${why[@]}"; fi
}

# bad 파일 줄번호
#   E3: 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄이 "trace-parse: 파일:줄번호: 이유"(이유는 한 글자 이상), 패닉 없음
#   케이스 이름에 그 줄의 내용을 붙인다 (\r은 글자 그대로 보인다)
bad() {
  local file=$1 line=$2 why=() first code shown
  got "$file"
  first=$(grep -m 1 . "$T/err")
  code=$(cat "$T/code")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [ -s "$T/out" ] && why+=("stdout이 비어 있어야 함: '$(head -n 1 "$T/out")'")
  [[ "$first" == "trace-parse: $file:$line: "?* ]] ||
    why+=("stderr 첫 줄 기대='trace-parse: $file:$line: <이유>' 실제='$first'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  [ "$code" = 124 ] && why+=("${LIMIT}초 안에 끝나지 않아 끊음")
  shown=$(sed -n "${line}p" "$D/$file" | sed 's/\r/\\r/g')
  if [ ${#why[@]} -eq 0 ]; then pass "$file:$line '$shown'"; else miss "$file:$line '$shown'" "${why[@]}"; fi
}

# fails '맥락1|맥락2' 인자...
#   E1·E2: 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄이 "trace-parse: "으로 시작하고 맥락 문자열을 모두 담음, 패닉 없음
fails() {
  local words=() word why=() first code
  IFS='|' read -ra words <<< "$1"
  shift
  got "$@"
  first=$(grep -m 1 . "$T/err")
  code=$(cat "$T/code")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [ -s "$T/out" ] && why+=("stdout이 비어 있어야 함: '$(head -n 1 "$T/out")'")
  [[ "$first" == "trace-parse: "* ]] || why+=("stderr 첫 줄 기대='trace-parse: …' 실제='$first'")
  for word in "${words[@]}"; do
    [[ "$first" == *"$word"* ]] || why+=("stderr 첫 줄에 '$word'가 있어야 함 (PRINCIPLES 2-3): '$first'")
  done
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  [ "$code" = 124 ] && why+=("${LIMIT}초 안에 끝나지 않아 끊음")
  if [ ${#why[@]} -eq 0 ]; then pass "오류 $(label "$@")"; else miss "오류 $(label "$@")" "${why[@]}"; fi
}

# full 인자...: E4 — 표준 출력이 /dev/full일 때 종료 코드 1, stderr가 "trace-parse:"로 시작, 패닉 없음
full() {
  local why=() code first
  (cd "$D" && timeout "$LIMIT" "$X" "$@") < /dev/null > /dev/full 2> "$T/err"
  code=$?
  first=$(grep -m 1 . "$T/err")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [[ "$first" == "trace-parse:"* ]] || why+=("stderr 기대='trace-parse:…' 실제='$first'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  if [ ${#why[@]} -eq 0 ]; then pass "> /dev/full: $(label "$@")"; else miss "> /dev/full: $(label "$@")" "${why[@]}"; fi
}

echo "── 단위 테스트: trace 모듈"
if [ -n "$unit" ]; then
  f=days/d03-trace-parse/src/trace.rs
  if [ -f "$f" ]; then
    pass "src/trace.rs 있음"
  else
    miss "src/trace.rs 있음" "Op, Access, parse_line은 src/trace.rs에 둔다 (명세 제약)"
  fi
  cargo test -q -p trace-parse -- trace:: > "$T/test.out" 2>&1
  code=$?
  n=$(grep -o '[0-9]* passed' "$T/test.out" | awk '{ s += $1 } END { print s + 0 }')
  if [ "$code" = 0 ] && [ "$n" -ge 4 ]; then
    pass "cargo test: trace 모듈 테스트 ${n}개 통과"
  else
    why=("종료 코드=$code, 통과=${n}개 (cargo test -p trace-parse로 확인)")
    grep -q 'panicked' "$T/test.out" && why+=("$(grep -m 1 -A 1 'panicked' "$T/test.out" | tr '\n' ' ')")
    grep -q '^error' "$T/test.out" && why+=("$(grep -m 1 '^error' "$T/test.out")")
    miss "cargo test: trace 모듈 테스트 4개 이상 통과" "${why[@]}"
  fi
  # #[cfg(test)] 아래에 #[test]가 4개 이상이고, parse_line을 부르는 줄이 있는지
  tests=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c '#\[test\]')
  calls=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c 'parse_line(')
  if [ "$tests" -ge 4 ] && [ "$calls" -ge 1 ]; then
    pass "테스트 ${tests}개가 parse_line을 검사함"
  else
    miss "테스트 4개 이상이 parse_line을 검사함" "#[test] ${tests}개, parse_line을 부르는 줄 ${calls}개 (I 줄, 데이터 줄, 건너뛸 줄, 잘못된 줄)"
  fi
else
  echo "SKIP (X를 지정하면 건너뜀)"
fi

before=$fail

echo "── F2~F5: 형식 (Cache Lab 문서의 예, lackey, yi.trace, 공백, 줄 끝)"
mk writeup.trace $'I 0400d7d4,8\n M 0421c7f0,4\n L 04f6b868,8\n S 7ff0005c8,8\n'
same "$(summary 1 1 1 1 0x421c7f0 0x7ff0005c8)" writeup.trace
mk lackey.trace $'==469889== Lackey, an example Valgrind tool\n==469889== Using Valgrind-3.22.0 and LibVEX; rerun with -h for copyright info\n==469889== Command: /bin/true\n==469889== \nI  0401f540,3\nI  0401f543,5\n S 1fff000028,8\nI  04020211,7\n M 04038e06,1\nI  048dfac0,1\n L 1ffefffea8,8\n==469889== \n==469889== Counted 0 calls to main()\n==469889== Exit code:       0\n'
same "$(summary 4 1 1 1 0x4038e06 0x1fff000028)" lackey.trace
mk yi.trace $' L 10,1\n M 20,1\n L 22,1\n S 18,1\n L 110,1\n L 210,1\n M 12,1\n'
same "$(summary 0 4 1 2 0x10 0x210)" yi.trace
mk spaces.trace $'L 10,1\n I  400,3\n   S    20,4\n M 30,8   \n'
same "$(summary 1 1 1 1 0x10 0x30)" spaces.trace
mk crlf.trace $' L 10,1\r\n S 20,1\r\n'
same "$(summary 0 1 1 0 0x10 0x20)" crlf.trace
mk nonl.trace $' L 10,1\n S 20,1'
same "$(summary 0 1 1 0 0x10 0x20)" nonl.trace
mk order.trace $' L 500,8\n S 100,8\nI  50,1\n M 900,8\nI  ffffffff,1\n L 300,8\n'
same "$(summary 2 2 1 1 0x100 0x900)" order.trace

echo "── 경계: 데이터 접근 0개·1개 (빈 파일, 건너뛸 줄만, I 줄만, 한 줄)"
mk empty.trace ''
same "$(summary 0 0 0 0 - -)" empty.trace
mk skip.trace $'==1== a\n\n   \n ==2== indented\n==\n'
same "$(summary 0 0 0 0 - -)" skip.trace
mk instr.trace $'I  0401f540,3\nI  ffffffffffffffff,15\n'
same "$(summary 2 0 0 0 - -)" instr.trace
mk one.trace $' S 7ff0005c8,8\n'
same "$(summary 0 0 1 0 0x7ff0005c8 0x7ff0005c8)" one.trace

echo "── 경계: 주소 0·2^64-1·앞의 0·대문자, 크기 1·2^64-1"
mk zero.trace $' L 0,1\n'
same "$(summary 0 1 0 0 0x0 0x0)" zero.trace
mk top.trace $' S ffffffffffffffff,8\n L 10,1\n'
same "$(summary 0 1 1 0 0x10 0xffffffffffffffff)" top.trace
mk pad.trace $' L 0000000000000000010,8\n'
same "$(summary 0 1 0 0 0x10 0x10)" pad.trace
mk upper.trace $' M ABCDEF,4\n L 7FF0005C8,8\n'
same "$(summary 0 1 0 1 0xabcdef 0x7ff0005c8)" upper.trace
mk size.trace $' L 10,1\n S 20,18446744073709551615\n'
same "$(summary 0 1 1 0 0x10 0x20)" size.trace

echo "── 실제 트레이스: valgrind --tool=lackey --trace-mem=yes /bin/true"
true_want=
if [ "$fail" -gt "$before" ]; then
  miss "실제 트레이스" "위의 작은 트레이스가 모두 통과하면 실제 트레이스로 넘어간다"
elif ! command -v "$VALGRIND" > /dev/null 2>&1; then
  miss "valgrind 있음" "오늘은 lackey 트레이스를 쓴다: sudo apt install valgrind"
elif ! "$VALGRIND" --tool=lackey --trace-mem=yes --log-file="$D/true.trace" /bin/true < /dev/null > /dev/null 2>&1; then
  miss "lackey로 /bin/true의 트레이스 만들기" "$VALGRIND --tool=lackey --trace-mem=yes --log-file=… /bin/true가 실패함"
else
  f=$D/true.trace
  # 데이터 줄의 주소를 앞의 0을 떼고 (자릿수, 글자) 순으로 정렬하면 수의 크기 순이 된다
  grep -E '^ [LSM] ' "$f" | cut -d' ' -f3 | cut -d, -f1 | sed 's/^0*//; s/^$/0/' |
    awk '{ print length($0), $0 }' | LC_ALL=C sort -k1,1n -k2,2 | cut -d' ' -f2 > "$T/addrs"
  true_want=$(summary "$(grep -c '^I ' "$f")" "$(grep -c '^ L ' "$f")" "$(grep -c '^ S ' "$f")" \
    "$(grep -c '^ M ' "$f")" "0x$(head -n 1 "$T/addrs")" "0x$(tail -n 1 "$T/addrs")")
  before=$fail
  same "$true_want" true.trace
  [ "$fail" -gt "$before" ] && true_want=
fi

echo "── E1: 사용법"
fails usage
fails usage yi.trace writeup.trace
fails usage -x yi.trace
fails usage yi.trace -x
fails usage -
fails usage -- yi.trace

echo "── E2: 읽기"
fails nofile.trace nofile.trace
mkdir "$D/traces.d"
fails traces.d traces.d
mk locked.trace $' L 10,1\n'
chmod 000 "$D/locked.trace"
if [ "$(id -u)" -ne 0 ]; then
  fails locked.trace locked.trace
else
  echo "SKIP locked.trace (root는 권한과 상관없이 읽는다)"
fi
mk latin1.trace $' L 10,1\n\xff\xfe\n'
fails latin1.trace latin1.trace

echo "── E3: 해석 (가장 앞의 잘못된 줄, 줄 번호는 1부터)"
mk e-op.trace $' X 10,1\n'
bad e-op.trace 1
mk e-lower.trace $' l 10,1\n'
bad e-lower.trace 1
mk e-op2.trace $' LS 10,1\n'
bad e-op2.trace 1
mk e-oponly.trace $' L\n'
bad e-oponly.trace 1
mk e-nospace.trace $' L10,1\n'
bad e-nospace.trace 1
mk e-nocomma.trace $' L 10\n'
bad e-nocomma.trace 1
mk e-noaddr.trace $' L ,1\n'
bad e-noaddr.trace 1
mk e-nosize.trace $' L 10,\n'
bad e-nosize.trace 1
mk e-0x.trace $' L 0x10,1\n'
bad e-0x.trace 1
mk e-nothex.trace $' L 1g,1\n'
bad e-nothex.trace 1
mk e-addrneg.trace $' L -10,1\n'
bad e-addrneg.trace 1
mk e-addrbig.trace $' L 10000000000000000,1\n'
bad e-addrbig.trace 1
mk e-size0.trace $' L 10,0\n'
bad e-size0.trace 1
mk e-sizehex.trace $' L 10,a\n'
bad e-sizehex.trace 1
mk e-sizeneg.trace $' L 10,-1\n'
bad e-sizeneg.trace 1
mk e-sizebig.trace $' L 10,18446744073709551616\n'
bad e-sizebig.trace 1
mk e-comma2.trace $' L 10,1,2\n'
bad e-comma2.trace 1
mk e-gap.trace $' L 10, 1\n'
bad e-gap.trace 1
mk e-extra.trace $' L 10,1 x\n'
bad e-extra.trace 1
mk e-instr.trace $'I  zz,3\n'
bad e-instr.trace 1
mk e-lineno.trace $'==1== header\n\n L 10,1\nI  400,3\n S 10 1\n L 20,1\n'
bad e-lineno.trace 5
mk e-first.trace $' L 10,1\n Q 20,1\n L 30,1\n Z 40,1\n'
bad e-first.trace 2
mk e-last.trace $' L 10,1\n L 20,1\n S zz,1'
bad e-last.trace 3
mk e-crlf.trace $' L 10,1\r\n Q 20,1\r\n'
bad e-crlf.trace 2

echo "── E4: 출력 실패"
full yi.trace

if [ -n "${EXT:-}" ]; then
  echo "── 확장: -w (서로 다른 64바이트 블록 수, 시작 주소만)"
  same "$(summary 0 4 1 2 0x10 0x210)"$'\n'"blocks 3" -w yi.trace
  same "$(summary 1 1 1 1 0x421c7f0 0x7ff0005c8)"$'\n'"blocks 3" writeup.trace -w
  mk edge.trace $' L 3f,1\n L 40,1\n L 7f,8\n L 80,1\n'
  same "$(summary 0 4 0 0 0x3f 0x80)"$'\n'"blocks 3" -w edge.trace
  mk straddle.trace $' L 3c,8\n S 7c,8\n'
  same "$(summary 0 1 1 0 0x3c 0x7c)"$'\n'"blocks 2" -w straddle.trace
  same "$(summary 0 1 1 0 0x10 0xffffffffffffffff)"$'\n'"blocks 2" -w top.trace
  same "$(summary 0 0 0 0 - -)"$'\n'"blocks 0" -w empty.trace
  same "$(summary 2 0 0 0 - -)"$'\n'"blocks 0" -w instr.trace
  fails usage -w
  fails usage -w yi.trace writeup.trace
  fails usage -w -x yi.trace
  if [ -z "$true_want" ]; then
    echo "SKIP -w true.trace (실제 트레이스 검사를 통과한 뒤에 본다)"
  elif ! command -v gawk > /dev/null 2>&1; then
    echo "SKIP -w true.trace (블록 수를 셀 gawk가 없다)"
  else
    blocks=$(gawk '$1 ~ /^[LSM]$/ { split($2, a, ","); seen[int(strtonum("0x" a[1]) / 64)] } END { print length(seen) }' "$D/true.trace")
    same "$true_want"$'\n'"blocks $blocks" -w true.trace
  fi
fi

echo
echo "OK $ok · FAIL $fail"
[ "$fail" -eq 0 ]
