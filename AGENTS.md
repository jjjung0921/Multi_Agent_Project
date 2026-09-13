# AGENTS.md

모든 AI Agent(Claude Code, Codex, Gemini CLI, ChatGPT 등)와 개발자가 공유하는 공통 규칙이다. 짧게 유지한다.
장기 지식은 `docs/`, 작업 상태는 `.ai/work/<내 스트림>/`에 있으며 여기에 복사하지 않는다. 도구가 이 파일을 이미 로드했다면(CLAUDE.md·GEMINI.md import) 다시 읽지 않는다.

## Project

- Name: <프로젝트 이름>
- Summary: <누구를 위한 무엇인지 한 줄>
- Stack: <언어 / 프레임워크 / 런타임 / 패키지 매니저>

<!-- 템플릿 초기화(.ai/BOOTSTRAP.md) 시 채운다. 상세 설명은 README.md, 요구사항은 docs/PRD.md에 둔다. -->

## Repository Map

- `docs/PRD.md` 요구사항 · `docs/ARCHITECTURE.md` 현재 구조(Module Boundaries의 Owner = 소유권) · `docs/api/` API spec · `docs/decisions/` ADR · `docs/phases/` Phase 계획/결과 · 추적 표(PRD FR/NFR → Task `Refs:` → 스트림, `ai-stream.sh trace` 생성)
- `.ai/work/<id>/` 스트림 상태 — `CURRENT.md` 상태·checkpoint·Touches·Acked · `HANDOFF.md` 인수인계 · `LOG.md` 세션 보고 · `INBOX.md` 소유자 지시 · `notes/` 임시 메모
- `.ai/team/announcements/` 팀 공지(must-read) · `.ai/local/` 개인 메모리(미추적, 내 Agent만) · `.claude/agent-memory/<역할>/` 역할 메모리 · `.claude/agents/git-flow.md` flow 역할
- `scripts/ai-start.sh` 세션 시작 · `scripts/ai-end.sh` 종료 점검 / `--ready` PR 준비 / `--ci` · `scripts/ai-stream.sh` 스트림·Phase·이력 관리 · `src/` 구현 · `tests/` 테스트

<!-- src/·tests/는 단일 패키지 기본값이다. backend/frontend/db/infra처럼 구성요소가 여럿이면 초기화 시 이 줄을 구성요소 목록으로 바꾼다 (.ai/BOOTSTRAP.md의 Layout). -->

## Rules

