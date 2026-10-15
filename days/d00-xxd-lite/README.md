# D0 · xxd-lite

## 명세

### 목적
파일을 바이트 그대로 보여 주는 헥스 덤프 도구. 리눅스 `xxd`의 축소판이다.
ELF 분석(D8~D13), malloc 블록 헤더(D38), DNS 패킷(D44)을 볼 때 계속 쓴다.
Rust로는 파일 읽기, `Vec<u8>`와 슬라이스 빌림, 반복, 포맷 출력, `Result` 오류 처리를 처음 익힌다.

### 사용법
```
xxd-lite [-s 시작] [-l 길이] <파일>
```
- `-s N`: N번째 바이트부터 출력 (10진수)
- `-l N`: 최대 N바이트만 출력 (10진수)
- 옵션과 파일은 어떤 순서로 와도 된다

### 기능
- F1. 파일을 읽어 16바이트씩 한 줄로 출력한다
- F2. 한 줄은 `오프셋: 16진 영역  ASCII 열`
  - 오프셋: 8자리 소문자 16진수 뒤에 `:`와 공백 1칸
  - 16진 영역: 바이트마다 소문자 2자리, 2바이트 묶음 사이에 공백 1칸 (꽉 찬 줄은 39칸)
  - 16진 영역 뒤에 공백 2칸, 그다음 ASCII 열
- F3. ASCII 열은 0x20~0x7e면 그 글자, 나머지는 `.`
- F4. 마지막 줄이 짧아도 16진 영역을 39칸까지 공백으로 채워 ASCII 열 위치를 맞춘다
- F5. `-s N`: N번째 바이트부터 출력하고, 오프셋 열은 파일 기준 실제 위치를 보인다
- F6. `-l N`: 최대 N바이트까지만 출력한다
- F7. 출력할 바이트가 없으면(빈 파일, N이 파일 길이 이상) 아무것도 출력하지 않고 종료 코드 0

### 출력 예시 (실제 xxd와 같음)
```
$ printf 'Hello, world\n' > hello.txt
$ xxd-lite hello.txt
00000000: 4865 6c6c 6f2c 2077 6f72 6c64 0a         Hello, world.
$ xxd-lite -s 7 hello.txt
00000007: 776f 726c 640a                           world.
```

### 오류 처리 (잘못된 입력에 패닉 금지)
- E1. 파일 인자가 없으면: 표준 에러에 사용법 한 줄, 종료 코드 1
- E2. 파일을 못 읽으면: `xxd-lite: <파일>: <OS 오류 메시지>`, 종료 코드 1
- E3. `-s`·`-l` 값이 없거나 숫자가 아니면, 또는 모르는 옵션이면: 오류 메시지, 종료 코드 1
  (진짜 xxd는 `-s abc`를 0으로 취급하지만 여기서는 오류)

### 제약
- std만 사용. 외부 크레이트와 unsafe는 쓰지 않는다
- `std::fs::read`로 한 번에 읽어도 된다 (조금씩 읽기는 D16 RIO)
- 정상 출력은 표준 출력, 오류는 표준 에러

### 완료 기준 (저장소 루트에서)
```sh
cargo build -q -p xxd-lite && X=target/debug/xxd-lite
head -c 1000 /dev/urandom > /tmp/rand.bin; : > /tmp/empty
for f in /bin/ls Cargo.toml /tmp/rand.bin /tmp/empty; do
  diff <(xxd "$f") <($X "$f") > /dev/null && echo "OK $f" || echo "FAIL $f"
done
diff <(xxd -s 16 -l 64 /bin/ls) <($X -s 16 -l 64 /bin/ls) && echo "OK -s -l"
diff <(xxd -l 13 /bin/ls) <($X -l 13 /bin/ls) && echo "OK 덜 찬 줄"
diff <(xxd -s 99999999 Cargo.toml) <($X -s 99999999 Cargo.toml) && echo "OK 끝 넘김"
$X /없는/파일; echo "exit=$?"
$X -s abc /bin/ls; echo "exit=$?"
$X; echo "exit=$?"
```
- 모든 줄에 OK, 마지막 세 줄은 패닉 없이 메시지와 `exit=1`
- FAIL이면 `diff <(xxd 파일) <($X 파일) | head`로 첫 차이 확인

### 범위 밖
표준 입력, `-c`·`-g` 같은 다른 xxd 옵션, 음수 `-s`

### 확장
- `-s 0x10`처럼 0x로 시작하는 16진수 값 받기
- `-e`: 4바이트씩 리틀 엔디언으로 묶어 출력하고 `xxd -e`와 diff (덜 찬 마지막 묶음은 묶음 안에서 오른쪽 정렬)
- `$X /bin/ls | head -1`의 결과를 예측하고 실행해 보기. 이상하면 원인을 찾아 고치기 (11장 SIGPIPE 예고)

## 기록
- 예측:
  1. 폴더 덤프는 처음이라 아에 감이 안오는데
  2. read의 unwrap이 예외처리 안해서 안될 줄 알았는데.
- 결과: 
  1. 리눅스의 실행 파일은 ELF형식이고, 파일 맨 앞 4바이트가 매직 넘버다(.ELF)
  2. dump로 data를 보내고 함수가 종료되면 소유권이 사라짐. 그래서 len에서 오류. 고칠려면 참조자 이용해서 빌려주거나 복제해서 주기.
- 배운 것:
- 재미(1~5): · 막힌 시간(분): · 힌트 단계(0~3):
