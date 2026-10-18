#!/usr/bin/env bash
# D0-일 wc-lite 완료 기준
# 표준 출력·표준 에러·종료 코드를 모두 비교하고, 경계값을 넣는다 (PRINCIPLES 6-2).
# 기대값은 C 로캘의 GNU wc로 만든다. 명세가 wc와 다르게 정한 곳(E1, E2의 디렉터리, E3, E4)은 명세 기준으로 본다.
# 사용: ./days/d00-wc-lite/check.sh
#       X=다른/바이너리 ./days/d00-wc-lite/check.sh   (빌드와 단위 테스트 없이 그 바이너리만 검사)
#       EXT=1 ./days/d00-wc-lite/check.sh            (확장: E1 대신 표준 입력을 wc와 비교)
set -u
export LC_ALL=C
[ -n "${X:-}" ] && X=$(realpath "$X")
cd "$(dirname "$0")/../.." || exit 1

unit=
if [ -z "${X:-}" ]; then
  cargo build -q -p wc-lite || exit 1
  X=target/debug/wc-lite
  unit=1
fi

T=$(mktemp -d)
trap 'chmod -R u+rw "$T"; rm -rf "$T"' EXIT
ok=0
fail=0
IN=/dev/null # 표준 입력 (기본은 비어 있음. 구현이 표준 입력을 읽어도 멈추지 않게)
PIPE=        # 1이면 표준 입력을 파이프로 준다
SHOW_IN=     # 1이면 케이스 이름에 표준 입력의 출처를 붙인다

# ── 테스트 입력 ────────────────────────────────────────────
printf 'Hello, world\n' > "$T/hello"                    # 13바이트 (명세 예시)
: > "$T/empty"                                          # 0바이트
printf 'a' > "$T/one"                                   # 1바이트, \n 없음
printf '\n' > "$T/nl"                                   # \n 하나뿐
printf 'one two' > "$T/notail"                          # 마지막 줄에 \n 없음
printf '  lead  trail  \n\n\nx\n' > "$T/spaces"         # 연속 공백, 빈 줄
printf 'a\tb\nc\vd\fe\rf g\n' > "$T/ws6"                # 공백 6종이 하나씩 단어를 끊음
printf 'a\001b \001 \177\200\377 c\001\n' > "$T/other"  # 그 밖의 바이트: 시작도 끊기도 안 함
for i in $(seq 0 255); do printf "\\$(printf %03o "$i")"; done > "$T/all"  # 0x00~0xff 한 번씩
gzip -cn /bin/ls | head -c 1000 > "$T/rand"              # 무작위처럼 보이지만 매번 같은 1000바이트
printf '12345' > "$T/s5"; printf '1234' > "$T/s4"       # 합 9 → 폭 1, 합 10 → 폭 2
printf '123456789' > "$T/s9"; printf '1234567890' > "$T/s10"
yes 'lorem ipsum' | head -c 999999 > "$T/m6"            # 6자리
yes 'lorem ipsum' | head -c 1000000 > "$T/m7"           # 7자리
truncate -s 100000000 "$T/big"                          # 10^8바이트 희소 파일 (0x00뿐)
printf 'secret\n' > "$T/locked"; chmod 000 "$T/locked"
mkdir "$T/dir"

# ── 판정 도구 ──────────────────────────────────────────────
# run 프로그램 인자...: IN을 표준 입력으로 주고 실행 (PIPE=1이면 파이프로)
run() {
  if [ -n "$PIPE" ]; then cat "$IN" | "$@"; else "$@" < "$IN"; fi
}
# want: 기대값을 wc로 만든다 (stderr의 "wc: "를 "wc-lite: "로)
# got: 검사 대상 실행 (stderr 끝의 " (os error N)"을 뗀다)
want() {
  run wc "$@" > "$T/w.out" 2> "$T/w.err"; echo $? > "$T/w.code"
  sed -i 's/^wc: /wc-lite: /' "$T/w.err"
}
got() {
  run "$X" "$@" > "$T/g.out" 2> "$T/g.err"; echo $? > "$T/g.code"
  sed -i 's/ (os error [0-9]*)$//' "$T/g.err"
}

