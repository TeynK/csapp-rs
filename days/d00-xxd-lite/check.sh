#!/usr/bin/env bash
# D0 xxd-lite 완료 기준 (리뷰 반영판)
# 표준 출력·표준 에러·종료 코드를 모두 비교하고, 경계값을 넣는다 (PRINCIPLES 6-2).
# 사용: ./days/d00-xxd-lite/check.sh
#       X=다른/바이너리 ./days/d00-xxd-lite/check.sh   (빌드 없이 그 바이너리를 검사)
set -u
cd "$(dirname "$0")/../.." || exit 1

if [ -z "${X:-}" ]; then
  cargo build -q -p xxd-lite || exit 1
  X=target/debug/xxd-lite
fi

T=$(mktemp -d)
trap 'chmod -R u+rw "$T"; rm -rf "$T"' EXIT
ok=0
fail=0

# ── 테스트 입력 ────────────────────────────────────────────
printf 'Hello, world\n' > "$T/hello"                        # 13바이트 (명세 예시)
: > "$T/empty"                                              # 0바이트
for i in $(seq 0 255); do printf "\\$(printf %03o "$i")"; done > "$T/all"  # 0x00~0xff 한 번씩
for n in 1 15 16 17 32; do head -c "$n" "$T/all" > "$T/b$n"; done   # 줄 경계 앞뒤
head -c 1000 /dev/urandom > "$T/rand"
printf 'secret\n' > "$T/locked"; chmod 000 "$T/locked"

# ── 판정 도구 ──────────────────────────────────────────────
# want: 기대값을 xxd로 만든다 / got: 검사 대상 실행 / verdict: 셋 다 같으면 OK
want() { xxd "$@" > "$T/w.out" 2> "$T/w.err"; echo $? > "$T/w.code"; }
want_nothing() { : > "$T/w.out"; : > "$T/w.err"; echo 0 > "$T/w.code"; }
got() { "$X" "$@" > "$T/g.out" 2> "$T/g.err"; echo $? > "$T/g.code"; }

# 임시 폴더 경로를 떼고 보여 준다 / 파일 내용을 한 줄로 줄여 보여 준다
label() { local s="$*"; s=${s//$T\//}; echo "${s//$T/<임시폴더>}"; }
peek() { tr -s '\n' ' ' < "$1" | head -c 100; }

pass() { ok=$((ok + 1)); echo "OK   $1"; }
miss() { fail=$((fail + 1)); echo "FAIL $1"; shift; for why in "$@"; do echo "       $why"; done; }

verdict() {
  local name=$1 why=()
  cmp -s "$T/w.out" "$T/g.out" || why+=("stdout 다름: diff <(xxd ...) <(\$X ...) | head")
  cmp -s "$T/w.err" "$T/g.err" || why+=("stderr 기대='$(peek "$T/w.err")' 실제='$(peek "$T/g.err")'")
  cmp -s "$T/w.code" "$T/g.code" || why+=("종료 코드 기대=$(cat "$T/w.code") 실제=$(cat "$T/g.code")")
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

# same 인자...: xxd와 같은 인자로 돌려 비교
same() { want "$@"; got "$@"; verdict "$(label "$@")"; }

# fails 메시지접두사 인자...: 종료 코드 1, stdout 비어 있음, stderr 첫 줄이 접두사로 시작, 패닉 없음
# 접두사가 ''이면 stderr가 비어 있지만 않으면 된다
fails() {
  local prefix=$1 why=() first
  shift
  got "$@"
  first=$(grep -m 1 . "$T/g.err")
  [ "$(cat "$T/g.code")" = 1 ] || why+=("종료 코드 기대=1 실제=$(cat "$T/g.code")")
  [ -s "$T/g.out" ] && why+=("stdout이 비어 있어야 함")
  [ -n "$first" ] || why+=("stderr에 메시지가 없음")
  [[ "$first" == "$prefix"* ]] || why+=("stderr 기대='$prefix…' 실제='$first'")
  grep -q 'panicked' "$T/g.err" && why+=("패닉")
  local name="오류 $(label "$@")"
  [ $# -eq 0 ] && name="오류 (인자 없음)"
  if [ ${#why[@]} -eq 0 ]; then pass "$name"; else miss "$name" "${why[@]}"; fi
}

H=$T/hello # n = 13
A=$T/all   # n = 256

echo "── F1~F4, F7: 파일 전체 (0, 1, 15, 16, 17, 32, 256, 1000바이트, /bin/ls)"
same "$H"
same "$T/empty"
for n in 1 15 16 17 32; do same "$T/b$n"; done
same "$A"
same "$T/rand"
same /bin/ls

echo "── F5, F7: -s (n = 13: 0, 1, n-1, n, n+1, 아주 큰 값)"
for s in 0 1 7 12 13 14 99999999; do same -s "$s" "$H"; done
same -s 5 "$A"  # 줄 경계에 맞지 않는 시작
same -s 16 "$A" # 줄 경계에 맞는 시작
# xxd는 LONG_MAX를 넘는 -s에 exit 4로 실패하므로, 여기서는 명세(F7)대로 기대값을 정한다
want_nothing; got -s 18446744073709551615 "$H"; verdict "-s usize::MAX (F7: 출력 없음, exit 0)"

echo "── F6, F7: -l (0, 1, n-1, n, n+1, 줄 경계 15·16·17, 아주 큰 값)"
for l in 0 1 12 13 14 99999999999 18446744073709551615; do same -l "$l" "$H"; done
for l in 15 16 17; do same -l "$l" "$A"; done

echo "── F5+F6: 함께 쓰기"
same -s 16 -l 64 /bin/ls
same -l 64 -s 16 /bin/ls
same -s 5 -l 20 "$A"   # 시작도 끝도 줄 경계가 아님
same -s 250 -l 10 "$A" # 길이가 파일 끝을 넘음
same -s 13 -l 5 "$H"   # 시작이 정확히 파일 끝
same -s 0 -l 0 "$H"

echo "── 옵션과 파일의 순서 (xxd는 파일 뒤 옵션을 받지 않으므로 앞 순서의 출력과 비교)"
want -s 16 -l 32 "$A"; got "$A" -s 16 -l 32; verdict "파일 -s 16 -l 32"
want -s 16 -l 32 "$A"; got -s 16 "$A" -l 32; verdict "-s 16 파일 -l 32"

echo "── E1: 파일 인자 없음"
fails ''
fails '' -s 1
fails '' -l 4

echo "── E2: 파일을 못 읽음"
fails "xxd-lite: $T/nofile: No such file or directory" "$T/nofile"
fails "xxd-lite: $T: Is a directory" "$T"
if [ "$(id -u)" != 0 ]; then
  fails "xxd-lite: $T/locked: Permission denied" "$T/locked"
fi

echo "── E3: 값이 없거나 숫자가 아님, 모르는 옵션"
fails '' -s abc "$H"
fails '' -l abc "$H"
fails '' -s 1x "$H"
fails '' -s '' "$H"
fails '' -s 99999999999999999999 "$H" # usize를 넘는 수
fails '' "$H" -s
fails '' "$H" -l
fails '' -x "$H"

echo
echo "OK $ok · FAIL $fail"
[ "$fail" -eq 0 ]
