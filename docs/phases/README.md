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

## Traceability

<!--
요구사항 → Task → 스트림 추적 표. 각 PLAN 의 Task 줄 `Refs:` 와 스트림(main 의 .ai/work/, 활성 ws/*)에서 `scripts/ai-stream.sh trace` 가 생성한다 — 손으로 고치지 않는다 (`ai-end.sh --ci` 가 어긋나면 FAIL).
- Ref 열: PRD 의 FR/NFR(PRD 표 순서) → 그 외 참조(ADR 등) → `none`(요구사항 없는 Task) → `—`(Refs 가 없는 Task — PLAN 에 적어야 한다). `— 미배정` = 아직 어떤 Task 도 맡지 않은 요구사항.
- PRD 는 이 표를 링크만 한다. 상태(Task·스트림)는 spec 에 쓰지 않는다 — PLAN 과 브랜치에서 도출한다.
-->

<!-- trace:begin -->
| Ref | Phase/Task | 상태 | 스트림 | PR · commit |
|-----|------------|------|--------|-------------|
| FR-1 | — 미배정 | | | |
| FR-2 | — 미배정 | | | |
| NFR-1 | — 미배정 | | | |
| none | [01/T1](01-project-setup/PLAN.md) — `.ai/BOOTSTRAP.md` 수행 | open |  |  |
| none | [01/T2](01-project-setup/PLAN.md) — 스택·핵심 도구 결정 후 ADR 작성 | open |  |  |
| none | [01/T3](01-project-setup/PLAN.md) — 제약 층 구성 (T1에서 적은 설정 파일·버전 고정·lockfile·`.gitignore` 목록대로) | open |  |  |
| none | [01/T4](01-project-setup/PLAN.md) — 최소 실행 스켈레톤 + 테스트 | open |  |  |
| none | [01/T5](01-project-setup/PLAN.md) — CI에서 install/test/typecheck/lint + `ai-end.sh --ci` 실행 | open |  |  |
| none | [01/T6](01-project-setup/PLAN.md) — Phase 02(이후) PLAN 초안과 Phase 그래프 | open |  |  |
<!-- trace:end -->

## Phase Rules

- 한 Phase는 독립적으로 검증 가능한 하나의 결과를 낸다. 결과를 한 문장으로 말할 수 없으면 나눈다.
- Phase들은 `Depends on`으로 이어진 그래프다. 의존이 없는 Phase는 사람별·구성요소별로 **동시에** 진행할 수 있고, Phase마다 Lead 한 명이 있다.
- Task 하나 = 스트림 하나(`ws/NN-Tk-<slug>`). 한 Task를 다시 열어야 하면 `ai-stream.sh open --reopen`.
- Phase 종료 조건: PLAN의 Acceptance Criteria 전부 충족 + Validation Plan 수행 + `Depends on`의 Phase가 DONE + 그 Phase의 활성 스트림 없음 + RESULT.md 작성. Lead가 `ws/phase-NN-close` 스트림에서 RESULT 작성 → PLAN Status=DONE → `ai-stream.sh phases` → `ai-stream.sh gc` → PR. 병합 후 `ai-stream.sh tag NN`.