1. **Memory** — 저장소가 기억이다. 상태·의도·계획·규칙은 파일과 커밋에 남기고, 대화 기억에 의존하지 않는다.
2. **Truth** — 정보가 충돌하면 이 순서로 우선한다: ① 스트림 소유자의 직접 지시(대화·스트림 INBOX·`.ai/local/INBOX.md`)와 승인된 PR 리뷰 ② tests·type system·schemas·`docs/api/` ③ 현재 코드 ④ ADR ⑤ `docs/ARCHITECTURE.md` ⑥ `docs/PRD.md` ⑦ 현재 Phase `PLAN.md` ⑧ 내 `CURRENT.md` ⑨ 내 `HANDOFF.md` ⑩ 과거 대화·역할 메모리. 다른 스트림의 CURRENT/HANDOFF는 근거가 아니다. 코드가 spec을 위반해 보이면 코드를 정답으로 보지 말고 inconsistency로 보고한다.
3. **Loading** — 필요한 것만 읽는다: 이 파일 → `.ai/work/<내 스트림>/CURRENT.md` → `HANDOFF.md` → `.ai/local/MEMORY.md`(있으면) → `scripts/ai-start.sh` 출력 → CURRENT가 지정한 문서·파일 → 현재 `PLAN.md`. 다른 스트림의 파일은 읽지 않는다(`ai-start.sh` 요약만). 팀 이력은 main의 first-parent 로그로 보고(아래 History), 브랜치 커밋은 특정 스트림·Task를 파고들 때만 본다. ARCHITECTURE·ADR·PRD·과거 Phase·`notes/`·checkpoint 이전 커밋은 이유가 있을 때만 본다.
4. **Changes** — checkpoint 이후의 커밋은 `ai-start.sh`가 나눈다. 내 브랜치의 trailer 없는 커밋은 **사람의 직접 수정**(소유자 또는 이전 소유자), main에서 유입된 커밋은 **동료 변경**이다. 어느 쪽도 되돌리지 않는다. 직접 수정은 diff를 읽고 spec·PLAN·HANDOFF에 반영하며 LOG의 Developer changes에 적는다. 동료 변경은 내 Touches·Relevant Files와 겹치는 부분만 확인·반영하고 LOG의 Upstream changes에 적는다. 의도가 불분명하면 그대로 두고 HANDOFF의 Unverified Assumptions에 적은 뒤 묻는다. 의견이 다르면 HANDOFF Known Problems + PR 코멘트.
5. **Inbox & Announcements** — 내 스트림 `INBOX.md`(와 `.ai/local/INBOX.md`)의 항목만 소유자의 직접 지시다. 처리한 항목은 삭제하고 결과를 LOG에 적으며, 못 한 항목은 남기고 이유를 적는다. `.ai/team/announcements/`의 공지는 Action을 수행하고 CURRENT의 `Acked:`에 id를 적는다(`Applies to`가 내 Touches와 무관하면 확인만). 그 밖의 팀 변경은 main의 spec·이 파일 변경으로 온다.
6. **Scope** — 현재 Phase `PLAN.md`의 Scope와 CURRENT의 `Touches:` 안에서만 작업한다. Touches 밖 파일을 고치려면 먼저 제안하고, 승인되면 CURRENT의 Touches를 먼저 고친다. Scope 밖 문제는 고치지 말고 HANDOFF의 Known Problems에 적는다. 요청받지 않은 리팩터링·의존성 추가·구조 변경은 먼저 제안한다. 다른 스트림의 `.ai/work/<id>/`는 절대 수정하지 않는다.
7. **Spec first** — Spec(PRD·ARCHITECTURE·API) 변경은 구현보다 먼저 main에 있어야 한다: spec 스트림(`ai-stream.sh open spec <slug>`)으로 PR을 내고 병합된 뒤 구현한다. 예외는 내 Touches에 선언된 spec 조각 안의 변경뿐이며, 그때는 같은 PR에 두고 LOG의 `Spec changes:`에 명시한다(`--ci`가 검사). 공개 인터페이스(API·스키마·CLI)와 spec은 같은 커밋에서 갱신한다.
8. **Verification** — 코드 변경은 test/typecheck/lint를 경고 없이 통과해야 완료다(경고는 실패로 설정한다). 새 기능·버그 수정에는 테스트를 같은 커밋에 넣는다. 실행하지 않은 검증을 완료로 적지 않고, 검증 절차는 PLAN의 Validation Plan과 RESULT에 남긴다. CI가 최종 관문이다.
9. **Commits** — 커밋은 Agent가 읽는다(아래 Commit Format). Task 완료마다 1커밋, 긴 Task는 step마다 WIP 커밋(`Wip:` trailer). 세션의 마지막은 `.ai/work/<내 스트림>/`·`docs/phases/`·`docs/decisions/`·`.claude/agent-memory/`만 담은 close commit이며, 커밋하지 않은 변경을 남긴 채 세션을 끝내지 않는다. main은 PR로만 바뀌고 병합은 merge commit이다(squash·rebase-merge 금지). push된 커밋은 rewrite하지 않는다. main 동기화는 `git merge main`이며 충돌 해결은 Touches 안에서만 하고 밖이면 멈추고 묻는다. close commit·open·WIP는 push한다 — push되지 않은 것은 팀에 없는 것이다.
10. **Interruption** — 중단(토큰·시간 소진, 오류)은 언제든 일어난다고 가정한다. Task 시작 시 HANDOFF의 Goal·Work In Progress를 먼저 쓰고(handoff-first), step마다 CURRENT의 Progress를 갱신하며, 큰 변경 전에는 HANDOFF를 먼저 갱신한다. 세션 안에 끝나지 않을 것 같으면 억지로 끝내지 말고 종료 절차로 간다.
11. **Resume** — 정상 종료 시 CURRENT의 Status를 IN_PROGRESS로 남기지 않는다. **내 스트림**의 IN_PROGRESS만 중단 신호다(남의 스트림의 IN_PROGRESS는 작업 중이라는 뜻). 시작 시 IN_PROGRESS를 보면: uncommitted diff가 HANDOFF의 Work In Progress·CURRENT의 Progress와 일치하면 그 step부터 잇고, 아니면 직접 수정으로 취급한다. 어느 쪽이든 test를 먼저 실행한다. REVIEW 상태에서 INBOX·새 커밋이 있으면 재작업이다(Status → IN_PROGRESS, 끝나면 다시 `--ready`). 남의 스트림은 `ai-stream.sh take` 후에만 잇는다.
12. **Context budget** — 파일은 필요한 부분만 읽고 긴 출력은 요약해서 남긴다. Relevant Source Files는 디렉터리가 아니라 파일·심볼 단위(`src/api/users.py:create_user`)로 적는다. 상한: CURRENT.md 50줄, HANDOFF.md 60줄, LOG 항목 8줄, Progress 10 step, `.ai/local/MEMORY.md` 50줄. `git log`는 맨몸으로 부르지 않는다.
13. **Conventions** — 포맷·린트는 도구 설정(`.editorconfig`, <linter/formatter 설정 파일>)을 따르고, 모듈 경계·의존성 방향·소유권은 `docs/ARCHITECTURE.md`를 따른다. 정해진 Stack 밖의 언어·런타임 도입은 ADR이 필요하다. 비밀값과 생성물은 커밋하지 않으며 `.ai/`·`.ai/local/`에도 적지 않는다. <!-- 스택 확정 후 언어별 규칙을 3줄 이내로 추가한다. 마지막 줄은 허용 언어 목록 (.ai/BOOTSTRAP.md의 Stack Constraints) -->
14. **Decisions** — 장기 영향이 있는 결정은 `docs/decisions/ADR-YYYYMMDD-<slug>.md`로 남긴다. `Status: Accepted`로 PR을 올리고 병합이 곧 승인이다. `docs/ARCHITECTURE.md`는 현재 구조만 기술하고, 과거 구조와 이유는 ADR에 둔다. 팀 전체가 행동해야 하는 변경(이 파일·ARCHITECTURE·API의 breaking 변경, 새 관례)은 같은 PR에 `.ai/team/announcements/` 공지를 넣는다.
15. **Streams** — 작업 단위는 스트림이다: 브랜치 `ws/<id>` = `.ai/work/<id>/` = 소유자 1명 = Task 1개(또는 spec/chore/plan/phase-close 1건). 스트림 파일은 소유자만 쓰고 한 스트림에는 세션 하나만 있다(`.lock`). 열기·인수·현황·정리는 `scripts/ai-stream.sh`로 하며 main에서 직접 작업하지 않는다. 팀 현황은 파일이 아니라 `ai-stream.sh status`가 도출한다. 역할 메모리(`.claude/agent-memory/`)는 `--ready` 단계의 close commit에서만 갱신하고, 개인 취향·교정은 `.ai/local/MEMORY.md`에 둔다.

