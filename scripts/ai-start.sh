#!/usr/bin/env bash
# ai-start.sh — 세션 시작. 내 스트림을 확인하고, checkpoint 이후의 변경을 나누고, 상황에 맞는 next steps 를 안내한다.
#
# 사용법: scripts/ai-start.sh            요약
#         scripts/ai-start.sh --diff     사람 직접 수정 커밋의 변경 파일 목록까지
#         scripts/ai-start.sh --upstream 변경 분류만 (post-merge 훅용, lock 없음)
#         scripts/ai-start.sh --force    .lock 이 있어도 진행 (죽은 세션의 lock 정리)
# 요구:   git 2.23+, bash 3.2+. 정보 제공용이라 종료 코드는 0 (스트림이 없거나 소유자가 아니면 1).

set -eo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

show_diff=0; upstream_only=0; force=0
for a in "$@"; do case "$a" in --diff) show_diff=1;; --upstream) upstream_only=1;; --force) force=1;; esac; done

branch=$(current_branch); id=$(stream_from_branch "$branch"); me=$(my_email)
bootstrap=0; [ -f .ai/BOOTSTRAP.md ] && bootstrap=1

# --- 0. 스트림 확인 ---
if [ -z "$id" ]; then
  if [ "$bootstrap" -eq 1 ]; then
    say "bootstrap 모드: 브랜치 '$branch' (스트림 없음). .ai/BOOTSTRAP.md 를 수행한다. 팀이라면 'scripts/ai-stream.sh open chore bootstrap --touches .' 로 스트림을 연다."
    exit 0
  fi
  say "브랜치 '$branch' 는 ws/* 스트림 브랜치가 아니다. main 에서 직접 작업하지 않는다 (Rule 15)."
  say "  스트림 열기: scripts/ai-stream.sh open <NN>/<Tk> <slug>   |   spec/chore: open spec <slug> --touches …   |   현황: scripts/ai-stream.sh status"
  exit 1
fi
dir="$WORK/$id"; CURRENT="$dir/CURRENT.md"; HANDOFF="$dir/HANDOFF.md"; INBOX="$dir/INBOX.md"; LOCK="$dir/.lock"
[ -f "$CURRENT" ] || { say "브랜치 ws/$id 에 $dir/CURRENT.md 가 없다 — scripts/ai-stream.sh open 으로 만든 스트림이 아니다."; exit 1; }

fetch_quiet
main=$(main_ref)
owner=$(field "$CURRENT" Owner)
if have_origin && git show-ref --verify -q "refs/remotes/origin/ws/$id"; then
  rowner=$(field_from_ref "origin/ws/$id" "$CURRENT" Owner); [ -n "$rowner" ] && owner=$rowner
  ahead=$(git rev-list --count "HEAD..origin/ws/$id" 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ] && say "origin/ws/$id 가 로컬보다 ${ahead}개 앞서 있다 — 먼저 'git merge --ff-only origin/ws/$id'."
fi
if [ "$owner" != "$me" ]; then
  say "stream $id 의 소유자는 '$owner' 이고 나는 '${me:-?}' 다. 읽기만 하거나 인수한다: scripts/ai-stream.sh take (Rule 15)."
  exit 1
fi
if [ "$upstream_only" -eq 0 ]; then
  if [ -f "$LOCK" ] && [ "$force" -eq 0 ]; then
    say "다른 세션이 열려 있다: $LOCK ($(cat "$LOCK" 2>/dev/null)). 한 스트림에는 세션 하나만 (Rule 15). 죽은 세션이면 --force."
    exit 1
  fi
  printf 'pid=%s date=%s agent=%s\n' "$$" "$(date '+%F %T')" "${AI_AGENT:-?}" > "$LOCK"
fi

task=$(field "$CURRENT" Task); touches=$(field "$CURRENT" Touches); acked=$(field "$CURRENT" Acked | tr -d ' ')
status=$(status_of "$CURRENT"); checkpoint=$(checkpoint_of "$CURRENT")
if [ "$upstream_only" -eq 0 ]; then say "stream: $id  owner: $owner (you)  branch: $branch  task: $task"; say "touches: $touches"; fi

