#!/usr/bin/env bash
# D4 lru-set 완료 기준
#  - 단위 테스트: set 모듈의 #[test] 3개 이상이 통과하고, 테스트가 access와 contains를 부른다
#  - 정상 케이스: 표준 출력 전체를 기대값과 비교하고, 빈 표준 에러와 종료 코드 0을 본다
#    짧은 태그 열은 참조 구현으로 확인한 기대값을 적어 두고, 긴 태그 열은 LRU의 성질로 기대값을 만든다
#  - 오류 케이스: 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄(접두사와 맥락), 패닉 없음 (PRINCIPLES 6-2)
# 사용: ./days/d04-lru-set/check.sh
#       X=다른/바이너리 ./days/d04-lru-set/check.sh  (빌드와 단위 테스트 없이 그 바이너리만 검사)
#       EXT=1 ./days/d04-lru-set/check.sh           (확장 -p도 검사)
set -u
if [ -n "${X:-}" ]; then
  [ -x "$X" ] || { echo "X=$X: 실행 파일이 아니다"; exit 1; }
  X=$(realpath "$X")
fi
cd "$(dirname "$0")/../.." || exit 1

unit=
if [ -z "${X:-}" ]; then
  cargo build -q -p lru-set || exit 1
  X=$PWD/target/debug/lru-set
  unit=1
fi
LIMIT=30   # 실행 하나에 주는 시간(초). 넘으면 끊고 FAIL로 센다

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
ok=0
fail=0

# ── 판정 도구 ──────────────────────────────────────────────
pass() { ok=$((ok + 1)); echo "OK   $1"; }
miss() { fail=$((fail + 1)); echo "FAIL $1"; shift; for why in "$@"; do echo "       $why"; done; }

