#!/usr/bin/env bash
# ai-stream.sh — 스트림·Phase·이력 관리. bash 3.2+, git 2.23+.
#
#   open <NN>/<Tk> <slug> [--reopen]            Task 스트림 열기 (브랜치 ws/<id> + .ai/work/<id>/ + push)
#   open spec|chore|plan|phase-close <slug> --touches a,b [--reopen]
#   take                                         현재 스트림 인수 (Owner 변경 커밋 + push)
#   status                                       팀 현황판 (원격 ws/* 에서 도출)
#   gc [--dry-run]                               병합되고 브랜치가 없는 스트림 디렉터리 삭제 (git rm, 커밋은 호출자)
#   merge [<id>] [--title "<제목>"]              개인용: --ci 후 로컬 --no-ff 병합
#   tag <NN>                                     phase/<NN> 태그 (병합 후)
#   phases [--check]                             docs/phases/README.md 표 생성 / 검사
#   phase new <name>                             다음 번호로 Phase 골격 + 계획 스트림
#   history [--type t] [--scope s] [--phase NN] [--task P/T] [--stream id] [--agent a] [--spec] [--no-ai] [--branches] [-n N] [-- path]
#   digest [--since <date>]                      병합된 스트림들의 LOG 로 다이제스트 (stdout)
#   announce [--check]                           .ai/team/README.md 공지 색인 생성 / 검사
#   codeowners [--check]                         ARCHITECTURE Owner 열 → .github/CODEOWNERS
#   setup [--local [--local-memory <path>]] [--check]   저장소 설정(리드) / clone 설정(팀원)
#   flow review|maintain|setup                   flow 역할 프롬프트 + 컨텍스트 출력

set -eo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

stream_exists() { ws_ref_exists "$1" || git cat-file -e "$(main_ref):$WORK/$1/CURRENT.md" 2>/dev/null; }

bookkeep_commit() { # bookkeep_commit <subject> <task> <stream>
  git commit -q -m "$1" --trailer "Agent: ${AI_AGENT:-ai-stream}" --trailer "Task: $2" --trailer "Stream: $3"
}
push_branch() {
  if ! have_origin; then say "(origin 없음 — push 생략)"; return 0; fi
  if git push -q -u origin "$1" 2>/dev/null; then say "pushed $1"
  else warn "push 실패 (오프라인·인증?) — 나중에 'git push -u origin $1'. push 전까지는 팀에 보이지 않는다 (Rule 15)"; fi
}

