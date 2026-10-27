# 버그 일지

2026-10-17: D0 - hex값이 아닌 10진수 출력, 원인은 fmt에서 x를 뺴먹음. 다음부턴 출력명세 확인할 것.
2026-10-26 · D2 · release에서 throughput이 끝나지 않음 → black_box(for …)가 for의 값 ()만 감싸 read_stride 결과가 버려지고 루프가 지워져 repeat이 끝없이 두 배 → black_box는 루프 안에서 입력과 결과에
2026-10-26 · D2 · 정상 값 16K가 빈 문자열이 됨 → strip_prefix("-").unwrap_or_default()에서 None이 기본값 ""가 됨 → unwrap_or_default는 기본값이 뜻에 맞을 때만(D1에 이어 두 번째)
2026-10-27 · D2 · 16K 같은 정상 크기가 거절됨 → (MIN..=MAX).contains 앞의 ! 누락으로 조건이 뒤집힘 → 범위 검사는 경계값으로 바로 돌려 본다
