# Phases

<!--
전체 개발 계획의 Phase 목록. 아래 표는 각 NN-<name>/PLAN.md 머리(Status·Lead·Depends on)와 Tasks 체크박스에서 `scripts/ai-stream.sh phases` 가 생성한다 — 손으로 고치지 않는다 (`ai-end.sh --ci` 가 어긋나면 FAIL).
- Phase 열기: `scripts/ai-stream.sh phase new <name>` (원격의 최대 NN + 1, 계획 스트림 ws/plan-NN-<name>).
- 지금 진행 중인 Task는 각 스트림의 CURRENT.md 가 기준이다. 활성 스트림은 `scripts/ai-stream.sh status`.
-->

<!-- phases:begin -->
| #  | Phase | Lead | Depends on | Status | Tasks | Result |
|----|-------|------|------------|--------|-------|--------|
| 01 | [project-setup](01-project-setup/PLAN.md) | <email 또는 @handle> | none | PLANNED | 0/6 | — |
<!-- phases:end -->

## Phase Rules

- 한 Phase는 독립적으로 검증 가능한 하나의 결과를 낸다. 결과를 한 문장으로 말할 수 없으면 나눈다.
- Phase들은 `Depends on`으로 이어진 그래프다. 의존이 없는 Phase는 사람별·구성요소별로 **동시에** 진행할 수 있고, Phase마다 Lead 한 명이 있다.
- Task 하나 = 스트림 하나(`ws/NN-Tk-<slug>`). 한 Task를 다시 열어야 하면 `ai-stream.sh open --reopen`.
- Phase 종료 조건: PLAN의 Acceptance Criteria 전부 충족 + Validation Plan 수행 + `Depends on`의 Phase가 DONE + 그 Phase의 활성 스트림 없음 + RESULT.md 작성. Lead가 `ws/phase-NN-close` 스트림에서 RESULT 작성 → PLAN Status=DONE → `ai-stream.sh phases` → `ai-stream.sh gc` → PR. 병합 후 `ai-stream.sh tag NN`.