# 임시 폴더 경로를 떼고 보여 준다 / 파일 내용을 한 줄로 줄여 보여 준다
label() { local s="$*"; s=${s//$T\//}; echo "${s//$T/<임시폴더>}"; }
peek() { local s; s=$(tr -s '\n' '|' < "$1"); s=${s//$T\//}; s=${s//$T/<임시폴더>}; echo "${s:0:120}"; }
# 표준 입력을 쓰는 케이스면 이름 뒤에 그 출처를 붙인다
src() {
  [ -n "$SHOW_IN" ] || return 0
  if [ -n "$PIPE" ]; then echo " (cat $(label "$IN") |)"; else echo " (< $(label "$IN"))"; fi
}

pass() { ok=$((ok + 1)); echo "OK   $1"; }
miss() { fail=$((fail + 1)); echo "FAIL $1"; shift; for why in "$@"; do echo "       $why"; done; }

verdict() {
  local name=$1 why=()
  cmp -s "$T/w.out" "$T/g.out" || why+=("stdout 기대='$(peek "$T/w.out")' 실제='$(peek "$T/g.out")'")
  cmp -s "$T/w.err" "$T/g.err" || why+=("stderr 기대='$(peek "$T/w.err")' 실제='$(peek "$T/g.err")'")
  cmp -s "$T/w.code" "$T/g.code" || why+=("종료 코드 기대=$(cat "$T/w.code") 실제=$(cat "$T/g.code")")
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

# same 인자...: wc와 같은 인자로 돌려 비교
same() { want "$@"; got "$@"; verdict "$(label "$@")$(src "$@")"; }

# same_nodir 인자...: E2 디렉터리 — wc 출력에서 디렉터리의 줄만 뺀 것과 비교
same_nodir() {
  want "$@"; got "$@"
  sed -i "\\| $T/dir\$|d" "$T/w.out"
  verdict "$(label "$@") (디렉터리 줄 없음)"
}

# fails 인자...: 종료 코드 1, stdout 비어 있음, stderr 첫 줄이 "wc-lite:"로 시작, 패닉 없음
fails() {
  local why=() first
  got "$@"
  first=$(grep -m 1 . "$T/g.err")
  [ "$(cat "$T/g.code")" = 1 ] || why+=("종료 코드 기대=1 실제=$(cat "$T/g.code")")
  [ -s "$T/g.out" ] && why+=("stdout이 비어 있어야 함: '$(peek "$T/g.out")'")
  [[ "$first" == "wc-lite:"* ]] || why+=("stderr 기대='wc-lite:…' 실제='$first'")
  grep -q 'panicked' "$T/g.err" && why+=("패닉")
  local name="오류 $(label "$@")"
  [ $# -eq 0 ] && name="오류 (인자 없음)"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

# full 인자...: E4 — 표준 출력이 /dev/full일 때 종료 코드 1, stderr가 "wc-lite:"로 시작, 패닉 없음
full() {
  local why=() code first
  "$X" "$@" < /dev/null > /dev/full 2> "$T/g.err"; code=$?
  first=$(grep -m 1 . "$T/g.err")
  [ "$code" = 1 ] || why+=("종료 코드 기대=1 실제=$code")
  [[ "$first" == "wc-lite:"* ]] || why+=("stderr 기대='wc-lite:…' 실제='$first'")
  grep -q 'panicked' "$T/g.err" && why+=("패닉")
  local name="> /dev/full: $(label "$@")"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

H=$T/hello

echo "── M1: counts 모듈과 단위 테스트"
if [ -n "$unit" ]; then
  if [ -f days/d00-wc-lite/src/counts.rs ]; then
    pass "src/counts.rs 있음"
  else
    miss "src/counts.rs 있음" "Counts와 from_bytes는 src/counts.rs에 둔다 (명세 제약)"
  fi
  cargo test -q -p wc-lite -- counts:: > "$T/test.out" 2>&1
  code=$?
  n=$(grep -o '[0-9]* passed' "$T/test.out" | awk '{ s += $1 } END { print s + 0 }')
  if [ "$code" = 0 ] && [ "$n" -ge 3 ]; then
    pass "cargo test: counts 모듈 테스트 ${n}개 통과"
  else
    miss "cargo test: counts 모듈 테스트 3개 이상 통과" "종료 코드=$code, 통과=${n}개 (cargo test -p wc-lite로 확인)"
  fi
  # 테스트가 실제로 from_bytes를 검사하는지 (mod tests 아래에서 from_bytes를 부른 줄 수)
  calls=$(sed -n '/mod tests/,$p' days/d00-wc-lite/src/counts.rs 2>/dev/null | grep -c 'from_bytes')
  if [ "$calls" -ge 3 ]; then
    pass "테스트가 from_bytes를 ${calls}번 부름"
  else
    miss "테스트가 from_bytes를 3번 이상 부름" "mod tests 안에서 from_bytes 호출 ${calls}번 (빈 입력, 마지막 \\n 없음, 공백 6종을 검사한다)"
  fi
else
  echo "SKIP (X를 지정하면 건너뜀)"
fi

echo "── F1·F2: 파일 하나, 기본 세 항목 (0, 1바이트, \\n만, \\n 없음, 공백, 바이트 부류)"
for f in empty one nl notail hello spaces ws6 other all rand; do same "$T/$f"; done
same /bin/ls

echo "── F4: 옵션 (하나, 여럿, 순서, 묶어 쓰기, 중복, 위치)"
for o in -l -w -c; do same "$o" "$H"; done
same -w -l "$H"
same -c -l "$H"
same -c -w -l "$H"
same -lw "$H"
same -cl "$H"
same -wcl "$H"
same -l -l "$H"
same -ll "$H"
same "$H" -l

echo "── F5: 여러 파일과 합계 (2, 같은 파일 두 번, 8개)"
same "$H" "$T/empty"
same "$H" "$H"
same -l "$H" "$T/empty"
same -l "$H" -c "$T/empty"  # 옵션이 파일 사이에 있어도 된다
same -w "$T/ws6" "$T/other" "$T/all"
same "$H" "$H" "$H" "$H" "$H" "$H" "$H" "$H"
same "$T/notail" "$T/other" "$T/rand" /bin/ls

echo "── F6: 폭 (자릿수 경계, 장치 파일, 메타데이터 크기 0, 아주 큰 파일)"
same "$T/s9"
same "$T/s10"
same "$T/s5" "$T/s4"
same "$T/s5" "$T/s5"
same "$T/m6"
same "$T/m7"
same -l "$T/m7"
same /dev/null
same -l /dev/null
same -l /dev/null "$H"
same /proc/version
same -l /proc/version "$H"
same "$T/big"
same -c "$T/big" "$H"

echo "── E2: 파일을 못 읽으면 알리고 다음으로 (없음, 권한, 디렉터리)"
same "$T/nofile"
same -l "$T/nofile"
same "$H" "$T/nofile"
same "$T/nofile" "$H"
same "$T/nofile" "$T/nofile2"
same -l "$T/nofile" "$H" /dev/null
if [ "$(id -u)" != 0 ]; then
  same "$T/locked" "$H"
  same "$T/locked" "$T/s5"   # 못 연 파일도 stat은 되므로 폭에 들어간다 (7+5=12 → 폭 2)
fi
same_nodir "$T/dir"
same_nodir "$T/dir" "$H"
same_nodir -c "$H" "$T/dir"
fails "$T/"$'\xff'   # UTF-8이 아닌 파일 이름: 패닉 없이 E2 (메시지 형식은 보지 않음)

echo "── E1: 파일 인자 없음"
if [ -z "${EXT:-}" ]; then
  fails
  fails -l
else
  echo "   (EXT=1: 표준 입력을 wc와 비교)"
  SHOW_IN=1
  IN=/dev/null; same; same -l
  IN=$H; same; same -w; same -; same "$H" -; same - "$T/empty"
  PIPE=1; same; same -c; same -; same "$H" -
  PIPE=; IN=/dev/null; SHOW_IN=
fi

echo "── E3: 모르는 옵션 (표준 출력은 비어 있어야 함)"
fails -x "$H"
fails -lx "$H"
fails "$H" -x
fails --lines "$H"
fails -l "$H" -q "$T/empty"

echo "── E4: 출력 실패"
full "$H"
full "$H" "$H" "$H" "$H" "$H" "$H" "$H" "$H"

echo
echo "OK $ok · FAIL $fail"
[ "$fail" -eq 0 ]
