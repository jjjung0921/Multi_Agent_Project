# PRD — <프로젝트 이름>

<!--
제품 관점의 요구사항 문서. "무엇을, 왜"를 다루고 "어떻게(구현)"는 docs/ARCHITECTURE.md에 둔다.
- 요구사항마다 ID를 붙여 Phase PLAN의 Task 줄 `Refs:`·테스트·ADR에서 참조한다 (FR-1, NFR-1 ...). 어느 Task·스트림이 맡았는지는 여기 쓰지 않는다 — docs/phases/README.md의 추적 표가 PLAN에서 도출한다.
- 요구사항이 바뀌면 이 문서를 먼저 고치고, 영향을 받는 Phase PLAN을 갱신한다.
- Status: Draft → Approved. Approved 이후의 변경은 git 이력으로 추적한다.
-->

- Status: Draft
- Last updated: <YYYY-MM-DD>
- Trace: [docs/phases/README.md — Traceability](phases/README.md#traceability) (FR/NFR → Task → 스트림, 생성 표)

## Problem

<해결하려는 문제. 누가, 어떤 상황에서, 무엇 때문에 불편한가.>

## Goals

- G1. <측정 가능한 목표>
- G2. <...>

## Target Users

- <사용자 유형 1>: <특징·상황·기대>
- <사용자 유형 2>: <...>

## User Stories

- US-1. <사용자>로서 <목적>을 위해 <행동>을 하고 싶다.
- US-2. <...>

## Functional Requirements

| ID   | Requirement                  | Priority | Related |
|------|------------------------------|----------|---------|
| FR-1 | <시스템은 ...해야 한다>       | Must     | US-1    |
| FR-2 | <...>                        | Should   |         |

<!-- Priority: Must / Should / Could. 구현 방식은 적지 않는다. -->

## Non-functional Requirements

| ID    | Requirement                          | Target            |
|-------|--------------------------------------|-------------------|
| NFR-1 | <성능·보안·가용성·접근성·호환성 등> | <수치 또는 기준>  |

## Constraints

- <기술·법·일정·예산·플랫폼 등 바꿀 수 없는 제약>

## Non-goals

- <이번 제품 범위에서 의도적으로 제외하는 것과 그 이유>

## Success Criteria

- <출시/완료 판단 기준. Goals와 1:1로 대응되게 적는다>