# ---------------------------------------------------------------- open
cmd_open() {
  local kind="" slug="" reopen=0 touches="" task="" phase="" id="" plan="" task_title="" supersedes="none"
  while [ $# -gt 0 ]; do
    case "$1" in
      --reopen) reopen=1;;
      --touches) touches=${2:-}; shift;;
      --*) die "알 수 없는 옵션 $1";;
      *) if [ -z "$kind" ]; then kind=$1; elif [ -z "$slug" ]; then slug=$1; else die "인자가 너무 많다: $1"; fi;;
    esac; shift
  done
  [ -n "$kind" ] && [ -n "$slug" ] || usage 1
  git diff --quiet && git diff --cached --quiet || die "커밋되지 않은 변경이 있다 — 먼저 커밋하거나 stash 한다"
  fetch_quiet
  local base; base=$(main_ref)
  case "$kind" in
    [0-9][0-9]/T[0-9]*)
      phase=${kind%%/*}; task=$kind; id="${phase}-${kind#*/}-${slug}"
      plan=$(ls -d docs/phases/"${phase}"-*/PLAN.md 2>/dev/null | head -n1)
      [ -n "$plan" ] || die "Phase $phase 의 PLAN.md 가 없다 (docs/phases/${phase}-*/PLAN.md)"
      local tline; tline=$(grep -E "^- \[[ x]\] ${kind#*/}\. " "$plan" | head -n1 || true)
      [ -n "$tline" ] || die "$plan 에 Task ${kind#*/} 항목이 없다"
      task_title=$(printf '%s' "$tline" | sed -E 's/^- \[[ x]\] //; s/ — Done when:.*//')
      [ -z "$touches" ] && touches=$(printf '%s' "$tline" | sed -n 's/.*Touches: *//p' | sed 's/ · Owner:.*//; s/`//g')
      [ -n "$touches" ] || die "PLAN 의 Task 줄에 Touches: 가 없다 — 적거나 --touches 로 지정한다"
      local other
      for other in $(ws_refs | awk '{print $1}') $(git ls-tree --name-only "$base" "$WORK/" 2>/dev/null | sed "s#.*/##"); do
        case "$other" in "${phase}-${kind#*/}-"*)
          if [ "$reopen" -eq 1 ]; then supersedes=$other; else die "같은 Task 의 스트림이 있다: $other (병합된 Task 를 다시 열려면 --reopen)"; fi;;
        esac
      done
      ;;
    spec|chore|plan|phase-close)
      case "$kind" in
        phase-close) id="phase-${slug}-close"; task="${slug}/-"; touches=${touches:-"docs/phases/${slug}-*/,$WORK/"}; task_title="Phase $slug 종료";;
        plan)        id="plan-${slug}";        task="${slug%%-*}/-"; touches=${touches:-"docs/phases/${slug}/"}; task_title="Phase $slug 계획";;
        *)           id="${kind}-${slug}";     task="-/-"; task_title="${kind}: ${slug}";;
      esac
      [ -n "$touches" ] || die "--touches 를 지정한다 (예: --touches docs/api/openapi.yaml#/orders)"
      ;;
    *) usage 1;;
  esac
  if stream_exists "$id"; then
    [ "$reopen" -eq 1 ] || die "스트림 $id 가 이미 있다 (브랜치 또는 main). 재개하려면 --reopen"
    [ "$supersedes" = "none" ] && supersedes=$id
    local n=2
    while stream_exists "${id}-r${n}"; do n=$((n + 1)); done
    id="${id}-r${n}"
  fi

  say "stream: $id  task: $task  touches: $touches"
  local oid oref ot ov ocount=0
  while read -r oid oref; do
    [ -z "$oid" ] && continue
    is_merged "$oref" && continue
    ocount=$((ocount + 1))
    ot=$(field_from_ref "$oref" "$WORK/$oid/CURRENT.md" Touches)
    ov=$(overlap "$touches" "$ot")
    [ -n "$ov" ] && say "  겹침 경고: $oid ($(field_from_ref "$oref" "$WORK/$oid/CURRENT.md" Owner)) — $(printf '%s' "$ov" | tr '\n' ';')"
  done <<EOF
$(ws_refs)
EOF
  say "  활성 스트림 ${ocount}개 확인"

  if git show-ref --verify -q "refs/heads/ws/$id"; then
    if have_origin && is_merged "ws/$id"; then git branch -q -D "ws/$id"; else die "로컬 브랜치 ws/$id 가 이미 있다"; fi
  fi
  git checkout -q -b "ws/$id" "$base"
  mkdir -p "$WORK/$id/notes"
  R_STREAM=$id R_OWNER=$(my_email) R_TASK=$task R_TOUCHES=$touches R_SUPERSEDES=$supersedes R_TASK_TITLE=$task_title R_CHECKPOINT=$(short "$base")
  if [ -n "$plan" ]; then R_PHASE="${plan#docs/phases/}"; R_PHASE="${R_PHASE%/PLAN.md} — \`$plan\`"; R_PLAN="\`$plan\`"; else R_PHASE="— (Task 밖 스트림)"; R_PLAN="\`AGENTS.md\`"; fi
  export R_STREAM R_OWNER R_TASK R_TOUCHES R_SUPERSEDES R_TASK_TITLE R_CHECKPOINT R_PHASE R_PLAN
  local f
  for f in CURRENT HANDOFF LOG INBOX; do render "$WORK/_template/$f.md" > "$WORK/$id/$f.md"; done
  cp "$WORK/_template/notes/README.md" "$WORK/$id/notes/README.md"
  git add "$WORK/$id"
  bookkeep_commit "ai($id): open" "$task" "$id"
  push_branch "ws/$id"
  say "opened ws/$id → $WORK/$id/  다음: scripts/ai-start.sh"
}