## Commands

| Purpose   | Command                |
|-----------|------------------------|
| Install   | `<install command>`    |
| Test      | `<test command>`       |
| Typecheck | `<typecheck command>`  |
| Lint      | `<lint command>`       |
| Run       | `<run command>`        |

<!-- 템플릿 초기화 시 채운다. 해당 없는 항목은 N/A로 명시한다. -->

## Session Procedure

- **스트림이 없을 때**: `scripts/ai-stream.sh open <phase>/<task> <slug>` (spec/chore는 `open spec|chore <slug> --touches …`). 브랜치 `ws/<id>`와 `.ai/work/<id>/`가 생기고 push된다.
- **시작**: `scripts/ai-start.sh`를 실행하고 출력의 next steps를 따른다(Claude Code는 `.claude/settings.json`의 SessionStart 훅이 자동 실행해 출력을 컨텍스트에 넣는다 — 다른 Agent는 직접 실행) — Resume/재작업 판단 → 미확인 공지 → main 유입 spec 변경·직접 수정·INBOX 반영 → PLAN의 Task·Acceptance Criteria 확인 → CURRENT의 Status=IN_PROGRESS·Progress 작성과 HANDOFF 초안 → 구현.
- **종료**: test → typecheck → lint → 작업 커밋과 PLAN의 Task SHA 갱신 → CURRENT(Status≠IN_PROGRESS)·HANDOFF·LOG 갱신 → 필요 시 ADR·공지 → `scripts/ai-end.sh --set-checkpoint` → close commit → push.
- **Task 완료**: `git merge main` → `scripts/ai-end.sh --ready`(Status=REVIEW, PR 초안 출력; `--pr`로 생성) → 소유자가 PR 본문을 다듬어 올린다. Phase 완료는 Lead의 `ws/phase-NN-close` 스트림(RESULT·`ai-stream.sh phases`·`gc`)과 병합 후 `ai-stream.sh tag NN`.

