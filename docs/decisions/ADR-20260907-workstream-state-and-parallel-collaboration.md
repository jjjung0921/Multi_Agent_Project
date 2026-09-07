# ADR-20260907: 스트림 단위 단기 상태와 브랜치·PR 병렬 협업

- Status: Accepted
- Date: 2026-09-07
- Deciders: 템플릿 소유자

## Context

개인용 템플릿(ADR-20260829-repository-as-shared-memory ~ executable-constraints-over-prose)은 `.ai/`에 저장소당 하나뿐인 상태 파일(`CURRENT.md`·`HANDOFF.md`·`LOG.md`·`INBOX.md`)을 두고, checkpoint 하나·선형 히스토리·"trailer 없는 커밋 = 개발자 한 명의 수정"·"진행 중 Phase 하나"·"IN_PROGRESS = 끊긴 세션"을 전제했다. 여러 개발자가 각자 AI Agent와 함께 브랜치에서 동시에 작업하면 (1) 세션마다 갱신되는 상태 파일이 매 병합에서 충돌하고, (2) 충돌 없이 병합돼도 남의 checkpoint·Progress·IN_PROGRESS를 내 것으로 읽어 의미가 깨지며, (3) '내 수동 수정'과 '동료의 작업'을 구분하지 못하고, (4) `docs/`(spec·PLAN·ADR)를 두 사람이 동시에 다른 방향으로 고칠 수 있다.

## Problem

개인용 템플릿의 원칙(규칙 SSoT · 장기/단기 분리 · Truth 순서 · 개발자 우선 · 중단 내성 · 컨텍스트 예산 · 규칙/절차/제약 분리 · 채널 분리 · Phase 계획 · 커밋 추적)을 그대로 지키면서, 단기 상태와 절차가 브랜치·PR·병합 히스토리에서도 성립하고 spec의 의미 충돌까지 다루려면 무엇을 바꿔야 하는가.

## Alternatives

1. **상태를 브랜치에만 두고 병합 전 삭제** — main이 깨끗하지만 완료 기록이 PR에만 남고 재작업 시 상태를 다시 만들어야 한다.
2. **사람 단위 디렉터리** `.ai/people/<name>/` — 충돌은 없애지만 한 사람의 병렬 스트림, 사람 간 인수인계, 브랜치와의 1:1 대응이 안 된다.
3. **외부 트래커(Issues/Projects)에 상태** — Agent가 자동으로 읽지 못하고 코드와 함께 버전 관리되지 않는다(ADR-20260829-repository-as-shared-memory의 2안과 같은 이유).
4. **싱글턴 `.ai/` 유지 + merge driver(union/ours)** — git 충돌은 사라지지만 의미 붕괴(남의 checkpoint)는 그대로다. 문제의 본질은 병합 충돌이 아니라 싱글턴 의미론이다.
5. **squash merge** — 히스토리는 깨끗하지만 trailer·WIP·checkpoint SHA가 main에서 사라져 추적 체계가 무너진다.
6. **스트림 단위 디렉터리 + merge commit** — 아래 Decision.

## Decision

6안을 채택한다.

- **스트림**: 브랜치 `ws/<id>` = `.ai/work/<id>/` = 소유자 1명 = Task 1개(또는 spec/chore/plan/phase-close 1건). `CURRENT.md`(Owner·Task·Touches·Acked·checkpoint 포함)·`HANDOFF.md`·`LOG.md`·`INBOX.md`·`notes/`는 전부 스트림 안에 있다. 스트림 파일은 소유자만 쓰고(`ai-end.sh --ci`가 검사) 한 스트림에는 세션 하나만 있다(`.lock`). 병합된 스트림 디렉터리는 main에 남아 기록이 되고 Phase 종료 시 `gc`로 정리한다. 인수는 `ai-stream.sh take`(Owner 변경 커밋), 재개는 `open --reopen`(`-r2`, `Supersedes:`).
- **저장소 수준 공유 상태는 단일 작성자 또는 write-once 파일만**: `.ai/team/announcements/<date>-<slug>.md`(공지, 파일 하나가 공지 하나, 각 스트림이 `Acked:`로 확인). 팀 현황·다이제스트·Phase 표·CODEOWNERS·공지 색인은 파일에 손으로 쓰지 않고 스크립트가 도출·생성한다.
- **변경 분류**: checkpoint 이후 커밋을 `git fetch` 후 `--no-merges`로 "내 브랜치 전용"(`<checkpoint>..HEAD ^origin/main`)과 "main 유입"으로 나눈다. 브랜치 전용은 trailer로(`Agent:` = 이 스트림의 에이전트, 없음 = 사람의 직접 수정), main 유입은 전부 동료 변경으로 취급한다. 어느 쪽도 되돌리지 않는다. 출력은 상한이 있다(spec·Touches에 닿는 것만 최대 10개).
- **Phase 병렬**: Phase는 `Depends on` 그래프이며 의존 없는 Phase는 동시에 진행한다. `PLAN.md` 머리(Status·Lead·Depends on)가 SSoT이고 `docs/phases/README.md` 표는 생성한다. Phase 종료는 Lead의 `ws/phase-NN-close` 스트림.
- **의미 충돌 층**: spec 변경은 구현보다 먼저 main에(spec 스트림; 예외는 내 Touches 안의 spec 조각뿐, CI 검사) · Task마다 `Touches` 선언과 겹침 경고 · ARCHITECTURE Module Boundaries의 Owner 열 → CODEOWNERS · ADR 파일명 날짜 기반, 병합 = Accepted · PLAN 항목 사이 빈 줄, 새 Task는 계획 PR로만 · 역할 메모리는 `--ready` 단계에만 갱신하고 union merge.
- **메모리 5층**: 팀 공지 / `docs/` / 역할 메모리(`.claude/agent-memory/`) / 스트림 상태 / 개인 메모리(`.ai/local/`, 미추적).
- 개인 프로젝트도 같은 구조를 쓴다(PR 대신 `ai-stream.sh merge`).

## Rationale

- 디렉터리 분리는 git이 가장 잘 하는 충돌 회피다. "소유자만 쓴다"를 CI로 강제하면 예절이 아니라 제약이 된다(ADR-20260829-executable-constraints-over-prose).
- 사람이 아니라 스트림을 단위로 두면 한 사람의 병렬 작업, 사람 간 인수인계(HANDOFF의 본래 목적 확장), 브랜치와의 1:1 대응이 한 번에 해결된다.
- 파생 파일을 생성으로 두면 "표의 인접 행 충돌" 같은 저빈도 충돌까지 없어지고, 어긋남은 CI가 잡는다.
- 공지를 write-once 파일로 두면 "읽었는지"를 스트림 안(`Acked:`)에 기록할 수 있어 충돌 없이 확인을 강제할 수 있다.

## Consequences

- 긍정: `.ai/` 병합 충돌 0(구조적). 세션 절차·규칙·컨텍스트 예산이 개인용과 같다. 인수인계가 사람 사이에서도 성립한다. 템플릿 한 벌로 개인·팀을 모두 다룬다.
- 부정 / 감수한 것: Task마다 브랜치 + `open` 한 번의 비용. merge commit으로 히스토리가 덜 선형적(`--first-parent`로 본다). push된 것만 팀에 보인다. 오프라인에서는 겹침 경고가 없다. PLAN·ARCHITECTURE의 저빈도 충돌은 리뷰로 남는다. 스크립트가 커졌다.
- 후속 작업: 스트림 상한(1인 2개 권장)·stale 기준(3일)은 운영하며 조정한다. GitHub 외 호스팅의 CI 예시 추가.
