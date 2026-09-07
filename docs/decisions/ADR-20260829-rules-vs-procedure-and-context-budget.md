# ADR-20260829-rules-vs-procedure-and-context-budget: AGENTS.md 규칙·절차 분리와 컨텍스트 예산

- Status: Accepted
- Date: 2026-08-29
- Deciders: 프로젝트 소유자

## Context

ADR-20260829-git-checkpoint-and-session-safety까지 반영한 시점의 `AGENTS.md`는 139줄, 규칙성 문장 70개였고, 세션 시작 시 필수로 읽는 컨텍스트(AGENTS + CURRENT + HANDOFF + 현재 PLAN + 스크립트 출력)는 약 18KB였다. 토큰 양으로는 200K 컨텍스트의 3~4%라 문제가 아니지만, 세 가지 희석 요인이 있었다.

1. 규칙 수 — 모델은 지시가 많아질수록 개별 지시의 준수율이 떨어진다. 절차의 세부 단계가 규칙과 섞여 있어 정작 불변 규칙(되돌리지 마라, Scope 밖 금지, 커밋 없이 끝내지 마라)의 무게가 줄었다.
2. 상한 없는 파일 — `HANDOFF.md`, `CURRENT.md`의 Recent Important Changes·Progress는 성실한 Agent일수록 길어진다.
3. 중복 읽기 — CLAUDE.md·GEMINI.md가 `AGENTS.md`를 자동 로드하는 도구에서 "AGENTS.md를 읽어라" 규칙 때문에 같은 내용이 두 번 들어가고, `.ai/` 파일의 작성 지침 주석(2.4KB)이 매 세션 반복된다.

## Problem

읽는 양을 늘리지 않으면서 규칙 준수율을 유지하고, 상태 파일이 세션을 거듭해도 커지지 않게 하려면 어떻게 구성할 것인가.

## Alternatives

1. **AGENTS.md를 여러 파일로 분할** (rules.md, workflow.md …) — 파일당은 짧아지지만 읽어야 할 hop이 늘어 누락이 잦아진다.
2. **요약 파일 추가** (AGENTS-SHORT.md 등) — 정보원이 중복되어 drift한다.
3. **규칙과 절차의 분리 + 상한** — `AGENTS.md`는 판단 규칙만 남기고, 시작·종료 절차의 세부 단계는 `scripts/ai-start.sh`·`ai-end.sh` 출력이 그 시점에 안내한다. 상태 파일에는 상한을 두고 스크립트가 경고한다.

## Decision

3안을 채택한다.

- `AGENTS.md`: Rules 14개(굵은 키워드로 시작) + Session Procedure 2줄 + Commit Format. 도구가 이미 로드했으면 다시 읽지 않는다.
- 절차 안내: `ai-start.sh`가 상황에 맞는 next steps를 출력한다(중단된 세션에만 Resume, 개발자 변경·INBOX가 있을 때만 반영 단계). `ai-end.sh`가 종료 점검과 상한 경고를 한다.
- 상한: `CURRENT.md` 50줄, `HANDOFF.md` 60줄, LOG 항목 8줄, Progress 10 step, Recent Important Changes 5개. 시작 컨텍스트가 25KB를 넘으면 `ai-start.sh`가 경고한다.
- `.ai/` 파일의 작성 지침 주석은 1~2줄로 제한한다.
- Relevant Source Files는 디렉터리가 아니라 파일·심볼 단위로 적는다.

## Rationale

- 희석은 토큰 총량보다 "지금 필요 없는 지시의 비율"에서 온다. 절차를 실행 시점에 스크립트로 주입하면 필요한 단계만 컨텍스트에 들어온다.
- 스크립트 출력은 상황에 따라 달라지므로 문서에 모든 경우를 나열하는 것보다 정확하고 짧다.
- 상한은 기계적으로 검사할 수 있어 Agent마다 다른 "짧게"의 해석을 통일한다.
- 분할이나 요약 파일은 hop과 중복을 늘려 원래 문제를 다른 형태로 옮길 뿐이다.

## Consequences

- 긍정: 시작 컨텍스트가 세션을 거듭해도 일정하게 유지되고, 핵심 규칙이 한눈에 들어온다. `AGENTS.md` 139줄 → 59줄, `.ai/` 주석 2.4KB → 1.1KB.
- 부정 / 감수한 것: 절차를 바꾸려면 `AGENTS.md`의 Session Procedure와 스크립트를 함께 고쳐야 한다. bash를 실행할 수 없는 환경(웹 채팅)에서는 사람이 스크립트 출력을 붙여 넣어야 한다.
- 후속 작업: `AGENTS.md`에 규칙을 추가할 때는 기존 규칙과 합치거나 제거해 15개 안팎을 유지한다.
