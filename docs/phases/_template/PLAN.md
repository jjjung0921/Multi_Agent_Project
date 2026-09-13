# Phase NN — <phase-name>

<!--
새 Phase 시작 시 작성한다(`scripts/ai-stream.sh phase new <name>` 이 이 양식을 복사한다). Scope가 곧 AI의 작업 허용 범위이므로 구체적으로 적는다.
머리의 Status·Lead·Depends on 은 docs/phases/README.md 표의 원천이다 (`ai-stream.sh phases` 가 생성). Status 는 Phase 시작·종료 시에만 바꾼다.
Task는 한 스트림(한 세션~몇 세션, PR 하나)에 끝나고 독립적으로 검증 가능한 크기로 나눈다. Task 항목 사이에는 빈 줄을 둔다 — 인접 줄 변경은 git이 충돌시키므로.
새 Task 추가는 계획 PR(Lead)로만 한다. 집계 줄(완료 n/m)을 두지 않는다.
-->

- Status: PLANNED | IN_PROGRESS | DONE
- Lead: <email 또는 @handle>
- Depends on: none | NN, NN
- Start: <YYYY-MM-DD> · End: <YYYY-MM-DD>

## Goal

<이 Phase가 끝났을 때 참이 되어야 하는 한 문장.>

## Motivation

<왜 지금 이 Phase인가. 어떤 요구사항(FR/NFR)·문제를 해결하는가.>

## Scope

- <포함되는 작업·컴포넌트·기능>

## Out of Scope

- <이번 Phase에서 하지 않는 것. 하고 싶어지기 쉬운 것일수록 명시한다>

## Dependencies

- <선행 Phase·Task(`03/T2` 형식), 외부 서비스, 개발자 결정 대기 항목>

## Tasks

<!-- 형식: `- [ ] Tk. <작업> — Done when: <조건> · Touches: <경로 접두, spec 조각> · Owner: <email|미정> · Refs: <FR-n, NFR-n | none>`
Touches 는 ai-stream.sh open 이 CURRENT.md 로 복사하고 겹침 경고에 쓴다. Owner 는 사전 배정(선택) — 실제 소유는 스트림의 존재로 표현된다.
Refs 는 이 Task 의 부모 — PRD 의 FR/NFR ID(쉼표 구분). 요구사항에서 나오지 않은 Task(설정·유지보수·ADR 후속·Known Problems)는 `none`. `scripts/ai-stream.sh trace` 가 이 필드로 docs/phases/README.md 의 추적 표(FR → Task → 스트림)를 만든다.
완료 시 [x]로 바꾸고 완료 커밋 SHA와 PR 번호를 끝에 적는다: `(commit abc1234, PR #42)` -->

- [ ] T1. <작업> — Done when: <검증 가능한 완료 조건> · Touches: `src/<path>/`, `docs/api/openapi.yaml#/<path>` · Owner: 미정 · Refs: FR-1

- [ ] T2. <...> — Done when: <...> · Touches: <...> · Owner: 미정 · Refs: <...>

## Relevant Specifications

- `docs/PRD.md` — <FR-x, NFR-y>
- `docs/ARCHITECTURE.md` — <해당 섹션>
- `docs/api/openapi.yaml` — <해당 경로>
- `docs/decisions/ADR-YYYYMMDD-*.md`

## Acceptance Criteria

- [ ] AC1. <외부에서 관찰 가능한 조건>
- [ ] AC2. <...>

## Validation Plan

- <자동 테스트: 어떤 테스트가 어떤 AC를 덮는가>
- <수동 확인: 절차와 기대 결과>
- <NFR 검증: 성능·보안 등의 측정 방법>
