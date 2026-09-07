# Architecture — <프로젝트 이름>

<!--
현재 유효한 시스템 구조의 source of truth.
- "현재" 구조만 기술한다. 과거 구조와 결정 이유는 docs/decisions/(ADR)에 둔다.
- 구조가 바뀌면 같은 변경에서 이 문서를 갱신한다. 이 문서와 코드가 다르면 AGENTS.md의 Source of Truth Priority에 따라 inconsistency로 보고한다.
- 상세 API 계약은 docs/api/에 둔다. 여기서는 참조만 한다.
- 아직 정해지지 않은 항목은 "TBD (ADR-… 예정)"으로 표시한다.
- Module Boundaries 표의 Owner 열이 소유권의 source of truth다. `scripts/ai-stream.sh codeowners`가 이 표에서 .github/CODEOWNERS를 만든다.
-->

- Last updated: <YYYY-MM-DD>
- Related ADRs: <ADR-YYYYMMDD-slug, ...>

## System Overview

<시스템이 무엇을 하고, 어떤 큰 덩어리로 이루어지며, 외부와 어떻게 연결되는지 한 문단.>

```text
<간단한 박스 다이어그램 (또는 mermaid)>
```

## Major Components

| Component | Responsibility      | Location      |
|-----------|---------------------|---------------|
| <이름>    | <책임 한 줄>        | `src/<path>`  |

## Module Boundaries

<!-- 한 행이 소유권 단위다. Location은 경로 접두(PLAN의 Touches와 같은 표기), Owner는 GitHub 핸들(@name) 또는 이메일 — 사람이 여럿이면 쉼표. docs/ 행의 Owner는 리드. -->

| Module   | Owns (책임)          | Location        | Owner     | Allowed access (허용 인터페이스)      |
|----------|----------------------|-----------------|-----------|---------------------------------------|
| <이름>   | <소유하는 것>        | `src/<path>/`   | @<handle> | <다른 모듈이 쓸 수 있는 인터페이스>   |
| docs     | spec · ADR · Phase   | `docs/`         | @<lead>   | PR 리뷰                               |

<각 모듈이 소유하지 않는 것, 모듈 간 접근이 허용되는 인터페이스를 표 아래에 보충한다.>

## Dependency Direction

<허용되는 의존 방향. 예: `api → service → domain ← infra`. 금지 규칙(순환, 계층 건너뛰기 등).>

## Data Flow

<대표 시나리오 1~3개의 흐름. 입력 → 처리 → 저장/출력.>

## State Management

<상태가 어디에 있고(클라이언트/서버/캐시), 누가 소유하며, 어떻게 동기화되는가.>

## Persistence

<저장소 종류, 스키마·마이그레이션 위치, 트랜잭션 경계, 백업 정책.>

## External Systems

| System     | Purpose  | Interface        | Failure Handling         |
|------------|----------|------------------|--------------------------|
| <서비스명> | <용도>   | <REST/SDK/큐>    | <타임아웃·재시도·폴백>   |

## Important Interfaces

- REST API: `docs/api/openapi.yaml`
- <이벤트/메시지 스키마, CLI, 플러그인 인터페이스 등과 그 spec 위치>

## Cross-cutting Concerns

<인증/인가, 설정(config)·환경변수, 로깅, 에러 처리, 관측성. 각 항목 1~2줄.>