# --- 1. checkpoint ---
if [ -z "$checkpoint" ] || ! git cat-file -e "${checkpoint}^{commit}" 2>/dev/null; then
  say "checkpoint: (${checkpoint:-없음}) — 이 저장소에 없다. 최근 30개 커밋을 본다."
  range_from=$(git rev-list --max-count=30 HEAD | tail -n1); [ -n "$range_from" ] && checkpoint="$range_from^" || checkpoint=""
else
  [ "$upstream_only" -eq 1 ] || say "checkpoint: $checkpoint  $(git log -1 --format='%as %s' "$checkpoint")"
fi
range="${checkpoint:+$checkpoint..}HEAD"

# --- 2. 변경 분류: 내 브랜치 전용 vs main 유입 ---
tmp=$(mktemp -t ai-start.XXXXXX)
git rev-list --no-merges --reverse "$range" -- > "$tmp.all" 2>/dev/null || true
git rev-list --no-merges --reverse "$range" "^$main" -- > "$tmp.branch" 2>/dev/null || true
grep -vxF -f "$tmp.branch" "$tmp.all" > "$tmp.upstream" 2>/dev/null || true
merges=$(git rev-list --merges "$range" -- 2>/dev/null | wc -l | tr -d ' ')

[ "$upstream_only" -eq 1 ] || say
[ "$upstream_only" -eq 1 ] || say "commits since checkpoint (branch-only, --no-merges):"
n_agent=0; n_human=0; n_other=0; n_ai=0; human_shas=""
while read -r sha; do
  [ -z "$sha" ] && continue
  subj=$(git log -1 --format=%s "$sha"); agent=$(trailer "$sha" Agent); st=$(trailer "$sha" Stream)
  case "$subj" in "ai("*) n_ai=$((n_ai + 1)); continue;; esac
  line=$(git log -1 --format="$LOG_FMT" "$sha")
  [ "$upstream_only" -eq 1 ] && continue
  if [ -n "$st" ] && [ "$st" != "$id" ]; then n_other=$((n_other + 1)); say "  $line {stream:$st}   ← 다른 스트림 (동료 변경으로 취급)"
  elif [ -n "$agent" ]; then n_agent=$((n_agent + 1)); say "  $line {$agent}"
  else n_human=$((n_human + 1)); human_shas="$human_shas $sha"; say "  $line {HUMAN}   ← 직접 수정 (Rule 4)"; fi
done < "$tmp.branch"
if [ "$upstream_only" -eq 0 ]; then
  [ $((n_agent + n_human + n_other)) -eq 0 ] && say "  (없음)"
  [ "$n_ai" -gt 0 ] && say "  (+ 부기 커밋 ai(…) ${n_ai}개)"
fi
if [ "$n_human" -gt 0 ] && [ "$show_diff" -eq 1 ]; then
  for sha in $human_shas; do say "  --- $sha"; git show --stat --format= "$sha" | sed 's/^/    /'; done
fi

