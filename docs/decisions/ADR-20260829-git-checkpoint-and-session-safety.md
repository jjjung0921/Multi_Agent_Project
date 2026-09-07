# ADR-20260829-git-checkpoint-and-session-safety: git checkpoint 기반 변경 추적과 세션 중단 대비

- Status: Accepted
- Date: 2026-08-29
- Deciders: 프로젝트 소유자

## Context

ADR-20260829-repository-as-shared-memory의 문서 체계만으로는 두 가지 문제가 남는다.

1. 개발자가 세션 사이에 직접 코드·문서를 고쳐도 다음 Agent가 그 사실을 모르거나, 알아도 "무엇이 새로 바뀐 것인지" 전체 이력에서 골라내야 한다. 모든 Agent가 같은 개발자 계정으로 커밋하므로 author만으로는 Agent 커밋과 개발자 커밋을 구분할 수 없다.
2. Agent 세션은 토큰·시간 소진이나 오류로 예고 없이 끊긴다. 종료 시점에만 CURRENT/HANDOFF를 쓰면 중단된 세션의 작업은 uncommitted 상태로 남고, 다음 Agent는 그것이 개발자 변경인지 중단된 작업인지 판단할 수 없다.

또한 개발자는 Agent가 무엇을 했는지 대화 로그가 아니라 한 곳에서 짧게 확인하고 싶어 한다.

## Problem

Agent와 개발자의 변경을 서로 구분해 추적하고, 세션이 언제 끊겨도 저장소만으로 재개할 수 있으며, 개발자가 작업 현황을 최소 비용으로 확인할 수 있는 구조를 어떻게 만들 것인가.

## Alternatives

변경 추적:

1. **개발자가 변경 내역을 직접 신고** (문서에 수동 기록) — Agent 부담은 없지만 개발자가 잊으면 추적이 끊긴다.
2. **git ref/tag를 checkpoint로 사용** (`refs/ai/checkpoint`를 세션마다 이동) — 파일 변경이 없어 깔끔하지만 눈에 보이지 않고, clone 간 동기화와 웹 채팅 Agent 접근이 어렵다.
3. **CURRENT.md에 checkpoint SHA 기록 + 커밋 trailer로 Agent 식별** — 파일이라 누구나 읽고 diff로 검토할 수 있고, `git log <checkpoint>..HEAD` 한 번으로 새 변경만 본다.
4. **Task별 브랜치와 PR** — 리뷰 UI는 좋지만 로컬에서 여러 Agent가 같은 clone을 쓰는 흐름에 절차가 많다.

중단 대비:

- a. **세션 종료 시에만 문서 갱신** (현행) — 단순하지만 중단 시 상태가 사라진다.
- b. **진행 중 checkpoint: Progress 체크리스트 + WIP 커밋 + handoff-first** — 문서·커밋 비용이 조금 늘지만 어느 시점에 끊겨도 재개 가능하다.
- c. **`git stash`로 임시 저장** — 로컬 전용이고 보이지 않아 다음 Agent가 발견하지 못한다.

## Decision

3과 b를 채택한다.

- 모든 Agent 커밋에 `Agent: <이름>`, `Task: <phase>/<task>` trailer를 붙인다. trailer가 없는 커밋과 uncommitted 변경은 개발자 변경으로 간주한다.
- `.ai/CURRENT.md`의 Last Checkpoint에 Agent가 마지막으로 처리한 커밋을 기록하고, 세션 시작 시 그 이후만 확인한다 (`scripts/ai-start.sh`).
- 커밋 단위는 Task이며, 긴 Task는 step마다 WIP 커밋한다. 세션의 마지막은 `.ai/`·docs만 담은 close commit이다. Task 완료 커밋의 SHA는 PLAN.md에, Phase 완료는 `phase/NN` 태그로 기록한다.
- Task 시작 시 HANDOFF 초안을 먼저 쓰고(handoff-first), CURRENT.md의 Progress를 step마다 갱신한다. 정상 종료된 세션은 Status를 IN_PROGRESS로 남기지 않으므로, IN_PROGRESS는 곧 "중단된 세션" 신호다.
- 개발자 보고는 `.ai/LOG.md`(최신순, 세션당 8줄 이내), 개발자 지시는 `.ai/INBOX.md`로 채널을 분리한다.
- 절차 준수는 `scripts/ai-start.sh`, `scripts/ai-end.sh`(bash + git만 사용)로 점검한다.

## Rationale

- checkpoint를 파일에 두면 웹 채팅 Agent나 사람도 같은 정보를 보고, 갱신 자체가 커밋 이력에 남아 검증할 수 있다. ref 방식의 장점(파일 변경 없음)보다 가시성이 중요하다.
- trailer는 git이 표준으로 파싱(`%(trailers:key=...)`, `--trailer`)하므로 스크립트가 단순하고 스택에 의존하지 않는다.
- WIP 커밋은 히스토리를 조금 어지럽히지만, 중단된 작업을 저장소에 남기는 가장 확실한 방법이다. squash는 checkpoint SHA를 무효화하므로 push 이후에는 하지 않는다.
- LOG와 HANDOFF를 분리한 이유: 독자가 다르다. HANDOFF는 재개용 상세, LOG는 개발자용 요약이며 Phase 종료 시 정리해 짧게 유지한다.

## Consequences

- 긍정: 개발자 변경이 자동으로 분류되어 "되돌림" 사고가 구조적으로 줄어든다. 어느 시점에 세션이 끊겨도 CURRENT.md Progress + HANDOFF + WIP 커밋으로 재개한다. 개발자는 `.ai/LOG.md` 맨 위만 읽으면 된다.
- 부정 / 감수한 것: 커밋 수가 늘고, Agent가 trailer·checkpoint·LOG 갱신을 빠뜨리면 추적이 흐려진다(`ai-end.sh`가 대부분 잡아낸다). 스크립트는 bash 기준이므로 Windows는 Git Bash/WSL이 필요하다.
- 후속 작업: 새 Agent를 도입하면 trailer 규칙을 지키는지 첫 세션에서 확인한다. Phase 완료 시 LOG의 해당 항목을 정리한다.