# ---------------------------------------------------------------- take
cmd_take() {
  local br id ref owner me to age ans task
  br=$(current_branch); id=$(stream_from_branch "$br"); [ -n "$id" ] || die "ws/* 브랜치가 아니다"
  fetch_quiet
  if have_origin && git show-ref --verify -q "refs/remotes/origin/ws/$id"; then
    ref="origin/ws/$id"
    git merge -q --ff-only "$ref" 2>/dev/null || die "로컬 ws/$id 가 origin 과 갈라져 있다 — 먼저 맞춘다"
  else ref="ws/$id"; fi
  owner=$(field "$WORK/$id/CURRENT.md" Owner); me=$(my_email)
  [ -n "$me" ] || die "git config user.email 이 없다"
  [ "$owner" = "$me" ] && die "이미 내 스트림이다"
  to=$(field "$WORK/$id/HANDOFF.md" To); age=$(age_days "$ref")
  if [ "$to" != "$me" ] && [ "$age" -lt "$STALE_DAYS" ] && [ -z "${AI_FORCE:-}" ]; then
    printf '소유자 %s 의 마지막 push 는 %s일 전이고 HANDOFF To: 는 "%s" 다. 인수할까? [y/N] ' "$owner" "$age" "$to"
    read -r ans; [ "$ans" = "y" ] || exit 1
  fi
  awk -v me="$me" '/^- Owner: /{print "- Owner: " me; next}{print}' "$WORK/$id/CURRENT.md" > "$WORK/$id/CURRENT.md.tmp" && mv "$WORK/$id/CURRENT.md.tmp" "$WORK/$id/CURRENT.md"
  awk '/^- To: /{print "- To: 없음"; next}{print}' "$WORK/$id/HANDOFF.md" > "$WORK/$id/HANDOFF.md.tmp" && mv "$WORK/$id/HANDOFF.md.tmp" "$WORK/$id/HANDOFF.md"
  task=$(field "$WORK/$id/CURRENT.md" Task)
  git add "$WORK/$id"
  bookkeep_commit "ai($id): take from $owner" "$task" "$id"
  push_branch "ws/$id"
  say "took $id (owner: $owner → $me). HANDOFF.md 를 읽고 scripts/ai-start.sh"
}

# ---------------------------------------------------------------- status
cmd_status() {
  fetch_quiet
  local tmp; tmp=$(mktemp -t ai-status.XXXXXX)
  local id ref cur owner task st touches age flag phase me
  me=$(my_email)
  while read -r id ref; do
    [ -z "$id" ] && continue
    is_merged "$ref" && continue
    cur="$WORK/$id/CURRENT.md"
    owner=$(field_from_ref "$ref" "$cur" Owner); task=$(field_from_ref "$ref" "$cur" Task)
    st=$(section_from_ref "$ref" "$cur" Status | head -n1 | tr -d '[:space:]'); touches=$(field_from_ref "$ref" "$cur" Touches)
    age=$(age_days "$ref"); flag=""
    [ "$st" = "IN_PROGRESS" ] && [ "$age" -ge "$STALE_DAYS" ] && flag="stale"
    case "$id" in [0-9][0-9]-*) phase=${id%%-*};; plan-[0-9][0-9]*) phase=$(printf '%s' "$id" | sed -E 's/^plan-([0-9]{2}).*/\1/');; phase-[0-9][0-9]-close) phase=$(printf '%s' "$id" | sed -E 's/^phase-([0-9]{2}).*/\1/');; *) phase="--";; esac
    printf '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' "$phase" "$SEP" "$id" "$SEP" "${owner:-?}" "$SEP" "${task:-?}" "$SEP" "${st:-?}" "$SEP" "${age}d" "$SEP" "$flag" "$SEP" "$touches" >> "$tmp"
  done <<EOF