up_total=$(wc -l < "$tmp.upstream" | tr -d ' ')
[ "$upstream_only" -eq 1 ] || say
if [ "$up_total" -gt 0 ]; then
  say "from main since checkpoint: ${up_total} commits (merges: ${merges}) — spec·Touches 에 닿는 것만 표시:"
  shown=0; hit=0; > "$tmp.specfiles"
  while read -r sha; do
    [ -z "$sha" ] && continue
    files=$(git show --format= --name-only "$sha" 2>/dev/null)
    hits=""
    while read -r f; do
      [ -z "$f" ] && continue
      case "$f" in docs/PRD.md|docs/ARCHITECTURE.md|docs/api/*|AGENTS.md) hits="$hits $f"; echo "$f" >> "$tmp.specfiles";; *)
        if path_in_touches "$f" "$touches"; then hits="$hits $f"; fi;; esac
    done <<EOF
$files
EOF
    if [ -n "$hits" ]; then
      hit=$((hit + 1))
      if [ "$shown" -lt 10 ]; then shown=$((shown + 1)); say "  $(git log -1 --format="$LOG_FMT" "$sha")   ←$(printf '%s' "$hits" | tr '\n' ' ' | cut -c1-80)"; fi
    fi
  done < "$tmp.upstream"
  [ "$hit" -eq 0 ] && say "  (spec·Touches 에 닿는 커밋 없음)"
  [ "$hit" -gt "$shown" ] && say "  … 외 $((hit - shown))개 (scripts/ai-stream.sh history --branches -n 50 -- <path>)"
  spec_hits=$(sort -u "$tmp.specfiles" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$merges" -gt 0 ]; then
    cf=$(for m in $(git rev-list --merges "$range" --); do git diff-tree -c --name-only --no-commit-id "$m"; done 2>/dev/null | sort -u | head -n 20)
    [ -n "$cf" ] && { say "  merge conflicts resolved in:"; printf '%s\n' "$cf" | sed 's/^/    /'; }
  fi
else
  say "from main since checkpoint: (없음)"; spec_hits=0
fi
[ "$upstream_only" -eq 1 ] && { rm -f "$tmp" "$tmp".*; exit 0; }

# --- 3. uncommitted ---
say
say "uncommitted changes:"
status_out=$(git status --porcelain)
if [ -z "$status_out" ]; then say "  (없음)"; else printf '%s\n' "$status_out" | sed 's/^/  /'; fi
other_dirty=$(printf '%s\n' "$status_out" | cut -c4- | sed 's/.* -> //' | grep -E "^$WORK/" | grep -vE "^$WORK/($id|_template)/" || true)
[ -n "$other_dirty" ] && say "  → 다른 스트림 디렉터리에 변경이 있다 — 되돌리지 말고 소유자에게 묻는다 (Rule 6·15)"

# --- 4. INBOX (스트림 + 개인) ---
say
open_items=0
for ib in "$INBOX" "$LOCAL/INBOX.md"; do
  [ -f "$ib" ] || continue
  c=$(grep -c '^- \[ \]' "$ib" || true); c=${c:-0}
  if [ "$c" -gt 0 ]; then say "INBOX ($ib): ${c}개 — 소유자의 직접 지시 (Rule 5)"; grep '^- \[ \]' "$ib" | sed 's/^/  /'; open_items=$((open_items + c)); fi
done
[ "$open_items" -eq 0 ] && say "INBOX: 비어 있음"

# --- 5. 공지 ---
say
unacked=0; unacked_req=0
for f in "$TEAM"/announcements/*.md; do
  [ -f "$f" ] || continue
  aid=$(basename "$f" .md); [ "$aid" = "_template" ] && continue
  case ",$acked," in *",$aid,"*) continue;; esac
  req=$(field "$f" Required); app=$(field "$f" "Applies to"); rel="해당"
  announcement_applies "$app" "$touches" || rel="해당 없음(확인만)"
  unacked=$((unacked + 1)); [ "$req" = "yes" ] && [ "$rel" = "해당" ] && unacked_req=$((unacked_req + 1))
  say "announcement: $aid  Required=${req:-?}  Applies to=${app:-all}  [$rel]"
  sed -n 's/^- Action: */    Action: /p' "$f" | head -n1
done
[ "$unacked" -eq 0 ] && say "announcements: 미확인 없음"
[ "$unacked" -gt 5 ] && say "  → 미확인 공지 ${unacked}개 — 오래된 것은 Phase 종료 시 정리한다"

# --- 6. CURRENT 상태 ---
say
phase=$(section "$CURRENT" "Current Phase" | head -n1); plan=$(printf '%s' "$phase" | grep -oE '`[^`]+`' | head -n1 | tr -d '`' || true)
next=$(section "$CURRENT" "Next Action" | head -n1)
say "CURRENT: phase  = ${phase:-?}"
say "         status = ${status:-?}"
say "         next   = ${next:-?}"
rework=0
if [ "$status" = "IN_PROGRESS" ]; then
  say "  → 직전 세션이 정상 종료되지 않았다(중단). progress:"; section "$CURRENT" Progress | sed 's/^/      /'
elif [ "$status" = "REVIEW" ] && { [ "$open_items" -gt 0 ] || [ "$n_human" -gt 0 ]; }; then
  rework=1; say "  → REVIEW 상태에 INBOX·새 커밋이 있다 = 리뷰 재작업"
fi

# --- 7. 활성 스트림 (겹치는 것만) ---
say
n_active=0; n_stale=0; shown=0
while read -r oid oref; do
  [ -z "$oid" ] || [ "$oid" = "$id" ] && continue
  is_merged "$oref" && continue
  n_active=$((n_active + 1))
  ocur="$WORK/$oid/CURRENT.md"; ost=$(section_from_ref "$oref" "$ocur" Status | head -n1 | tr -d '[:space:]'); oage=$(age_days "$oref")
  [ "$ost" = "IN_PROGRESS" ] && [ "$oage" -ge "$STALE_DAYS" ] && n_stale=$((n_stale + 1))
  ot=$(field_from_ref "$oref" "$ocur" Touches); ov=$(overlap "$touches" "$ot")
  if [ -n "$ov" ]; then
    [ "$shown" -eq 0 ] && say "active streams — Touches 가 겹치는 것:"
    shown=$((shown + 1)); say "  $oid  $(field_from_ref "$oref" "$ocur" Owner)  ${ost:-?}  ${oage}d  $(printf '%s' "$ov" | tr '\n' ';')"
  fi
