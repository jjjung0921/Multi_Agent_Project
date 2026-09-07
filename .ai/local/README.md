# .ai/local — 개인 메모리 (git이 추적하지 않는다)

이 디렉터리는 `.gitignore`로 제외된다(이 README만 추적). 내 Agent만 읽고 쓴다. `scripts/ai-stream.sh setup --local`이 만들며, 여러 기기를 쓰면 `--local-memory <개인 경로>`로 심링크한다.

- `MEMORY.md` (50줄 상한) — 내 Agent가 나에 대해 배운 것: 선호, 교정, 자주 하는 실수, 내 환경. 프로젝트 사실은 여기가 아니라 역할 메모리(`.claude/agent-memory/`)나 docs로.
- `INBOX.md` — 팀에 보이고 싶지 않은 지시. 스트림 INBOX와 같은 형식, 같은 우선순위.
- `notes/` — 개인 메모.
- 비밀값은 여기에도 두지 않는다(화면·로그로 샌다).