# 케이스 이름: 인자를 셸에 다시 넣을 수 있는 모양으로. 인자가 많으면 앞의 12개와 개수만
label() {
  if [ $# -eq 0 ]; then echo "(인자 없음)"; return; fi
  local s
  if [ $# -gt 14 ]; then
    s=$(printf '%q ' "${@:1:12}")
    printf '%s\n' "${s% } … (인자 $#개)"
  else
    s=$(printf '%q ' "$@")
    printf '%s\n' "${s% }"   # echo는 '-E'를 제 옵션으로 먹는다
  fi
}

# 표준 입력은 /dev/null
got() {
  timeout "$LIMIT" "$X" "$@" < /dev/null > "$T/out" 2> "$T/err"
  echo $? > "$T/code"
}

# 패닉이면 위치 줄과 그다음 메시지 줄을 한 줄로 보여 준다
panic_msg() { grep -m 1 -A 1 'panicked' "$T/err" | tr '\n' ' '; }

# same 기대출력 인자...
#   표준 출력이 기대 + 줄 바꿈과 바이트까지 같고, 표준 에러가 비어 있고, 종료 코드가 0인지
#   FAIL이면 처음 다른 곳을 diff로 보여 준다 (<는 기대, >는 실제)
same() {
  local want=$1 why=() code d
  shift
  got "$@"
  printf '%s\n' "$want" > "$T/want"
  if ! cmp -s "$T/want" "$T/out"; then
    why+=("stdout이 기대와 다름. 처음 다른 곳 (diff 기대 실제):")
    while IFS= read -r d; do why+=("  $d"); done < <(diff "$T/want" "$T/out" | head -n 6)
  fi
  [ -s "$T/err" ] && why+=("stderr가 비어 있어야 함: '$(grep -m 2 . "$T/err" | tr '\n' ' ')'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  code=$(cat "$T/code")
  [ "$code" = 0 ] || why+=("종료 코드 기대=0 실제=$code")
  [ "$code" = 124 ] && why+=("${LIMIT}초 안에 끝나지 않아 끊음")
  if [ ${#why[@]} -eq 0 ]; then pass "$(label "$@")"; else miss "$(label "$@")" "${why[@]}"; fi
}

# fails '맥락1|맥락2|!없어야 할 말' 인자...
#   E1~E3: 종료 코드 1, 빈 표준 출력, 표준 에러 첫 줄이 "lru-set: "으로 시작하고 맥락을 모두 담음, 패닉 없음
#   !로 시작하는 말은 첫 줄에 없어야 한다. 가장 앞의 잘못된 태그만 보고하는지(!qq),
#   빈 값이나 UTF-8이 아닌 값을 사용법 오류로 뭉뚱그리지 않는지(!usage) 볼 때 쓴다
fails() {
  local words=() word why=() first code
  IFS='|' read -ra words <<< "$1"
  shift
  got "$@"
  first=$(grep -m 1 . "$T/err")
  code=$(cat "$T/code")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [ -s "$T/out" ] && why+=("stdout이 비어 있어야 함: '$(head -n 1 "$T/out")'")
  [[ "$first" == "lru-set: "* ]] || why+=("stderr 첫 줄 기대='lru-set: …' 실제='$first'")
  for word in "${words[@]}"; do
    if [[ "$word" == '!'* ]]; then
      [[ "$first" == *"${word#!}"* ]] && why+=("stderr 첫 줄에 '${word#!}'가 없어야 함: '$first'")
    else
      [[ "$first" == *"$word"* ]] || why+=("stderr 첫 줄에 '$word'가 있어야 함 (PRINCIPLES 2-3): '$first'")
    fi
  done
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  [ "$code" = 124 ] && why+=("${LIMIT}초 안에 끝나지 않아 끊음")
  if [ ${#why[@]} -eq 0 ]; then pass "오류 $(label "$@")"; else miss "오류 $(label "$@")" "${why[@]}"; fi
}

# full 인자...: E4 — 표준 출력이 /dev/full일 때 종료 코드 1, stderr가 "lru-set:"으로 시작, 패닉 없음
full() {
  local why=() code first
  timeout "$LIMIT" "$X" "$@" < /dev/null > /dev/full 2> "$T/err"
  code=$?
  first=$(grep -m 1 . "$T/err")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [[ "$first" == "lru-set:"* ]] || why+=("stderr 기대='lru-set:…' 실제='$first'")
  grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
  [ "$code" = 124 ] && why+=("${LIMIT}초 안에 끝나지 않아 끊음")
  if [ ${#why[@]} -eq 0 ]; then pass "> /dev/full: $(label "$@")"; else miss "> /dev/full: $(label "$@")" "${why[@]}"; fi
}

# ── 긴 태그 열의 기대 출력: LRU의 성질로 만든다 ──────────────
# distinct E N: 서로 다른 태그 0..N−1을 차례로. 처음 E개는 빈 줄에 들어가고,
#   그 뒤 i번째(i ≥ E)는 i−E번째를 쫓아낸다 (그때 세트에는 바로 앞의 E개가 있고, 그중 가장 오래전에 쓴 것이 i−E번째다)
distinct_want() {
  local e=$1 n=$2 i
  for ((i = 0; i < n; i++)); do
    if ((i < e)); then echo "$i miss"; else echo "$i miss eviction $((i - e))"; fi
  done
  echo "hits:0 misses:$n evictions:$((n > e ? n - e : 0))"
}

# repeat E K: 태그 0..E−1을 K바퀴. 첫 바퀴가 빈 줄을 채우고, 그 뒤는 모두 세트에 있다
repeat_tags() { local r; for ((r = 0; r < $2; r++)); do seq 0 $(($1 - 1)); done; }
repeat_want() {
  local e=$1 k=$2 r i
  for ((r = 0; r < k; r++)); do
    for ((i = 0; i < e; i++)); do
      if ((r == 0)); then echo "$i miss"; else echo "$i hit"; fi
    done
  done
  echo "hits:$(((k - 1) * e)) misses:$e evictions:0"
}

# cycle E K: 태그 0..E(E+1개)를 K바퀴. j번째 접근(j ≥ E) 때 세트에는 바로 앞의 E개가 있다
cycle_tags() { local r; for ((r = 0; r < $2; r++)); do seq 0 "$1"; done; }
cycle_want() {
  local e=$1 k=$2 n j
  n=$(((e + 1) * k))
  for ((j = 0; j < n; j++)); do
    if ((j < e)); then echo "$((j % (e + 1))) miss"
    else echo "$((j % (e + 1))) miss eviction $(((j - e) % (e + 1)))"; fi
  done
  echo "hits:0 misses:$n evictions:$((n - e))"
}

# hot E K (E ≥ 2): 태그 1과 새 태그 100, 101, …, 100+K−1을 번갈아. 1은 늘 방금 쓴 줄이라 쫓겨나지 않고,
#   새 태그는 빈 줄이 없으면 가장 먼저 들어온 새 태그를 쫓아낸다
hot_tags() { local i; for ((i = 0; i < $1; i++)); do echo 1 $((100 + i)); done; }
hot_want() {
  local e=$1 k=$2 i
  echo "1 miss"
  for ((i = 0; i < k; i++)); do
    if ((i > 0)); then echo "1 hit"; fi
    if ((i < e - 1)); then echo "$((100 + i)) miss"
    else echo "$((100 + i)) miss eviction $((100 + i - e + 1))"; fi
  done
  echo "hits:$((k - 1)) misses:$((k + 1)) evictions:$((k > e - 1 ? k - e + 1 : 0))"
}

echo "── 단위 테스트: set 모듈"
if [ -n "$unit" ]; then
  f=days/d04-lru-set/src/set.rs
  if [ -f "$f" ]; then
    pass "src/set.rs 있음"
  else
    miss "src/set.rs 있음" "Outcome, CacheSet, Line은 src/set.rs에 둔다 (명세 제약)"
  fi
  cargo test -q -p lru-set -- set:: > "$T/test.out" 2>&1
  code=$?
  n=$(grep -o '[0-9]* passed' "$T/test.out" | awk '{ s += $1 } END { print s + 0 }')
  if [ "$code" = 0 ] && [ "$n" -ge 3 ]; then
    pass "cargo test: set 모듈 테스트 ${n}개 통과"
  else
    why=("종료 코드=$code, 통과=${n}개 (cargo test -p lru-set로 확인)")
    grep -q 'panicked' "$T/test.out" && why+=("$(grep -m 1 -A 1 'panicked' "$T/test.out" | tr '\n' ' ')")
    grep -q '^error' "$T/test.out" && why+=("$(grep -m 1 '^error' "$T/test.out")")
    miss "cargo test: set 모듈 테스트 3개 이상 통과" "${why[@]}"
  fi
  # #[cfg(test)] 아래에 #[test]가 3개 이상이고, access와 contains를 부르는 줄이 있는지
  tests=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c '#\[test\]')
  calls=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c '\.access(')
  peeks=$(sed -n '/#\[cfg(test)\]/,$p' "$f" 2>/dev/null | grep -c '\.contains(')
  if [ "$tests" -ge 3 ] && [ "$calls" -ge 1 ] && [ "$peeks" -ge 1 ]; then
    pass "테스트 ${tests}개가 access와 contains를 검사함"
  else
    miss "테스트 3개 이상이 access와 contains를 검사함" "#[test] ${tests}개, .access( ${calls}줄, .contains( ${peeks}줄 (E = 1 충돌, E = 2 LRU 순서와 contains, cold miss)"
  fi
else
  echo "SKIP (X를 지정하면 건너뜀)"
fi

echo "── F3·F4: 명세의 예와 LRU 순서"
same $'1 miss\n2 miss\n1 hit\n3 miss eviction 2\n2 miss eviction 1\nhits:1 misses:4 evictions:2' -E 2 1 2 1 3 2
same $'0 miss\n1 miss eviction 0\n0 miss eviction 1\n1 miss eviction 0\nhits:0 misses:4 evictions:3' -E 1 0 1 0 1
same $'1 miss\n2 miss\n3 miss eviction 1\nhits:0 misses:3 evictions:1' -E 2 1 2 3
same $'0 miss\n1 miss\n2 miss\n0 hit\n3 miss eviction 1\nhits:1 misses:4 evictions:1' -E 3 0 1 2 0 3
same $'1 miss\n2 miss\n3 miss\n1 hit\n2 hit\n4 miss eviction 3\n1 hit\nhits:3 misses:4 evictions:1' -E 3 1 2 3 1 2 4 1
same $'1 miss\n2 miss\n3 miss\n2 hit\n2 hit\n4 miss eviction 1\nhits:2 misses:4 evictions:1' -E 3 1 2 3 2 2 4
same $'7 miss\n7 hit\n8 miss\n9 miss eviction 7\nhits:1 misses:3 evictions:1' -E 2 7 7 8 9
same $'1 miss\n2 miss\n3 miss\n4 miss\n1 hit\n5 miss eviction 2\nhits:1 misses:5 evictions:1' -E 4 1 2 3 4 1 5
same $'1 miss\n2 miss\n3 miss eviction 1\n4 miss eviction 2\n5 miss eviction 3\nhits:0 misses:5 evictions:3' -E 2 1 2 3 4 5
same "5 miss
3 miss
5 hit
1 miss
4 miss eviction 3
3 miss eviction 5
3 hit
0 miss eviction 1
5 miss eviction 4
1 miss eviction 3
2 miss eviction 0
4 miss eviction 5
1 hit
0 miss eviction 2
0 hit
5 miss eviction 4
2 miss eviction 1
3 miss eviction 0
4 miss eviction 5
1 miss eviction 2
5 miss eviction 3
0 miss eviction 4
2 miss eviction 1
2 hit
3 miss eviction 5
1 miss eviction 0
4 miss eviction 2
0 miss eviction 3
5 miss eviction 1
3 miss eviction 4
hits:5 misses:25 evictions:22" -E 3 5 3 5 1 4 3 3 0 5 1 2 4 1 0 0 5 2 3 4 1 5 0 2 2 3 1 4 0 5 3
same "2 miss
7 miss
2 hit
9 miss
7 hit
4 miss
2 hit
8 miss eviction 9
9 miss eviction 7
7 miss eviction 4
1 miss eviction 2
2 miss eviction 8
4 miss eviction 9
4 hit
8 miss eviction 7
7 miss eviction 1
3 miss eviction 2
2 miss eviction 4
9 miss eviction 8
1 miss eviction 7
hits:4 misses:16 evictions:12" -E 4 2 7 2 9 7 4 2 8 9 7 1 2 4 4 8 7 3 2 9 1

echo "── 경계: 태그 0개·1개, 서로 다른 태그 E−1·E·E+1개, 태그 0"
same 'hits:0 misses:0 evictions:0' -E 4
same 'hits:0 misses:0 evictions:0' -E 1
same $'7 miss\nhits:0 misses:1 evictions:0' -E 1 7
same $'7 miss\n7 hit\n7 hit\nhits:2 misses:1 evictions:0' -E 1 7 7 7
same $'0 miss\nhits:0 misses:1 evictions:0' -E 2 0
same $'0 miss\n0 hit\n1 miss\n1 hit\nhits:2 misses:2 evictions:0' -E 3 0 0 1 1
same "$(distinct_want 3 2)" -E 3 0 1
same "$(distinct_want 3 3)" -E 3 0 1 2
same "$(distinct_want 3 4)" -E 3 0 1 2 3

echo "── 경계: 태그 2^64−1, 줄 수 1·65536"
same $'18446744073709551615 miss\n0 miss\n18446744073709551615 hit\n1 miss eviction 0\nhits:1 misses:3 evictions:1' -E 2 18446744073709551615 0 18446744073709551615 1
same $'18446744073709551615 miss\n0 miss eviction 18446744073709551615\nhits:0 misses:2 evictions:1' -E 1 18446744073709551615 0
same $'0 miss\n1 miss\n0 hit\nhits:1 misses:2 evictions:0' -E 65536 0 1 0

echo "── 긴 태그 열 (기대값은 LRU의 성질로 만든다)"
same "$(distinct_want 1 1000)" -E 1 $(seq 0 999)
same "$(distinct_want 1024 3000)" -E 1024 $(seq 0 2999)
same "$(repeat_want 8 1000)" -E 8 $(repeat_tags 8 1000)
same "$(cycle_want 100 3)" -E 100 $(cycle_tags 100 3)
same "$(hot_want 4 1000)" -E 4 $(hot_tags 1000)
same "$(distinct_want 8 20000)" -E 8 $(seq 0 19999)

echo "── E1: 사용법"
fails usage
fails usage -E
fails usage -x 2 1
fails usage 2 1 2
fails usage -e 2 1
fails usage -
fails usage --

echo "── E2: 줄 수 (1 이상 65536 이하의 10진 정수)"
fails '-E|0' -E 0 1 2
fails '-E|65537' -E 65537 1
fails '-E|65537' -E 65537
fails '-E|18446744073709551616' -E 18446744073709551616 1
fails '-E|-1' -E -1 1
fails '-E|four' -E four 1
fails '-E|0x10' -E 0x10 1
fails '-E|2.5' -E 2.5 1
fails '-E|!usage' -E '' 1
fails '-E|!usage' -E $'\xff' 1

echo "── E3: 태그 (10진 정수, 2^64 미만). 앞의 태그가 정상이어도 표준 출력은 비어 있다"
fails 'zz' -E 2 zz
fails 'zz|!qq' -E 2 1 zz qq
fails '18446744073709551616' -E 2 1 18446744073709551616
fails '-1' -E 2 -1
fails '0x10' -E 2 0x10
fails '1.5' -E 2 1.5
fails 'last' -E 2 1 2 3 last
fails '!usage' -E 2 1 ''
fails '!usage' -E 2 $'\xff'

echo "── E4: 출력 실패"
full -E 2 1 2 1
full -E 8 $(seq 0 19999)

if [ -n "${EXT:-}" ]; then
  # consistent E 태그...: -p random의 결과가 앞뒤가 맞는지 (어느 정책이든 지켜야 할 것). 태그는 하나 이상 준다
  #   결과 줄을 따라가며 세트의 내용을 다시 만든다. 줄마다 그 태그로 시작하고, hit은 세트에 있는 태그에만,
  #   miss는 없는 태그에만, 쫓아내기는 세트가 꽉 찼을 때만, 쫓겨나는 태그는 세트에 있던 것. 요약 줄은 위의 줄을 센 것
  #   태그는 문자열로 비교한다 (awk가 수로 비교하면 2^53 위에서 서로 다른 태그가 같다고 나온다)
  consistent() {
    local e=$1 why=() code msg
    shift
    got -E "$e" -p random "$@"
    printf '%s\n' "$@" > "$T/tags"
    msg=$(awk -v e="$e" '
      NR == FNR { tag[++n] = $0; next }
      { outn = FNR }
      FNR <= n {
        if (($1 "") != (tag[FNR] "")) { bad = 1; print FNR "줄이 태그 " tag[FNR] "로 시작하지 않음: " $0; exit }
        if (NF == 2 && $2 == "hit") {
          if (!($1 in now)) { bad = 1; print FNR "줄: 세트에 없는 태그가 hit: " $0; exit }
          h++
        } else if (NF == 2 && $2 == "miss") {
          if ($1 in now) { bad = 1; print FNR "줄: 세트에 있는 태그가 miss: " $0; exit }
          if (size >= e) { bad = 1; print FNR "줄: 세트가 꽉 찼는데 쫓아내지 않음: " $0; exit }
          now[$1]; size++; m++
        } else if (NF == 4 && $2 == "miss" && $3 == "eviction") {
          if ($1 in now) { bad = 1; print FNR "줄: 세트에 있는 태그가 miss: " $0; exit }
          if (size < e) { bad = 1; print FNR "줄: 빈 줄이 있는데 쫓아냄: " $0; exit }
          if (!($4 in now)) { bad = 1; print FNR "줄: 세트에 없던 태그를 쫓아냄: " $0; exit }
          delete now[$4]; now[$1]; m++; v++
        } else { bad = 1; print FNR "줄의 형식이 다름: " $0; exit }
        next
      }
      FNR == n + 1 {
        want = sprintf("hits:%d misses:%d evictions:%d", h, m, v)
        if ($0 != want) { bad = 1; print "요약 줄 기대 " want " 실제 " $0; exit }
        next
      }
      { bad = 1; print "요약 줄 뒤에 줄이 더 있음: " $0; exit }
      END { if (!bad && outn < n + 1) print "출력 줄 수 기대 " n + 1 " 실제 " outn + 0 }
    ' "$T/tags" "$T/out")
    [ -n "$msg" ] && why+=("$msg")
    [ -s "$T/err" ] && why+=("stderr가 비어 있어야 함: '$(grep -m 2 . "$T/err" | tr '\n' ' ')'")
    grep -q 'panicked' "$T/err" && why+=("패닉: $(panic_msg)")
    code=$(cat "$T/code")
    [ "$code" = 0 ] || why+=("종료 코드 기대=0 실제=$code")
    if [ ${#why[@]} -eq 0 ]; then pass "앞뒤가 맞음: $(label -E "$e" -p random "$@")"; else miss "앞뒤가 맞음: $(label -E "$e" -p random "$@")" "${why[@]}"; fi
  }

  echo "── 확장: -p lru·fifo"
  same $'1 miss\n2 miss\n1 hit\n3 miss eviction 2\n2 miss eviction 1\nhits:1 misses:4 evictions:2' -E 2 -p lru 1 2 1 3 2
  same $'1 miss\n2 miss\n1 hit\n3 miss eviction 1\n2 hit\nhits:2 misses:3 evictions:1' -E 2 -p fifo 1 2 1 3 2
  same $'1 miss\n2 miss\n3 miss\n1 hit\n4 miss eviction 1\n1 miss eviction 2\nhits:1 misses:5 evictions:2' -E 3 -p fifo 1 2 3 1 4 1
  same "1 miss
2 miss
3 miss
4 miss eviction 1
1 miss eviction 2
2 miss eviction 3
5 miss eviction 4
1 hit
2 hit
3 miss eviction 1
4 miss eviction 2
5 hit
hits:3 misses:9 evictions:6" -E 3 -p fifo 1 2 3 4 1 2 5 1 2 3 4 5
  same "1 miss
2 miss
3 miss
4 miss
1 hit
2 hit
5 miss eviction 1
1 miss eviction 2
2 miss eviction 3
3 miss eviction 4
4 miss eviction 5
5 miss eviction 1
hits:2 misses:10 evictions:6" -E 4 -p fifo 1 2 3 4 1 2 5 1 2 3 4 5
  same "$(distinct_want 4 50)" -E 4 -p fifo $(seq 0 49)
  same "$(repeat_want 4 10)" -E 4 -p fifo $(repeat_tags 4 10)

  echo "── 확장: -p random (결과가 정해지는 경우와, 앞뒤가 맞는지)"
  same $'1 miss\n2 miss eviction 1\n1 miss eviction 2\nhits:0 misses:3 evictions:2' -E 1 -p random 1 2 1
  same $'1 miss\n2 miss\n3 miss\n1 hit\n2 hit\n3 hit\nhits:3 misses:3 evictions:0' -E 4 -p random 1 2 3 1 2 3
  consistent 2 1 2 3 1 2 3 4 5 6 1 2 1 3 3 2
  consistent 4 $(for r in 1 2 3 4 5 6 7 8; do echo 1 2 3 4 5 6; done)
  consistent 8 $(seq 0 99) $(seq 0 99)

  echo "── 확장: 오류"
  fails usage -E 2 -p
  fails '-p|mru' -E 2 -p mru 1
  fails 'zz' -E 2 -p fifo 1 zz
fi

echo
echo "OK $ok · FAIL $fail"
[ "$fail" -eq 0 ]