done <<EOF
$(ws_refs)
EOF
say "active streams: ${n_active}개 (겹침 ${shown}, stale IN_PROGRESS ${n_stale}) — 전체는 scripts/ai-stream.sh status"

# --- 8. 시작 컨텍스트 크기 (Rule 12) ---
say
files="AGENTS.md $CURRENT $HANDOFF"; [ -f "$LOCAL/MEMORY.md" ] && files="$files $LOCAL/MEMORY.md"
[ -n "$plan" ] && [ -f "$plan" ] && files="$files $plan"
total=0; for f in $files; do size=$(wc -c < "$f" | tr -d ' '); total=$((total + size)); done
say "startup context: $(( (total + 512) / 1024 ))KB — $files"
[ "$total" -gt 25600 ] && say "  → 25KB 초과. CURRENT/HANDOFF/PLAN 을 줄인다 (Rule 12)."
[ "$(lines "$CURRENT")" -gt 50 ] && say "  → CURRENT.md $(lines "$CURRENT")줄 (상한 50)"
[ "$(lines "$HANDOFF")" -gt 60 ] && say "  → HANDOFF.md $(lines "$HANDOFF")줄 (상한 60)"

# --- 9. next steps ---
say
say "next steps:"
n=1
if [ "$status" = "IN_PROGRESS" ]; then say "  $n. Resume (Rule 11) — uncommitted diff 를 HANDOFF 의 Work In Progress·위 progress 와 대조: 일치하면 그 step 부터 잇고, 아니면 직접 수정으로 취급. 먼저 test."; n=$((n + 1)); fi
if [ "$rework" -eq 1 ]; then say "  $n. 재작업 (Rule 11) — INBOX 의 리뷰 요청을 처리한다. CURRENT Status=IN_PROGRESS 로 바꾸고 LOG 항목을 추가, 끝나면 다시 ai-end.sh --ready."; n=$((n + 1)); fi
if [ "$unacked_req" -gt 0 ]; then say "  $n. 공지 확인 (Rule 5) — Required 공지 ${unacked_req}개의 Action 을 수행하고 CURRENT 의 Acked: 에 id 를 적는다. 확인 전에는 PR 이 병합되지 않는다."; n=$((n + 1));
elif [ "$unacked" -gt 0 ]; then say "  $n. 공지 확인 (Rule 5) — 미확인 ${unacked}개. 해당되면 Action 수행, 아니면 Acked 에 적기만."; n=$((n + 1)); fi
if [ "${spec_hits:-0}" -gt 0 ]; then say "  $n. main 유입 spec 변경 반영 (Rule 4) — 위 파일을 Relevant Docs·구현에 반영하고 LOG 의 Upstream changes 에 적는다."; n=$((n + 1)); fi
if [ "$n_human" -gt 0 ] || [ "$open_items" -gt 0 ] || [ -n "$status_out" ]; then say "  $n. 직접 수정·INBOX 반영 (Rule 4·5) — 되돌리지 말고 spec·PLAN·HANDOFF 에 반영, LOG 의 Developer changes 에 기록."; n=$((n + 1)); fi
say "  $n. ${plan:-현재 Phase PLAN.md} 에서 Task·Acceptance Criteria 확인. CURRENT 의 Relevant Documents·Source Files 만 읽는다."; n=$((n + 1))
say "  $n. CURRENT.md: Status=IN_PROGRESS, Progress 에 step 목록(≤10). HANDOFF.md: Goal·Work In Progress 초안 (handoff-first, Rule 10)."; n=$((n + 1))
say "  $n. 구현 — step 마다 Progress 갱신, 긴 Task 는 WIP 커밋(Wip: trailer). 끝나면 scripts/ai-end.sh, Task 완료면 git merge main → scripts/ai-end.sh --ready."
rm -f "$tmp" "$tmp".*
exit 0
