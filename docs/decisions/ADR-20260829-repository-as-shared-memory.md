# ADR-20260829-repository-as-shared-memory: 저장소를 AI Agent 간 공유 메모리로 사용

- Status: Accepted
- Date: 2026-08-29
- Deciders: 프로젝트 소유자

## Context

이 프로젝트는 Claude Code, Codex, Gemini CLI, ChatGPT 등 여러 AI Agent가 교대로 작업한다. 각 Agent는 서로의 대화 기억을 공유하지 않으며, 같은 Agent라도 세션이 끝나면 문맥이 사라진다. 그 결과 (1) 같은 설명을 매 세션 반복하고, (2) Agent마다 다른 규칙으로 작업하며, (3) 개발자가 직접 고친 코드나 결정을 다음 Agent가 모르고 되돌리고, (4) 구현이 spec과 조용히 어긋나는 문제가 생긴다.

## Problem

Agent와 세션이 바뀌어도 프로젝트의 현재 상태, 설계 의도, 개발 계획, 작업 규칙이 유지되고, 새 Agent가 최소한의 문서만 읽고 작업을 이어갈 수 있으려면 정보를 어디에, 어떤 구조로 두어야 하는가.

## Alternatives

1. **도구별 설정 파일에 규칙을 각각 작성** (CLAUDE.md, GEMINI.md, .cursorrules 등에 전체 규칙 복사) — 도구별 최적화는 쉽지만 규칙이 곧 서로 어긋난다.
2. **대화 기록·외부 노트 도구(위키, Notion 등)에 의존** — 작성은 편하지만 저장소 밖에 있어 Agent가 자동으로 읽지 못하고, 코드 변경과 함께 버전 관리되지 않는다.
3. **단일 대형 문서에 모든 것을 기록** (하나의 CLAUDE.md에 규칙·설계·이력·상태를 누적) — 초기에는 단순하지만 프로젝트가 커질수록 매 세션 전체를 읽어야 하고, 오래된 정보와 현재 정보가 섞인다.
4. **저장소 안에 역할별로 계층화된 문서 체계** — 규칙(`AGENTS.md`), 장기 지식(`docs/`), 단기 상태(`.ai/`)를 분리하고, 진입점에서 필요한 문서만 지정한다.

## Decision

4안을 채택한다.

- `AGENTS.md`가 유일한 공통 규칙이며, `CLAUDE.md`·`GEMINI.md`는 이를 import만 한다.
- 장기 지식은 `docs/`에 둔다: `PRD.md`(요구사항), `ARCHITECTURE.md`(현재 구조), `api/`(machine-readable spec), `phases/`(Phase별 PLAN/RESULT), `decisions/`(ADR).
- 단기 상태는 `.ai/`에 둔다: `CURRENT.md`(현재 Phase·Task·다음 행동), `HANDOFF.md`(세션 인수인계, 덮어쓰기), `notes/`(임시 메모).
- 정보 충돌 시 우선순위와 context loading 순서는 `AGENTS.md`에 정의한다.
- 개발자의 직접 변경은 git 이력(`status`/`diff`/`log`)으로 감지하고, AI는 이를 되돌리지 않는다.

## Rationale

- 저장소는 모든 Agent와 개발자가 공통으로 접근하는 유일한 매체이고, git으로 버전·이력·diff가 관리된다.
- 규칙을 한 파일에만 두면 Agent 간 drift가 구조적으로 불가능해진다. 주요 CLI Agent는 `AGENTS.md`를 직접 읽거나(Codex) import 문법을 지원한다(Claude Code `@AGENTS.md`, Gemini CLI `@./AGENTS.md`).
- 장기/단기 분리로 `CURRENT.md`와 `HANDOFF.md`는 항상 짧게 유지되고, `docs/`는 세션마다 다시 쓰이지 않는다. 이것이 progressive context loading의 전제다.
- Phase 단위 PLAN/RESULT는 Scope를 명시적으로 만들어 AI의 임의 확장을 막고, 완료 판정을 검증 가능하게 한다.
- ADR이 "왜"를 보존하므로 `ARCHITECTURE.md`는 현재 구조만 기술하면 된다.

## Consequences

- 긍정: 어떤 Agent든 `AGENTS.md` → `.ai/CURRENT.md` → 지정 문서 순서로 최소 context만 읽고 작업을 재개할 수 있다. 개발자 결정과 spec이 대화보다 우선하는 것이 구조적으로 보장된다.
- 부정 / 감수한 것: 매 세션 종료 시 `CURRENT.md`·`HANDOFF.md` 갱신 비용이 든다. 갱신하지 않으면 체계 전체가 빠르게 무용해지므로 End of Work 절차 준수가 필수다.
- 후속 작업: 새 Agent·도구를 도입할 때 진입점 파일(또는 설정)에서 `AGENTS.md`를 참조하게 한다. 프로젝트별 추가 spec(DB 스키마, 이벤트 등)은 `docs/` 아래에 두고 `AGENTS.md`의 Repository Map과 Source of Truth Priority에 반영한다.
