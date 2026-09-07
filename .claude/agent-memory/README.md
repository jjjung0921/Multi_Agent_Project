# agent-memory — 역할별 프로젝트 전용 메모리

전문 역할(be-architect, fe-architect, project-* 등 `~/.agents/agents/`의 역할과 이 저장소의 `.claude/agents/git-flow`)이 **이 프로젝트에서** 배운 것을 두는 곳. 역할마다 하위 폴더 하나(`<역할>/`), 그 안에 `MEMORY.md`(인덱스, 100줄 상한)와 토픽 파일(`decisions.md`·`feedback.md`·`conventions.md`·`history.md`). 형식과 절차는 `~/.agents/skills/agent-memory-protocol/SKILL.md`가 소유한다.

- **Claude Code**: `memory: project` 서브에이전트가 자기 폴더의 `MEMORY.md`를 자동 로드하고 종료 전 갱신한다. 폴더는 첫 호출 때 스스로 만든다.
- **Codex 등 서브에이전트 메모리가 없는 엔진**: 역할 스킬(`~/.codex/skills/<역할>/`)의 `[메모리]` 줄에 따라 같은 폴더를 직접 읽고 쓴다. `MEMORY.md`가 없으면 첫 실행(시딩).
- **개발자**: 읽어도 되지만 손으로 고치지 않는다 — 틀린 기억은 내 스트림 `INBOX.md`로 지시하면 다음 호출에서 역할이 고친다.
- **팀**: 여러 사람이 같은 역할을 돌리므로 세션마다 갱신하지 않고 **스트림의 `--ready` 단계(main 동기화 후)의 close commit에서만** 갱신한다. 항목은 독립적이라 `.gitattributes`의 `merge=union`으로 충돌 시 양쪽을 보존한다. 개발자 개인의 취향·교정은 여기가 아니라 `.ai/local/MEMORY.md`에 둔다 — 프로젝트 사실만 여기에.

내용은 레포에서 다시 얻을 수 없는 것만(결정 이유·기각 대안·개발자 교정·반복 실패·산출물 인덱스). 커밋 대상이지만 source of truth가 아니다 — `AGENTS.md` Truth 순서에서 ⑩이고 spec·ADR이 우선한다. 세션을 연 디렉터리 기준으로 위치가 정해지므로, 세션은 이 저장소 루트에서 연다.
