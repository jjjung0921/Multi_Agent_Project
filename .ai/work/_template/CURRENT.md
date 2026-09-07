# Current State — {{STREAM}}

<!-- 50줄 이내. Status: TODO | IN_PROGRESS | BLOCKED | REVIEW (DONE은 병합 여부로 도출). Progress는 step마다, 나머지는 세션 종료 시 갱신. 머리의 필드는 ai-stream.sh가 채운다. -->

- Stream: {{STREAM}}
- Owner: {{OWNER}}
- Branch: ws/{{STREAM}}
- Task: {{TASK}}
- Touches: {{TOUCHES}}
- Supersedes: {{SUPERSEDES}}
- Acked: none

## Current Phase

{{PHASE}}

## Current Task

{{TASK_TITLE}}

## Status

TODO

## Progress

<!-- 현재 Task의 step ≤ 10개. 진행 중인 step 끝에 ← -->
- (Task 시작 전)

## Last Checkpoint

<!-- 이 스트림의 마지막 close commit. `scripts/ai-end.sh --set-checkpoint`가 기록한다. -->
`{{CHECKPOINT}}`

## Relevant Documents

- {{PLAN}}

## Relevant Source Files

<!-- 디렉터리가 아니라 파일·심볼 단위로: `src/api/users.py:create_user` -->
- (아직 없음)

## Next Action

{{PLAN}}에서 {{TASK}}의 Done when·Acceptance Criteria를 확인하고 HANDOFF의 Goal·Work In Progress를 쓴 뒤 시작한다.
