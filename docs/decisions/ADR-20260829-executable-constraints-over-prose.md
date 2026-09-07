# ADR-20260829-executable-constraints-over-prose: 제약은 실행 가능한 도구로 — 계약은 고정, 도구·구성은 자유

- Status: Accepted
- Date: 2026-08-29
- Deciders: 프로젝트 소유자

## Context

이 템플릿은 스택 비의존이라 언어·저장소 구성이 프로젝트마다 다르다. 언어가 바뀔 때 "어떤 제약을 어떻게 걸 것인가"가 초기화 Agent의 재량에 맡겨져 있었고, 루트 `src/`·`tests/`가 고정되어 backend / frontend / db / infra가 한 저장소에 있는 경우 잘못된 구조를 유도했다. 또한 Agent는 "타입을 명시하라" 같은 프로즈 규칙보다 실패하는 명령을 훨씬 잘 따른다는 점이 Rule 2(executable spec 우선)에 이미 반영되어 있다.

## Problem

언어·구성이 무엇이든 같은 수준의 제약이 걸리게 하되, 도구 선택과 디렉터리 구성은 프로젝트에 맞게 바꿀 수 있으려면 무엇을 고정하고 무엇을 열어 둘 것인가.

## Alternatives

1. **언어별 템플릿 분기** (template-python, template-ts …) — 각각은 정확하지만 규칙 변경을 N벌 유지해야 하고 polyglot을 못 다룬다.
2. **AGENTS.md에 언어별 규칙을 길게 서술** — 컨텍스트 예산(ADR-20260829-rules-vs-procedure-and-context-budget)을 깨고, 프로즈 규칙은 준수율이 낮다.
3. **계약과 프리셋의 분리** — 충족해야 할 계약(경고 없이 통과하는 4개 명령, 버전 고정·lockfile·설정 파일 커밋, 언어 규칙 ≤ 3줄 + 허용 언어 목록, CI)은 Phase 01 PLAN의 Acceptance Criteria로 고정하고, 언어별 프리셋과 구성(Layout) 절차는 초기화 후 삭제되는 `.ai/BOOTSTRAP.md`에 둔다.

## Decision

3안을 채택한다.

- 계약은 `docs/phases/01-project-setup/PLAN.md`의 AC2·AC6·AC7이며 언어와 무관하다. Rule 8에 "경고 없이", Rule 13에 "정해진 Stack 밖 언어·런타임 도입은 ADR 필요"를 추가한다.
- `.ai/BOOTSTRAP.md`의 Stack Constraints 절이 Layout(단일 패키지 vs 구성요소별 디렉터리) → Preset → AGENTS.md → PLAN T3 구체화 절차와 언어·구성요소별 프리셋(Python, TypeScript, Go, Rust, Java/Kotlin, C#, Ruby, Dart, DB, Infra), Weak types, Polyglot 지침을 담는다. 프리셋은 출발점이고 도구는 바꿀 수 있으며, 바꾼 이유는 스택 ADR에 남긴다.
- 루트 `src/`·`tests/`는 단일 패키지 기본값이다. 구성요소가 여럿이면 삭제하고 구성요소 디렉터리로 바꾸며, Commands는 루트 Makefile/justfile 타깃으로 묶어 Agent에게 인터페이스 하나만 보인다. 구성요소 간 의존은 ARCHITECTURE의 Module Boundaries에 적는다.
- 스타일·정적 검사 규칙은 도구 설정 파일에만 두고 AGENTS.md에는 도구가 잡지 못하는 것만 3줄 이내로 쓴다.

## Rationale

- Agent가 어긴 규칙은 사람이 리뷰에서 잡아야 하지만, 실패하는 명령은 Agent가 스스로 고친다. 제약을 도구에 두면 준수율과 검증 비용이 동시에 좋아진다.
- 경고를 실패로 설정하지 않으면 Agent는 경고를 무시한다. "경고 없이"는 계약의 핵심이다.
- 계약을 PLAN의 AC로 두면 BOOTSTRAP이 삭제된 뒤에도 T3의 완료 기준이 남는다. 프리셋은 한 번만 읽히므로 길어도 컨텍스트 예산을 해치지 않는다.
- 도구 통일 인터페이스(4개 명령)가 있으면 스크립트·CI·규칙이 언어를 몰라도 된다.

## Consequences

- 긍정: 언어·구성이 달라도 제약 수준이 같고, 프리셋 덕에 초기화가 빨라진다. polyglot 저장소도 인터페이스 하나로 다룬다.
- 부정 / 감수한 것: 프리셋의 도구 버전·옵션은 시간이 지나면 낡는다. 초기화 Agent가 현재 버전을 확인해야 한다. Makefile/justfile이라는 간접 층이 하나 늘어난다.
- 후속 작업: 새 언어·구성요소를 자주 쓰게 되면 프리셋을 추가한다. 프리셋 변경은 BOOTSTRAP.md에만 반영한다(AGENTS.md는 건드리지 않는다).