## Commit Format

커밋 메시지는 **Agent가 읽는다** — 짧고 규격대로. 설명은 PR 본문(사람용)에 쓴다.

```text
<type>(<scope>): <summary>        # type: feat fix refactor test docs chore ai · scope: 구성요소 이름(부기는 스트림 id) · summary ≤ 60자, 영어, 명령형
                                  # (빈 줄) body는 키-값만, 최대 5줄, diff로 알 수 없는 것만: Why: / What: / Test:
Agent: claude-code                # trailer 키 고정 — Agent(에이전트 커밋만) · Task: 02/T3 · Stream: 02-T3-auth · Spec: yes|no · Refs: ADR-…, #41 · Wip: 남은 것 한 줄(WIP만)
```

- `commit-msg` 훅이 subject 문법·길이를 검사하고 `Stream:`(브랜치에서)·`Agent:`(`$AI_AGENT`)·`Spec:`(docs/ diff)를 자동으로 붙인다. 손으로 쓸 때: `git commit --trailer "Agent: claude-code" --trailer "Task: 02/T3"`.
- 스트림 부기 커밋(open·close·take·checkpoint)은 type `ai`, scope는 스트림 id: `ai(02-T3-auth): close 3/5 — token refresh tests`.
- Task 완료 커밋의 SHA를 PLAN에 적는다: `- [x] T3. ... (commit abc1234, PR #42)`. Task 완료 커밋에는 `Wip:`가 없다.
- PR 제목(사람용이자 merge commit의 subject): `<type>(<scope>): <summary> [<phase>/<task>]` — type에 `spec adr plan phase-close hotfix announce` 추가. PR 본문 끝의 trailer 블록(`Stream Task Spec Refs Announcement`)이 merge commit의 trailer가 된다.

## History

- 팀에서 일어난 일: `git ai-log --first-parent main -n 20` (PR당 한 줄, ≈ 20토큰/줄). 부기 제외: `--invert-grep --grep='^ai('`.
- 한 Task·스트림·에이전트: `git ai-log --grep='^Task: 02/T3'` · `--grep='^Stream: <id>'` · `--grep='^Agent: codex'`. spec 변경: `--grep='^Spec: yes'`.
- 파일·심볼: `git ai-log -n 10 -- <path>` · `git log -L :<symbol>:<file> --format=%h` · `git log -S '<text>' --format=%h -n 5`. diff 전에 `git show --stat --format='%h %s' <sha>`.
- 중단 지점: `git log -1 --format='%(trailers:key=Wip,valueonly)'`. 감싼 명령: `scripts/ai-stream.sh history --type|--scope|--phase|--task|--stream`. 전체 레시피는 `.ai/README.md`.