$(ws_refs)
EOF
  if [ ! -s "$tmp" ]; then say "active streams: (없음)"; rm -f "$tmp"; return 0; fi
  say "active streams ($(main_ref) 기준, 미병합 ws/* — $(wc -l < "$tmp" | tr -d ' ')개):"
  sort -t "$SEP" -k1,1 -k2,2 "$tmp" | awk -F "$SEP" -v me="$me" '
    { if ($1 != last) { printf "  phase %s\n", $1; last = $1 }
      you = ($3 == me) ? " (you)" : ""
      printf "    %-28s %-26s %-8s %-12s %5s %s\n", $2, $3 you, $4, $5, $6, ($7 != "" ? "← " $7 : "") }'
  # 겹침
  local a b ta tb ov shown=0
  while IFS="$SEP" read -r _ a _ _ _ _ _ ta; do
    while IFS="$SEP" read -r _ b _ _ _ _ _ tb; do
      [ "$a" \< "$b" ] || continue
      ov=$(overlap "$ta" "$tb")
      if [ -n "$ov" ]; then [ "$shown" -eq 0 ] && say "  touches overlap:"; shown=1; say "    $a ~ $b: $(printf '%s' "$ov" | tr '\n' ';')"; fi
    done < "$tmp"
  done < "$tmp"
  rm -f "$tmp"
}

