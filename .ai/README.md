# .ai — 단기 상태

```text
.ai/
├── BOOTSTRAP.md          # 템플릿 → 프로젝트 초기화 절차 (초기화 후 삭제)
├── work/                 # 스트림 — 브랜치 ws/<id> 하나에 디렉터리 하나, 소유자만 쓴다
│   ├── _template/        # ai-stream.sh open 이 복사하는 양식 ({{…}} 치환)
│   └── <id>/             # CURRENT.md · HANDOFF.md · LOG.md · INBOX.md · notes/ · (.lock — 미추적)
├── team/
│   ├── README.md         # 공지 색인 (ai-stream.sh announce 가 생성)
│   └── announcements/    # 팀 공지 — 파일 하나가 공지 하나 (write-once), 스트림이 Acked: 로 확인
└── local/                # 개인 메모리 — git 밖, 내 Agent만 (README만 추적)
```

- 스트림 id: `<NN>-<Tk>-<slug>`(Task) · `spec-<slug>` · `chore-<slug>` · `plan-<NN>-<name>` · `phase-<NN>-close`. 재개 스트림은 `-r2`, `-r3`.
- 병합된 스트림의 디렉터리는 main에 남아 그 Task의 기록이 된다. Phase 종료 스트림의 `ai-stream.sh gc`가 병합되고 브랜치가 없는 것을 지운다.
- 저장소 수준의 공유 상태는 `team/announcements/`(write-once)뿐이다. 팀 현황은 파일이 아니라 `ai-stream.sh status`가 브랜치들에서 도출한다.

## Agent용 이력 조회 가이드 (토큰 예산 안에서)

원칙: `git log`를 맨몸으로 부르지 않는다. 항상 형식(`git ai-log` = 한 줄 형식)과 `-n`, 범위(`--first-parent`, `-- <path>`, `--grep`)를 붙인다. body는 커밋을 확정한 뒤 한 개만(`git show -s --format=%b <sha>`).

한 줄 형식(`setup --local`이 alias `ai-log`로 등록):

```text
%h %as %s | %(trailers:key=Task,valueonly,separator=%x2C) %(trailers:key=Stream,valueonly,separator=%x2C) %(trailers:key=Wip,valueonly,separator=%x2C)
→ 3e4d5f6 2026-09-06 feat(backend): add token refresh | 02/T3 02-T3-auth
```

| 알고 싶은 것 | 명령 | 대략의 비용 |
|-------------|------|-----------|
| 팀에서 최근 일어난 일 | `git ai-log --first-parent main -n 20` | 20줄 ≈ 400토큰 |
| 기능 이력만(부기 제외) | `git ai-log --first-parent main --invert-grep --grep='^ai(' -n 20` | 같음 |
| 한 Task의 전부 | `git ai-log --grep='^Task: 02/T3'` | Task당 5~15줄 |
| 한 스트림 / 한 에이전트 | `git ai-log --grep='^Stream: 02-T3-auth'` · `--grep='^Agent: codex'` | |
| spec을 바꾼 커밋 | `git ai-log --first-parent main --grep='^Spec: yes'` | PR 단위 |
| 파일·심볼 이력 | `git ai-log -n 10 -- src/auth/` · `git log -L :create_token:src/auth.py --format=%h` · `git log -S 'refresh_token' --format=%h -n 5` | |
| 무엇이 바뀌었나 (diff 전에) | `git show --stat --format='%h %s' <sha>` → 필요한 파일만 `git show <sha> -- <path>` | stat ≈ 파일 수 × 10토큰 |
| 중단된 곳 | `git log -1 --format='%(trailers:key=Wip,valueonly)'` | 1줄 |
| PR 단위 요약 | `scripts/ai-stream.sh history --task 02/T3 --with-pr` — PR 제목 줄 + trailer만 | |
| 조건 조합 | `scripts/ai-stream.sh history --type spec --scope backend --phase 02 -n 10` | |

- main의 first-parent 로그는 PR당 한 줄이다(merge commit의 subject = PR 제목, trailer = PR 본문 끝 블록). 브랜치 커밋은 특정 스트림·Task를 파고들 때만 본다.
- 스트림 부기 커밋(`ai(<id>): open|close|take`)은 type `ai`로 모여 있어 한 번에 걷어낼 수 있다.
