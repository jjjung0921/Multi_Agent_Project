#!/usr/bin/env bash
# ai-end.sh — 세션 종료 점검 / PR 준비 / 훅용 빠른 점검 / CI.
#
# 사용법: scripts/ai-end.sh                    종료 점검 (close commit 전)
#         scripts/ai-end.sh --set-checkpoint   내 CURRENT.md 의 Last Checkpoint 를 HEAD 로 기록한 뒤 점검
#         scripts/ai-end.sh --ready [--pr]     Task 완료: main 동기화·spec·공지 검사 → Status=REVIEW 커밋·push → PR 제목·본문 초안 출력 (--pr: gh 로 생성/갱신)
#         scripts/ai-end.sh --quick            pre-push 훅용 (브랜치·남의 스트림·비밀값만, 수 초)
#         scripts/ai-end.sh --ci               PR 검사 (CI). env: PR_TITLE, PR_BODY, GITHUB_HEAD_REF, CI_BASE(기본 origin/main)
# 종료 코드: 0 = 통과, 1 = FAIL 항목 있음 (warn 은 통과). 요구: git 2.23+, bash 3.2+.

set -eo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

mode=check; setcp=0; make_pr=0
for a in "$@"; do
  case "$a" in
    --set-checkpoint) setcp=1;; --quick) mode=quick;; --ready) mode=ready;; --pr) make_pr=1;; --ci) mode=ci;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "알 수 없는 옵션 $a";;
  esac
done

branch=$(current_branch); [ -z "$branch" ] && branch=${GITHUB_HEAD_REF:-}
id=$(stream_from_branch "$branch")
base=${CI_BASE:-$(main_ref)}
head_short=$(git rev-parse --short HEAD)
bootstrap=0; [ -f .ai/BOOTSTRAP.md ] && bootstrap=1

[ "$mode" = "quick" ] || say "ai-end ($mode) — HEAD $head_short · branch ${branch:-?} · base $base · $today"

# --- hotfix/* 와 bootstrap 은 스트림 규칙 밖 ---
case "$branch" in hotfix/*) say "  hotfix/* 브랜치 — 스트림 규칙 검사 없음 (Commands 만 CI 가 검사)"; exit 0;; esac
if [ -z "$id" ]; then
  if [ "$bootstrap" -eq 1 ] && [ "$mode" != "ci" ]; then say "  bootstrap 모드 — 스트림 없이 진행 (파생 파일 검사만)"; fail_derived=0
    bash scripts/ai-stream.sh phases --check >/dev/null 2>&1 || warn "docs/phases/README.md 표가 PLAN 머리와 다르다 → scripts/ai-stream.sh phases"
    exit 0
  fi
  fail "브랜치 '$branch' 는 ws/* 가 아니다 (Rule 15) — scripts/ai-stream.sh open"; exit 1
fi
dir="$WORK/$id"; CURRENT="$dir/CURRENT.md"; HANDOFF="$dir/HANDOFF.md"; LOG="$dir/LOG.md"; INBOX="$dir/INBOX.md"; LOCK="$dir/.lock"
[ -f "$CURRENT" ] || { fail "$CURRENT 가 없다"; exit 1; }
task=$(field "$CURRENT" Task); touches=$(field "$CURRENT" Touches); acked=$(field "$CURRENT" Acked | tr -d ' ')
kind=$(printf '%s' "$id" | sed -E 's/^([0-9]{2})-T[0-9]+-.*/task/; s/^(spec|chore|plan|phase)-.*/\1/')

