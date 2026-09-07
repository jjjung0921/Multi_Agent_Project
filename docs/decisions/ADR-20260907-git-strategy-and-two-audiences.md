# ADR-20260907: git 전략, 훅과 flow 역할, 그리고 두 독자(커밋은 Agent용 · PR은 사람용)

- Status: Accepted
- Date: 2026-09-07
- Deciders: 템플릿 소유자

## Context

ADR-20260907-workstream-state-and-parallel-collaboration은 상태의 단위를 정했다. 남은 것은 (1) 브랜치·병합·훅·CI라는 git 전략을 누가 정하고 누가 집행하는가, (2) "git 흐름을 맡는 에이전트가 훅으로 문서를 자동 작성"하는 요구를 이 템플릿의 원칙(절차는 스크립트, 제약은 도구, 저장소가 기억)과 어떻게 화해시키는가, (3) 커밋과 PR의 독자가 다르다는 점 — 커밋은 Agent가 `git log`로 읽고 PR·이슈·README는 사람이 읽는다 — 을 형식에 어떻게 반영하는가다.

## Problem

전략의 결정 주체·집행 수단·LLM의 역할 범위를 고정하고, 커밋 메시지는 "빨리 찾고 토큰을 아끼는" 형식으로, GitHub 산출물은 "맥락이 한눈에 들어오는" 형식으로 분리하려면 무엇을 정해야 하는가.

## Alternatives

전략과 자동화:

1. **LLM 에이전트가 훅에서 문서를 직접 쓴다** — 편해 보이지만 commit/push마다 모델 호출은 느리고 불안정하며, 공유 문서를 자동으로 쓰면 방금 없앤 충돌이 다른 형태로 돌아온다.
2. **모든 것을 결정적 스크립트로** — 예측 가능하지만 PR 본문↔HANDOFF 일치, 공지 필요 여부 같은 판단은 스크립트가 못 한다.
3. **두 층 분리** — 기계적인 것은 결정적 훅·CI, 판단은 LLM 역할이되 코멘트·PR·파생 파일 재생성으로만 말한다(아래 Decision).

커밋 형식:

- a. **자유 산문** — 사람에게 친절하지만 grep이 안 되고 토큰을 먹는다.
- b. **Conventional Commits + 산문 body** — subject는 찾기 좋지만 body가 길어진다.
- c. **고정 문법 subject + 키-값 body + 고정 키 trailer, 영어 subject** — Agent가 한 줄 ≈ 20토큰으로 읽고 trailer로 grep한다(아래 Decision).

## Decision

3안과 c안을 채택한다.

- **전략은 ADR이 정한다**(이 문서). 브랜치 `ws/<id>`·`hotfix/*` · main은 PR로만 · 병합은 merge commit만(squash·rebase-merge 비활성) · 병합 메시지 = "PR 제목 + 본문" · 병합 후 head 브랜치 자동 삭제 · push된 커밋 rewrite 금지 · main 동기화는 `git merge main`(충돌 해결은 Touches 안에서만) · Phase 태그는 병합 후 `ai-stream.sh tag`. 집행은 `ai-stream.sh setup`(저장소)과 `setup --local`(clone)이 한다.
- **결정적 훅**(`.githooks/`, `core.hooksPath`): `commit-msg`는 subject 문법·길이 검사와 `Stream:`(브랜치)·`Agent:`(`$AI_AGENT`)·`Spec:`(docs/ diff) 자동 추가 · `pre-push`는 `ai-end.sh --quick` · `post-merge`는 main 유입 요약 출력 · `post-checkout`은 스트림 요약. 훅에 LLM은 없다.
- **CI**(`ai-end.sh --ci`): 브랜치 이름 · 스트림 디렉터리 · Status · 남의 스트림 디렉터리 변경 금지(gc 삭제만 예외) · Touches 밖 spec 변경 FAIL · Required 공지 미확인 FAIL · PR 제목 문법 · 파생 파일(phases 표·CODEOWNERS) drift · 크기 상한 · 비밀값 패턴. `hotfix/*`는 Commands만.
- **flow 역할**(`.claude/agents/git-flow.md`, 저장소 안, 팀 공유): CI의 PR 이벤트에서 리뷰(본문↔HANDOFF/LOG 일치, Spec changes 누락, Touches 밖 변경 설명, ADR·공지 필요 여부)를 코멘트로, 일일 유지보수(stale 스트림·미확인 공지·gc 후보·설정 drift)를 코멘트와 `ws/flow-*` PR로 한다. 제약 셋: 로컬 차단 훅에 넣지 않는다 · 공유 문서를 직접 쓰지 않는다 · 전략을 정하지 않는다.
- **커밋(Agent용)**: `<type>(<scope>): <summary>` — type `feat fix refactor test docs chore ai`, scope는 구성요소 이름(부기는 스트림 id), summary ≤ 60자 영어 명령형 · body는 `Why:/What:/Test:` 키-값 ≤ 5줄, diff로 알 수 없는 것만 · trailer 키 고정 `Agent Task Stream Spec Refs Wip` · 부기 커밋은 type `ai` · WIP는 `Wip:` trailer. 조회는 한 줄 형식 alias `git ai-log`와 `ai-stream.sh history`.
- **PR·이슈(사람용)**: PR 제목 `<type>(<scope>): <summary> [<phase>/<task>]`(merge commit의 subject), 본문은 한국어 산문 섹션(무엇을·왜 / 리뷰 포인트 / Spec 변경 / 확인 방법 / 후속), 에이전트 산출물은 `<details>`, 맨 끝 trailer 블록(`Stream Task Spec Refs Announcement`)만 기계용 → merge commit의 trailer. 이슈는 `task-request`·`bug` 템플릿이며 Agent는 이슈를 직접 읽지 않고 소유자가 INBOX로 옮긴다.

## Rationale

- 실패하는 검사는 Agent가 스스로 고치지만 프로즈 규칙은 사람이 리뷰에서 잡아야 한다(ADR-20260829-executable-constraints-over-prose). 예절을 훅·CI로 옮기면 준수율과 검증 비용이 함께 좋아진다.
- LLM은 판단이 필요한 곳에서만 값어치가 있고, 쓰기 권한을 코멘트·PR로 좁히면 비결정성이 저장소 상태를 오염시키지 않는다.
- merge commit이어야 브랜치의 trailer·WIP·checkpoint SHA가 main에서 유효하다(ADR-20260829-git-checkpoint-and-session-safety의 "rewrite 금지"의 연장). 병합 메시지를 "제목+본문"으로 두면 first-parent 로그가 PR당 한 줄이 되고 trailer가 남는다 — Agent는 `%s`와 trailer만 읽으므로 본문 산문은 토큰을 쓰지 않는다.
- 영어 subject는 IME 없이 grep되고 같은 내용이 한국어보다 토큰이 30~40% 적다. body와 PR은 한국어로 두어 사람의 가독성을 잃지 않는다.

## Consequences

- 긍정: 커밋 조회 비용이 예측 가능하다(한 줄 ≈ 20토큰). PR은 리뷰어를 위한 글이 된다. 전략 drift를 CI와 flow 역할이 잡는다.
- 부정 / 감수한 것: 훅·CI·스크립트 유지 비용. flow 역할은 토큰 비용이 들고 조직의 Action 설정이 필요하다(기본 꺼짐). 영어 subject를 팀이 부담스러워하면 한국어로 바꿀 수 있으나 문법·길이 제한은 유지한다.
- 후속 작업: `ai-stream.sh setup`의 GitHub 외 호스팅 지원. flow 역할 프롬프트는 운영하며 다듬는다(`.claude/agent-memory/git-flow/`).