# ---------------------------------------------------------------- gc
cmd_gc() {
  local dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
  fetch_quiet
  local d id base n=0; base=$(main_ref)
  for d in "$WORK"/*/; do
    id=$(basename "$d"); [ "$id" = "_template" ] && continue
    if ws_ref_exists "$id"; then continue; fi
    if ! git cat-file -e "$base:$WORK/$id/CURRENT.md" 2>/dev/null; then say "  skip $id — main 에 없다 (병합되지 않은 스트림?)"; continue; fi
    n=$((n + 1))
    if [ "$dry" -eq 1 ]; then say "  would remove $WORK/$id/"; else git rm -rq "$WORK/$id" && say "  removed $WORK/$id/"; fi
  done
  [ "$n" -eq 0 ] && say "gc: 정리할 스트림 없음" || { [ "$dry" -eq 1 ] || say "gc: ${n}개 삭제를 스테이징했다 — 커밋: git commit -m 'ai(phase-NN-close): gc ${n} streams'"; }
}

# ---------------------------------------------------------------- merge (solo)
cmd_merge() {
  local id="" title=""
  while [ $# -gt 0 ]; do case "$1" in --title) title=${2:-}; shift;; *) id=$1;; esac; shift; done
  [ -n "$id" ] || id=$(stream_from_branch "$(current_branch)")
  [ -n "$id" ] || die "스트림 id 를 주거나 ws/* 브랜치에서 실행한다"
  git diff --quiet && git diff --cached --quiet || die "커밋되지 않은 변경이 있다"
  git checkout -q "ws/$id"
  say "== ai-end.sh --ci (ws/$id)"; CI_BASE=main bash scripts/ai-end.sh --ci || die "--ci 실패 — 고친 뒤 다시"
  local task goal; task=$(field "$WORK/$id/CURRENT.md" Task); goal=$(section "$WORK/$id/HANDOFF.md" Goal | head -n1)
  [ -n "$title" ] || title="chore($id): ${goal:-merge stream} [$task]"
  git checkout -q main
  git merge -q --no-ff -m "$title" -m "$(printf 'Stream: %s\nTask: %s' "$id" "$task")" "ws/$id"
  git branch -q -d "ws/$id"
  say "merged ws/$id into main: $title"
}

# ---------------------------------------------------------------- tag
cmd_tag() {
  local nn=${1:-}; [ -n "$nn" ] || usage 1
  git tag -a "phase/$nn" -m "Phase $nn done" "$(main_ref)"
  if have_origin; then git push -q origin "phase/$nn"; fi
  say "tagged phase/$nn at $(short "$(main_ref)")"
}

# ---------------------------------------------------------------- phases
gen_phases_table() {
  local d nn name plan st lead dep done_n total res
  printf '| #  | Phase | Lead | Depends on | Status | Tasks | Result |\n|----|-------|------|------------|--------|-------|--------|\n'
  for d in docs/phases/[0-9][0-9]-*/; do
    [ -d "$d" ] || continue
    plan="${d}PLAN.md"; [ -f "$plan" ] || continue
    nn=$(basename "$d" | cut -c1-2); name=$(basename "$d" | cut -c4-)
    st=$(field "$plan" Status | awk '{print $1}'); lead=$(field "$plan" Lead); dep=$(field "$plan" "Depends on")
    done_n=$(grep -cE '^- \[x\] T[0-9]+\.' "$plan" || true); total=$(grep -cE '^- \[[ x]\] T[0-9]+\.' "$plan" || true)
    if [ -f "${d}RESULT.md" ]; then res="[RESULT](${nn}-${name}/RESULT.md)"; else res="—"; fi
    printf '| %s | [%s](%s-%s/PLAN.md) | %s | %s | %s | %s/%s | %s |\n' "$nn" "$name" "$nn" "$name" "${lead:-?}" "${dep:-none}" "${st:-?}" "${done_n:-0}" "${total:-0}" "$res"
  done
}
# replace_between FILE BEGIN_MARK END_MARK NEWFILE — 두 마커 사이를 NEWFILE 내용으로 바꾼다
replace_between() {
  local f=$1 b=$2 e=$3 nf=$4 tmp; tmp=$(mktemp -t ai-rb.XXXXXX)
  awk -v b="$b" -v e="$e" -v nf="$nf" '
    index($0, b) { print; while ((getline line < nf) > 0) print line; skip = 1; next }
    index($0, e) { skip = 0 }
    !skip { print }' "$f" > "$tmp" && mv "$tmp" "$f"
}
# check_between FILE BEGIN_MARK END_MARK NEWFILE — 같으면 0
check_between() {
  local cur; cur=$(mktemp -t ai-cb.XXXXXX)
  sed -n "/$2/,/$3/p" "$1" | grep -v -e "$2" -e "$3" > "$cur" || true
  if diff -q "$cur" "$4" >/dev/null; then rm -f "$cur"; return 0; else diff "$cur" "$4" || true; rm -f "$cur"; return 1; fi
}
cmd_phases() {
  local f="docs/phases/README.md" new rc=0; new=$(mktemp -t ai-ph.XXXXXX)
  gen_phases_table > "$new"
  if [ "${1:-}" = "--check" ]; then check_between "$f" '<!-- phases:begin -->' '<!-- phases:end -->' "$new" || rc=1; rm -f "$new"; return $rc; fi
  replace_between "$f" '<!-- phases:begin -->' '<!-- phases:end -->' "$new"; rm -f "$new"
  say "docs/phases/README.md 표를 갱신했다"
}
cmd_phase() {
  [ "${1:-}" = "new" ] && [ -n "${2:-}" ] || usage 1
  local name=$2 max=0 d nn cand
  fetch_quiet
  for d in $(ls -d docs/phases/[0-9][0-9]-*/ 2>/dev/null; git ls-tree --name-only "$(main_ref)" docs/phases/ 2>/dev/null); do
    cand=$(basename "$d" | cut -c1-2); case "$cand" in [0-9][0-9]) [ "${cand#0}" -gt "$max" ] && max=${cand#0};; esac
  done
  nn=$(printf '%02d' $((max + 1)))
  cmd_open plan "${nn}-${name}" --touches "docs/phases/${nn}-${name}/"
  mkdir -p "docs/phases/${nn}-${name}"
  sed "s/^# Phase NN — <phase-name>/# Phase ${nn} — ${name}/" docs/phases/_template/PLAN.md > "docs/phases/${nn}-${name}/PLAN.md"
  cmd_phases >/dev/null
  git add docs/phases
  bookkeep_commit "plan(docs): add phase ${nn}-${name} skeleton" "${nn}/-" "plan-${nn}-${name}"
  push_branch "ws/plan-${nn}-${name}"
  say "phase ${nn}-${name}: PLAN.md 골격 생성. 머리(Lead·Depends on)와 Tasks(Touches) 를 채우고 --ready 로 계획 PR 을 낸다"
}