# --- --set-checkpoint ---
if [ "$setcp" -eq 1 ]; then
  awk -v sha="$head_short" '
    /^## Last Checkpoint/            { insec = 1; print; next }
    insec && /^## /                  { insec = 0 }
    insec && !done && /^`[^`]*`$/    { print "`" sha "`"; done = 1; next }
    { print }' "$CURRENT" > "$CURRENT.tmp" && mv "$CURRENT.tmp" "$CURRENT"
  say "Last Checkpoint → $head_short"
fi

# ---------------------------------------------------------------- 검사 함수
changed_paths() { # 커밋된 변경(base...HEAD) + uncommitted, "STATUS<TAB>PATH"
  { git diff --name-status --no-renames "$base...HEAD" -- 2>/dev/null || true
    git status --porcelain | awk '{ s = substr($0, 1, 2); gsub(/ /, "", s); if (s == "??") s = "A"; p = $0; sub(/^.. /, "", p); sub(/.* -> /, "", p); printf "%s\t%s\n", substr(s, 1, 1), p }'; } | sort -u
}
chk_other_streams() {
  local bad=0 st p x
  while IFS="$(printf '\t')" read -r st p; do
    [ -z "$p" ] && continue
    case "$p" in
      "$WORK"/_template/*) [ "$kind" = "chore" ] || { fail "스트림 양식 변경: $p — chore 스트림에서만"; bad=1; };;
      "$WORK"/*/*)
        x=${p#"$WORK"/}; x=${x%%/*}
        [ "$x" = "$id" ] && continue
        if [ "$st" = "D" ] && ! ws_ref_exists "$x"; then continue; fi   # gc: 브랜치 없는 스트림의 삭제만 허용
        fail "다른 스트림 디렉터리 변경: $p (Rule 6·15)"; bad=1;;
    esac
  done <<EOF
$(changed_paths)
EOF
  [ "$bad" -eq 0 ] && ok "다른 스트림 디렉터리 변경 없음"
  return 0
}
chk_secrets() {
  local hits; hits=$(secret_scan "$dir" "$TEAM" 2>/dev/null | head -n 5)
  if [ -n "$hits" ]; then fail "비밀값 패턴 (Rule 13):"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "비밀값 패턴 없음"; fi
  return 0
}
chk_status() {
  local st; st=$(status_of "$CURRENT")
  case "$mode:$st" in
    ready:REVIEW|ci:REVIEW) ok "Status = $st";;
    ready:TODO|ready:BLOCKED|ready:DONE) ok "Status = $st (→ REVIEW 로 바꾼다)";;
    *:IN_PROGRESS) fail "Status 가 IN_PROGRESS 다 → TODO / REVIEW / BLOCKED 중 하나로 (Rule 11)";;
    *:TODO|*:REVIEW|*:BLOCKED|*:DONE) ok "Status = $st";;
    *) fail "Status 를 읽을 수 없다: '${st:-}'";;
  esac
  return 0
}
chk_checkpoint() { # checkpoint 이후에 부기(ai(…))·병합 커밋만 있으면 통과
  local cp extra; cp=$(checkpoint_of "$CURRENT")
  if [ -z "$cp" ] || ! git cat-file -e "${cp}^{commit}" 2>/dev/null; then fail "Last Checkpoint(${cp:-없음})가 이 저장소에 없다 → scripts/ai-end.sh --set-checkpoint"; return; fi
  extra=$(git log --no-merges --format=%s "$cp..HEAD" -- | grep -vE '^ai\(' || true)
  if [ -z "$extra" ]; then ok "Last Checkpoint = $cp (이후 부기·병합 커밋만)"; else fail "checkpoint($cp) 이후 작업 커밋이 있다 → scripts/ai-end.sh --set-checkpoint"; fi
  return 0
}
chk_close_scope() { # 커밋 안 된 변경은 close commit 범위 안에만 (추적 파일은 FAIL, 미추적 파일은 warn)
  local other untracked
  other=$(git status --porcelain | grep -v '^??' | cut -c4- | sed 's/.* -> //' | grep -vE "^($dir/|docs/phases/|docs/decisions/|\.claude/agent-memory/)" || true)
  untracked=$(git status --porcelain | grep '^??' | cut -c4- | grep -vE "^($dir/|docs/phases/|docs/decisions/|\.claude/agent-memory/)" || true)
  if [ -z "$other" ]; then ok "코드 변경이 모두 커밋되어 있다"; else fail "작업 커밋이 안 된 변경이 있다 (close commit 전에 Rule 9 대로 커밋):"; printf '%s\n' "$other" | sed 's/^/           /'; fi
  [ -n "$untracked" ] && { warn "미추적 파일이 있다 — 커밋 대상이면 add, 아니면 .gitignore:"; printf '%s\n' "$untracked" | sed 's/^/           /'; }
  return 0
}
chk_handoff() {
  grep -q "^- Date: $today" "$HANDOFF" && ok "HANDOFF.md Date = $today" || warn "HANDOFF.md 의 Date 가 오늘($today)이 아니다"
  strip_comments "$HANDOFF" | grep -qE '<[^>]+>' && warn "HANDOFF.md 에 placeholder(<...>)가 남아 있다" || ok "HANDOFF.md 에 placeholder 없음"
  return 0
}
chk_log() {
  local top; top=$(grep -m1 '^## ' "$LOG" || true)
  case "$top" in "## $today"*) ok "LOG.md 맨 위 항목 = 오늘 세션";; *) warn "LOG.md 맨 위 항목이 오늘($today)이 아니다 (${top:-항목 없음})";; esac
  return 0
}
chk_head_trailer() { [ -n "$(trailer HEAD Agent)" ] && ok "HEAD 커밋에 Agent trailer 있음" || warn "HEAD 커밋($head_short)에 Agent trailer 가 없다 — 사람 커밋이거나 누락"; }
chk_inbox() {
  local c; c=$(grep -c '^- \[ \]' "$INBOX" 2>/dev/null || true); c=${c:-0}
  [ "$c" -gt 0 ] && warn "INBOX 에 미처리 항목 ${c}개 — 처리하지 못했다면 LOG 에 이유를 적는다" || ok "INBOX 비어 있음"
  return 0
}
cap() { if [ "${2:-0}" -le "$3" ]; then ok "$1 = $2 (≤ $3)"; else warn "$1 = $2 — 상한 $3 (Rule 12)"; fi; }
chk_caps() {
  cap "CURRENT.md 줄 수" "$(lines "$CURRENT")" 50
  cap "HANDOFF.md 줄 수" "$(lines "$HANDOFF")" 60
  cap "LOG 맨 위 항목 줄 수" "$(awk '/^## /{ n++ } n == 1 && NF' "$LOG" | grep -vc '^## ' || true)" 8
  cap "Progress step 수" "$(count_bullets "$CURRENT" Progress)" 10
  [ -f "$LOCAL/MEMORY.md" ] && cap "local MEMORY.md 줄 수" "$(lines "$LOCAL/MEMORY.md")" 50
  return 0
}
chk_sync() { git merge-base --is-ancestor "$base" HEAD 2>/dev/null && ok "main 동기화됨 ($base 가 HEAD 의 조상)" || fail "main 이 병합되지 않았다 → git merge main"; }
chk_spec() {
  local files f bad=0 logspec
  files=$(git diff --name-only "$base...HEAD" -- docs/PRD.md docs/ARCHITECTURE.md docs/api 2>/dev/null || true)
  if [ -z "$files" ]; then ok "spec 변경 없음"; return; fi
  logspec=$(awk '/^## /{ n++ } n == 1' "$LOG" | sed -n 's/^- Spec changes: *//p' | head -n1)
  while read -r f; do
    [ -z "$f" ] && continue
    path_in_touches "$f" "$touches" || { fail "Touches 밖 spec 변경: $f → spec 스트림으로 분리 (Rule 7)"; bad=1; }
  done <<EOF
$files
EOF
  case "$logspec" in ""|none|없음) fail "spec 이 바뀌었는데 LOG 맨 위 항목의 'Spec changes:' 가 비었다 (Rule 7)"; bad=1;; esac
  [ "$bad" -eq 0 ] && ok "spec 변경이 Touches 안이고 LOG 에 명시됨: $(printf '%s' "$files" | tr '\n' ' ')"
  if git diff --name-only "$base...HEAD" -- AGENTS.md | grep -q . ; then
    git diff --name-only --diff-filter=A "$base...HEAD" -- "$TEAM/announcements/" | grep -v _template | grep -q . && ok "AGENTS.md 변경에 공지 있음" || fail "AGENTS.md 가 바뀌었는데 공지($TEAM/announcements/)가 없다 (Rule 14)"
  fi
  return 0
}
chk_announcements() {
  local f aid req bad=0 added
  added=$(git diff --name-only --diff-filter=A "$base...HEAD" -- "$TEAM/announcements/" 2>/dev/null || true)
  for f in $(git ls-tree --name-only "$base" "$TEAM/announcements/" 2>/dev/null); do
    aid=$(basename "$f" .md); [ "$aid" = "_template" ] && continue
    case "$added" in *"$f"*) continue;; esac
    req=$(git show "$base:$f" | sed -n 's/^- Required: *//p' | head -n1)
    [ "$req" = "yes" ] || continue
    announcement_applies "$(git show "$base:$f" | sed -n 's/^- Applies to: *//p' | head -n1)" "$touches" || continue
    case ",$acked," in *",$aid,"*) ;; *) fail "Required 공지 미확인: $aid → Action 수행 후 CURRENT 의 Acked: 에 추가 (Rule 5)"; bad=1;; esac
  done
  [ "$bad" -eq 0 ] && ok "Required 공지 모두 확인됨"
  return 0
}
chk_pr_title() {
  local t=${PR_TITLE:-}; [ -z "$t" ] && { warn "PR_TITLE 없음 — 제목 문법 검사 생략"; return; }
  if printf '%s' "$t" | grep -qE '^(feat|fix|refactor|test|docs|chore|ai|spec|adr|plan|phase-close|hotfix|announce)\([a-z0-9._/-]+\): .{1,72} \[([0-9]{2}|-)/(T[0-9]+|-)\]$'; then ok "PR 제목 문법: $t"; else fail "PR 제목 문법 위반: '$t' → <type>(<scope>): <summary> [<phase>/<task>]"; fi
  return 0
}
chk_derived() {
  bash scripts/ai-stream.sh phases --check >/dev/null 2>&1 && ok "docs/phases/README.md 표 = PLAN 머리" || fail "docs/phases/README.md 표가 PLAN 머리와 다르다 → scripts/ai-stream.sh phases"
  bash scripts/ai-stream.sh announce --check >/dev/null 2>&1 && ok "공지 색인 최신" || fail "공지 색인이 다르다 → scripts/ai-stream.sh announce"
  if grep -vq '^#' .github/CODEOWNERS 2>/dev/null; then
    bash scripts/ai-stream.sh codeowners --check >/dev/null 2>&1 && ok "CODEOWNERS = ARCHITECTURE Owner 열" || fail "CODEOWNERS 가 ARCHITECTURE Owner 열과 다르다 → scripts/ai-stream.sh codeowners"
  fi
  local dup; dup=$(ls -d docs/phases/[0-9][0-9]-*/ 2>/dev/null | sed 's#/$##; s#.*/##' | cut -c1-2 | sort | uniq -d)
  [ -z "$dup" ] && ok "Phase 번호 중복 없음" || fail "Phase 번호 중복: $dup"
  return 0
}

# ---------------------------------------------------------------- 모드별 실행
case "$mode" in
  quick)
    chk_other_streams >/dev/null; chk_secrets >/dev/null
    [ "$FAILED" -ne 0 ] && { chk_other_streams; chk_secrets; };;
  check)
    chk_close_scope; chk_status; chk_checkpoint; chk_other_streams; chk_handoff; chk_log; chk_head_trailer; chk_inbox; chk_caps; chk_secrets;;
  ready)
    chk_close_scope; chk_status; chk_checkpoint; chk_other_streams; chk_sync; chk_spec; chk_announcements; chk_caps; chk_secrets; chk_handoff
    bash scripts/ai-stream.sh phases --check >/dev/null 2>&1 || warn "docs/phases/README.md 표가 PLAN 머리와 다르다 → scripts/ai-stream.sh phases (CI 가 FAIL 시킨다)"
    if [ "$kind" = "task" ]; then
      plan=$(ls -d docs/phases/"${task%%/*}"-*/PLAN.md 2>/dev/null | head -n1)
      [ -n "$plan" ] && { grep -qE "^- \[x\] ${task#*/}\. .*\(commit [0-9a-f]{7,}" "$plan" && ok "PLAN 의 ${task#*/} 에 완료 SHA 있음" || warn "PLAN 의 ${task#*/} 줄에 [x]·(commit <sha>, PR #n) 를 적는다"; }
    fi;;
  ci)
    chk_status; chk_other_streams; chk_sync; chk_spec; chk_announcements; chk_pr_title; chk_derived; chk_caps; chk_secrets
    grep -q '{{' "$CURRENT" && fail "CURRENT.md 에 치환되지 않은 {{…}} 가 있다";;
esac

[ "$mode" = "quick" ] || say
if [ "$FAILED" -ne 0 ]; then say "FAIL 항목을 해결한 뒤 다시 실행한다."; exit 1; fi

case "$mode" in
  quick) say "ai-end --quick: 통과 (stream $id)"; exit 0;;
  ci)    say "통과."; exit 0;;
  check)
    rm -f "$LOCK"
    say "통과. 남은 단계: close commit → push"
    say "  git add $dir docs/phases docs/decisions .claude/agent-memory && git commit -m 'ai($id): close <n>/<m> — <요약>' --trailer 'Agent: <이름>' --trailer 'Task: $task' && git push"
    exit 0;;
esac

# ---------------------------------------------------------------- --ready: Status=REVIEW 커밋 → PR 초안
st=$(status_of "$CURRENT")
if [ "$st" != "REVIEW" ]; then
  awk '/^## Status/{ print; getline; while ($0 ~ /^$|^<!--/) { print; getline }; print "REVIEW"; next }{ print }' "$CURRENT" > "$CURRENT.tmp" && mv "$CURRENT.tmp" "$CURRENT"
fi
if ! git diff --quiet -- "$dir"; then
  git add "$dir"; git commit -q -m "ai($id): ready for review" --trailer "Agent: ${AI_AGENT:-ai-stream}" --trailer "Task: $task" --trailer "Stream: $id"
  say "committed: ai($id): ready for review"
fi
have_origin && git push -q -u origin "ws/$id" 2>/dev/null && say "pushed ws/$id"
rm -f "$LOCK"

goal=$(section "$HANDOFF" Goal | head -n1 | sed 's/^<//; s/>$//')
spec_files=$(git diff --name-only "$base...HEAD" -- docs/PRD.md docs/ARCHITECTURE.md docs/api 2>/dev/null | tr '\n' ' ')
spec_flag=no; [ -n "$spec_files" ] && spec_flag=yes
logspec=$(awk '/^## /{ n++ } n == 1' "$LOG" | sed -n 's/^- Spec changes: *//p' | head -n1)
ann=$(git diff --name-only --diff-filter=A "$base...HEAD" -- "$TEAM/announcements/" 2>/dev/null | grep -v _template | sed 's#.*/##; s/\.md$//' | tr '\n' ',' | sed 's/,$//' || true)
refs=$(git diff --name-only --diff-filter=A "$base...HEAD" -- docs/decisions/ 2>/dev/null | grep -v _template | sed 's#.*/##' | tr '\n' ',' | sed 's/,$//' || true)
case "$kind" in task) ptype=feat;; spec) ptype=spec;; plan) ptype=plan;; phase) ptype=phase-close;; *) ptype=chore;; esac
scope=$(touches_of "$touches" | head -n1 | sed 's/^\.\///; s/^\///'); scope=${scope%%/*}; scope=${scope%%#*}; scope=${scope%%.*}; [ -z "$scope" ] || [ "$scope" = "." ] && scope=repo
[ "$kind" = "phase" ] && scope=ai
title="$ptype($scope): $(printf '%s' "${goal:-$id}" | cut -c1-60) [$task]"

body=$(mktemp -t ai-pr.XXXXXX)
{
  printf '## 무엇을 · 왜\n\n%s\n\n' "${goal:-<한 줄>}"
  section "$HANDOFF" "Work Completed"; printf '\n'
  printf '## 리뷰 포인트\n\n'; section "$HANDOFF" "Decisions Made"; section "$HANDOFF" "Unverified Assumptions" | sed 's/^- /- (가정) /'; printf '\n'
  printf '## Spec 변경\n\n'
  if [ "$spec_flag" = yes ]; then printf -- '- %s — %s\n\n' "$spec_files" "${logspec:-<무엇이 어떻게>}"; else printf -- '- 없음\n\n'; fi
  printf '## 확인 방법\n\n'; section "$HANDOFF" "Tests Executed"; section "$HANDOFF" "Test Results"; printf '\n'
  printf '## 후속 · 알려진 문제\n\n'; section "$HANDOFF" "Known Problems"; printf '\n'
  printf '<details><summary>세션 기록 (에이전트 생성)</summary>\n\n'; strip_comments "$LOG" | sed '1d'; printf '\n</details>\n\n'
  printf -- '---\nStream: %s\nTask: %s\nSpec: %s\nRefs: %s\nAnnouncement: %s\n' "$id" "$task" "$spec_flag" "${refs:-none}" "${ann:-none}"
} > "$body"

say
say "PR title (draft): $title"
say "PR body (draft) → $body"
say "-----"; cat "$body"; say "-----"
if [ "$make_pr" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || die "gh 가 없다 — 위 초안으로 수동 생성"
  if gh pr view "ws/$id" >/dev/null 2>&1; then gh pr edit "ws/$id" --title "$title" --body-file "$body" && say "PR 갱신됨"; else gh pr create --base main --head "ws/$id" --title "$title" --body-file "$body" && say "PR 생성됨"; fi
fi
say "소유자가 본문을 다듬어 올린다 — 리뷰어가 읽을 글이다."
exit 0
