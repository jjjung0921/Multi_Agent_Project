# Team — 공지 색인

<!-- `scripts/ai-stream.sh announce` 가 아래 표를 생성한다. 손으로 고치지 않는다. 공지 형식은 announcements/_template.md -->

<!-- announcements:begin -->
| 공지 | Required | Applies to | Until |
|------|----------|------------|-------|
<!-- announcements:end -->

- 공지는 팀 전체가 행동해야 하는 변경(AGENTS.md·ARCHITECTURE·API의 breaking 변경, 새 관례)에만 쓴다. 개인 간 요청은 이슈·PR 코멘트로.
- 각 스트림의 `ai-start.sh`가 미확인 공지를 맨 앞에 보여주고, Agent는 Action 수행 후 `CURRENT.md`의 `Acked:`에 id를 적는다. `Required: yes` 공지는 확인 전 PR 병합이 막힌다(`ai-end.sh --ci`).
- `Until`이 지난 공지는 Phase 종료 스트림에서 삭제한다(결정은 ADR에 이미 있다).