# ---------------------------------------------------------------- history
cmd_history() {
  local n=20 fp=1 noai=0 withpr=0 path="" greps=() ref
  ref=$(main_ref)
  while [ $# -gt 0 ]; do
    case "$1" in
      --type)   greps+=("--grep=^$2\\(");                   shift;;
      --scope)  greps+=("--grep=^[a-z-]*\\($2");            shift;;
      --phase)  greps+=("--grep=(\\[$2/|^Task: $2/)");       shift;;
      --task)   greps+=("--grep=(\\[$2\\]|^Task: $2\$)"); fp=0; withpr=1; shift;;
      --stream) greps+=("--grep=^Stream: $2\$"); fp=0;      shift;;
      --agent)  greps+=("--grep=^Agent: $2\$"); fp=0;       shift;;
      --spec)   greps+=("--grep=^Spec: yes");;
      --no-ai)  noai=1;;
      --branches) fp=0;;
      --with-pr) withpr=1;;
      -n)       n=$2; shift;;
      --)       shift; path=$*; break;;
      *) die "알 수 없는 옵션 $1";;
    esac; shift
  done
  local args=(--format="$LOG_FMT" -n "$n" --extended-regexp --all-match)
  [ ${#greps[@]} -gt 0 ] && args+=("${greps[@]}")
  if [ "$fp" -eq 1 ]; then args+=(--first-parent "$ref"); else args+=(--all); fi
  if [ "$noai" -eq 1 ]; then
    git log "${args[@]}" -- $path | grep -v ' ai(' || true
  else
    git log "${args[@]}" -- $path || true
  fi
}

# ---------------------------------------------------------------- digest
cmd_digest() {
  local since="" base h sha date subj stream; base=$(main_ref)
  while [ $# -gt 0 ]; do case "$1" in --since) since=${2:-}; shift;; esac; shift; done
  # main 의 first-parent 로그에서 Stream: trailer 가 있는 병합 커밋마다, 그 커밋 시점의 LOG.md 맨 위 항목을 뽑는다 (gc 로 지워진 스트림도 보인다)
  git log --first-parent --format="%H${SEP}%h${SEP}%as${SEP}%s${SEP}%(trailers:key=Stream,valueonly,separator=%x2C)" ${since:+--since="$since"} "$base" -- \
  | while IFS="$SEP" read -r h sha date subj stream; do
    [ -z "$stream" ] && continue
    stream=${stream%%,*}
    git cat-file -e "$h:$WORK/$stream/LOG.md" 2>/dev/null || continue
    printf '## %s · %s · %s\n\n' "$date" "$subj" "$sha"
    git show "$h:$WORK/$stream/LOG.md" | awk '/^## /{ n++ } n == 1' | grep -v '^## ' | grep -v '^$' | sed 's/^/  /'
    printf '\n'
  done
}

# ---------------------------------------------------------------- announce
gen_announce_table() {
  local f id req app until
  printf '| 공지 | Required | Applies to | Until |\n|------|----------|------------|-------|\n'
  for f in $(ls -r "$TEAM"/announcements/*.md 2>/dev/null); do
    id=$(basename "$f" .md); [ "$id" = "_template" ] && continue
    req=$(field "$f" Required); app=$(field "$f" "Applies to"); until=$(field "$f" Until)
    printf '| [%s](announcements/%s.md) | %s | %s | %s |\n' "$id" "$id" "${req:-?}" "${app:-all}" "${until:-?}"
  done
}
cmd_announce() {
  local f="$TEAM/README.md" new rc=0; new=$(mktemp -t ai-an.XXXXXX)
  gen_announce_table > "$new"
  if [ "${1:-}" = "--check" ]; then check_between "$f" '<!-- announcements:begin -->' '<!-- announcements:end -->' "$new" || rc=1; rm -f "$new"; return $rc; fi
  replace_between "$f" '<!-- announcements:begin -->' '<!-- announcements:end -->' "$new"; rm -f "$new"
  say "$f 색인을 갱신했다"
}

# ---------------------------------------------------------------- codeowners
gen_codeowners() {
  printf '# 생성 파일 — docs/ARCHITECTURE.md Module Boundaries 의 Owner 열에서 scripts/ai-stream.sh codeowners 가 만든다. 손으로 고치지 않는다.\n'
  sed -n '/^## Module Boundaries/,/^## /p' docs/ARCHITECTURE.md | grep '^|' | awk -F'|' 'NR > 2 {
      loc = $4; own = $5; gsub(/[` ]/, "", loc); gsub(/^ +| +$/, "", own)
      if (loc == "" || own == "" || index(loc, "<") || index(own, "<")) next
      if (substr(loc, 1, 1) != "/") loc = "/" loc
      printf "%-32s %s\n", loc, own }'
}
cmd_codeowners() {
  local f=".github/CODEOWNERS" t; t=$(mktemp -t ai-co.XXXXXX)
  gen_codeowners > "$t"
  if [ "$(grep -vc '^#' "$t" || true)" -eq 0 ]; then rm -f "$t"; say "ARCHITECTURE Module Boundaries 표에 Owner 가 채워진 행이 없다 — placeholder 를 채운 뒤 다시"; return 0; fi
  if [ "${1:-}" = "--check" ]; then
    if [ -f "$f" ] && diff -q <(grep -v '^#' "$f") <(grep -v '^#' "$t") >/dev/null; then rm -f "$t"; return 0; else diff <(grep -v '^#' "$f" 2>/dev/null || true) <(grep -v '^#' "$t") || true; rm -f "$t"; return 1; fi
  fi
  mkdir -p .github; mv "$t" "$f"; say "$f 를 생성했다"
}

# ---------------------------------------------------------------- setup
cmd_setup() {
  local local_mode=0 mem="" check=0
  while [ $# -gt 0 ]; do case "$1" in --local) local_mode=1;; --local-memory) mem=${2:-}; shift;; --check) check=1;; *) die "알 수 없는 옵션 $1";; esac; shift; done
  if [ "$local_mode" -eq 1 ]; then
    git config core.hooksPath .githooks
    git config commit.template .gitmessage
    git config alias.ai-log "log --format='$LOG_FMT'"
    chmod +x .githooks/* scripts/*.sh 2>/dev/null || true
    if [ -n "$mem" ]; then
      mkdir -p "$mem"; [ -e "$LOCAL" ] && [ ! -L "$LOCAL" ] && { cp -Rn "$LOCAL"/. "$mem"/ 2>/dev/null || true; rm -rf "$LOCAL"; }
      [ -L "$LOCAL" ] || ln -s "$mem" "$LOCAL"
    fi
    mkdir -p "$LOCAL/notes"
    [ -f "$LOCAL/MEMORY.md" ] || printf '# My memory (50줄 상한, 내 Agent만 읽는다)\n\n- (아직 없음)\n' > "$LOCAL/MEMORY.md"
    [ -f "$LOCAL/INBOX.md" ] || printf '# Local inbox\n\n(비어 있음)\n' > "$LOCAL/INBOX.md"
    say "local setup: hooksPath=.githooks · commit.template=.gitmessage · alias ai-log · $LOCAL/ 준비. AI_AGENT=<이름> 환경변수를 두면 Agent: trailer 가 자동으로 붙는다."
    return 0
  fi
  say "repository setup (전략: docs/decisions/ADR-20260907-git-strategy-and-two-audiences.md)"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && have_origin; then
    if [ "$check" -eq 1 ]; then
      gh api 'repos/{owner}/{repo}' --jq '"merge_commit=\(.allow_merge_commit) squash=\(.allow_squash_merge) rebase=\(.allow_rebase_merge) delete_branch_on_merge=\(.delete_branch_on_merge) merge_title=\(.merge_commit_title) merge_message=\(.merge_commit_message)"' || true
      gh api 'repos/{owner}/{repo}/branches/main/protection' --jq '"protection: reviews=\(.required_pull_request_reviews.required_approving_review_count) checks=\(.required_status_checks.contexts)"' 2>/dev/null || say "  main 보호 규칙 없음"
      return 0
    fi
    gh repo edit --enable-merge-commit=true --enable-squash-merge=false --enable-rebase-merge=false --delete-branch-on-merge=true >/dev/null && ok "병합 방식: merge commit 만, 브랜치 자동 삭제"
    gh api -X PATCH 'repos/{owner}/{repo}' -f merge_commit_title=PR_TITLE -f merge_commit_message=PR_BODY >/dev/null && ok "병합 메시지: PR 제목 + 본문"
    printf '%s' '{"required_status_checks":{"strict":true,"contexts":["ai-check","commands"]},"enforce_admins":false,"required_pull_request_reviews":{"required_approving_review_count":1},"restrictions":null}' \
      | gh api -X PUT 'repos/{owner}/{repo}/branches/main/protection' --input - >/dev/null && ok "main 보호: PR + 리뷰 1 + 검사(ai-check, commands)" || warn "main 보호 규칙 적용 실패 — 아래 체크리스트로 수동 설정"
  else
    say "  gh 를 쓸 수 없거나 origin 이 없다 — 저장소 설정 화면에서 수동으로:"
  fi
  cat <<'EOF'
  체크리스트
  [ ] Pull requests: Allow merge commits 만 켜기 (squash · rebase 끄기), Default commit message = "Pull request title and description"
  [ ] Automatically delete head branches 켜기
  [ ] Branches → main 보호: Require a pull request (approvals 1), Require status checks (ai-check, commands), Do not allow bypassing
  [ ] CODEOWNERS: docs/ARCHITECTURE.md Owner 열 채운 뒤 scripts/ai-stream.sh codeowners
  [ ] CI: .github/workflows/ci.yml 의 Commands 4개 채우기. flow.yml 은 준비되면 켜기
  [ ] 팀원: clone 후 scripts/ai-stream.sh setup --local
EOF
}

# ---------------------------------------------------------------- flow
cmd_flow() {
  local mode=${1:-review} id br
  say "===== ROLE: .claude/agents/git-flow.md (mode: $mode) ====="; cat .claude/agents/git-flow.md; say
  say "===== CONTEXT ====="
  case "$mode" in
    review)
      br=$(current_branch); id=$(stream_from_branch "${GITHUB_HEAD_REF:-$br}")
      say "PR title: ${PR_TITLE:-(없음)}"; say "PR body:"; printf '%s\n' "${PR_BODY:-(없음)}"; say
      say "--- diff --stat ($(main_ref)...HEAD)"; git diff --stat "$(main_ref)...HEAD" || true; say
      if [ -n "$id" ] && [ -d "$WORK/$id" ]; then
        say "--- $WORK/$id/CURRENT.md"; strip_comments "$WORK/$id/CURRENT.md"; say
        say "--- $WORK/$id/HANDOFF.md"; strip_comments "$WORK/$id/HANDOFF.md"; say
        say "--- $WORK/$id/LOG.md (top)"; awk '/^## /{ n++ } n == 1' "$WORK/$id/LOG.md"; say
      fi
      say "--- ai-end.sh --ci"; bash scripts/ai-end.sh --ci || true;;
    maintain)
      say "--- status"; cmd_status; say
      say "--- gc --dry-run"; cmd_gc --dry-run; say
      say "--- phases --check"; cmd_phases --check && say "  ok" || say "  drift"; say
      say "--- codeowners --check"; cmd_codeowners --check && say "  ok" || say "  drift"; say
      say "--- announcements"; ls "$TEAM"/announcements/ 2>/dev/null | grep -v '^_' || say "  (없음)"; say
      say "--- setup --check"; cmd_setup --check;;
    setup) cmd_setup;;
    *) usage 1;;
  esac
}

# ---------------------------------------------------------------- dispatch
cmd=${1:-help}; [ $# -gt 0 ] && shift
case "$cmd" in
  open)       cmd_open "$@";;
  take)       cmd_take "$@";;
  status)     cmd_status "$@";;
  gc)         cmd_gc "$@";;
  merge)      cmd_merge "$@";;
  tag)        cmd_tag "$@";;
  phases)     cmd_phases "$@";;
  phase)      cmd_phase "$@";;
  history)    cmd_history "$@";;
  digest)     cmd_digest "$@";;
  announce)   cmd_announce "$@";;
  codeowners) cmd_codeowners "$@";;
  setup)      cmd_setup "$@";;
  flow)       cmd_flow "$@";;
  help|-h|--help) usage 0;;
  *) say "unknown command: $cmd"; usage 1;;
esac
