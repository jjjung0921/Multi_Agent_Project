# common.sh — scripts/ai-*.sh 가 source 하는 공통 함수. bash 3.2+ (macOS 기본 bash), git 2.23+ 만 가정한다.
# 직접 실행하지 않는다.

# 한글 등 멀티바이트 문자열 처리를 위해 UTF-8 로케일이 없으면(CI 등) 지정한다 — macOS 터미널은 보통 이미 설정되어 있다
[ -n "${LANG:-}${LC_ALL:-}" ] || export LANG=C.UTF-8
AI_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: git 저장소 안에서 실행한다" >&2; exit 1; }
cd "$AI_ROOT"

SEP=$'\x1f'
WORK=".ai/work"
TEAM=".ai/team"
LOCAL=".ai/local"
SPEC_PATHS="docs/PRD.md docs/ARCHITECTURE.md docs/api AGENTS.md"
STALE_DAYS=${AI_STALE_DAYS:-3}
LOG_FMT='%h %as %s | %(trailers:key=Task,valueonly,separator=%x2C) %(trailers:key=Stream,valueonly,separator=%x2C) %(trailers:key=Wip,valueonly,separator=%x2C)'
today=$(date +%F)
FAILED=0

say()  { printf '%s\n' "$*"; }
ok()   { printf '  [ok]   %s\n' "$*"; }
warn() { printf '  [warn] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAILED=1; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

have_origin()    { git remote get-url origin >/dev/null 2>&1; }
main_ref()       { if have_origin && git rev-parse -q --verify refs/remotes/origin/main >/dev/null 2>&1; then echo origin/main; else echo main; fi; }
fetch_quiet()    { if have_origin; then git fetch --quiet --prune origin >/dev/null 2>&1 || true; fi; }
current_branch() { git symbolic-ref -q --short HEAD 2>/dev/null || echo ""; }
stream_from_branch() { case "$1" in ws/*) echo "${1#ws/}";; *) echo "";; esac; }
my_email()       { git config user.email 2>/dev/null || echo ""; }
short()          { git rev-parse --short "$1" 2>/dev/null; }

# "- Key: value" 형식의 머리 필드
field()          { sed -n "s/^- $2: *//p" "$1" 2>/dev/null | head -n1; }
field_from_ref() { git show "$1:$2" 2>/dev/null | sed -n "s/^- $3: *//p" | head -n1; }
# "## Header" 섹션 본문 (헤더·주석·빈 줄 제외)
section()        { sed -n "/^## $2/,/^## /p" "$1" 2>/dev/null | grep -vE '^(## |<!--|-->|$)' || true; }
section_from_ref() { git show "$1:$2" 2>/dev/null | sed -n "/^## $3/,/^## /p" | grep -vE '^(## |<!--|-->|$)' || true; }
strip_comments() { awk '/<!--/ { c = 1 } !c { print } /-->/ { c = 0 }' "$1"; }
lines()          { wc -l < "$1" | tr -d ' '; }
count_bullets()  { section "$1" "$2" | grep -c '^- ' || true; }
trailer()        { git log -1 --format="%(trailers:key=$2,valueonly,separator=%x2C)" "$1" 2>/dev/null; }

# ws 브랜치 목록: "id ref" (origin 이 있으면 원격, 없으면 로컬)
ws_refs() {
  if have_origin; then
    git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/ws/' | while read -r r; do echo "${r#origin/ws/} $r"; done
  else
    git for-each-ref --format='%(refname:short)' 'refs/heads/ws/' | while read -r r; do echo "${r#ws/} $r"; done
  fi
}
# 스트림 브랜치가 살아 있는가 — origin 이 있으면 원격만 본다 (병합 후 남은 로컬 브랜치는 활성이 아니다)
ws_ref_exists() {
  if have_origin; then git show-ref --verify -q "refs/remotes/origin/ws/$1" 2>/dev/null
  else git show-ref --verify -q "refs/heads/ws/$1" 2>/dev/null; fi
}
is_merged()     { git merge-base --is-ancestor "$1" "$(main_ref)" 2>/dev/null; }
age_days()      { local ts; ts=$(git log -1 --format=%ct "$1" 2>/dev/null || echo 0); echo $(( ( $(date +%s) - ts ) / 86400 )); }

# Touches 목록 정규화: 쉼표 구분 → 한 줄에 하나 (백틱·공백 제거)
touches_of() { printf '%s' "$1" | tr ',' '\n' | sed 's/`//g; s/^ *//; s/ *$//' | grep -v '^$' | grep -v '^none$' || true; }
# path 가 Touches 접두 중 하나에 속하면 0
path_in_touches() {
  local p=$1 t found=1
  while read -r t; do
    t=${t%%#*}; t=${t#./}
    if [ "$t" = "." ] || { [ -n "$t" ] && [ "${p#$t}" != "$p" ]; }; then found=0; break; fi
  done <<EOF
$(touches_of "$2")
EOF
  return $found
}
# 두 Touches 목록의 겹침 (접두 매칭; spec 조각은 둘 다 있을 때만 비교)
overlap() {
  local a b pa pb fa fb
  touches_of "$1" | while read -r a; do
    pa=${a%%#*}; fa=${a#"$pa"}
    touches_of "$2" | while read -r b; do
      pb=${b%%#*}; fb=${b#"$pb"}
      if [ "${pa#$pb}" = "$pa" ] && [ "${pb#$pa}" = "$pb" ]; then continue; fi
      if [ -n "$fa" ] && [ -n "$fb" ] && [ "$fa" != "$fb" ]; then continue; fi
      echo "$a ~ $b"
    done
  done
}

# 공지의 Applies to 가 내 Touches 에 해당하는가 — announcement_applies "<applies-to>" "<touches>" → 0 이면 해당
announcement_applies() {
  local app=$1 touches=$2 t
  case "$app" in
    ""|all) return 0;;
    touches:*) overlap "$touches" "${app#touches:}" | grep -q . && return 0; return 1;;
    *) while read -r t; do t=${t%%#*}; t=${t#./}; case "$t" in "$app"/*|"$app") return 0;; esac; done <<EOF
$(touches_of "$touches")
EOF
       return 1;;
  esac
}

# 비밀값 패턴 (인자: 경로들)
secret_scan() {
  grep -rnEi \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'sk-[A-Za-z0-9]{20,}' \
    -e 'gh[pousr]_[A-Za-z0-9]{30,}' \
    -e '-----BEGIN [A-Z ]*PRIVATE KEY' \
    -e '(password|passwd|secret|token|api[_-]?key)["'"'"']? *[:=] *["'"'"']?[A-Za-z0-9/+_-]{12,}' \
    "$@" 2>/dev/null | grep -v '_template' || true
}

# 템플릿 치환: render FILE (환경변수 R_STREAM … 사용)
render() {
  local c; c=$(cat "$1")
  c=${c//\{\{STREAM\}\}/$R_STREAM}; c=${c//\{\{OWNER\}\}/$R_OWNER}; c=${c//\{\{TASK\}\}/$R_TASK}
  c=${c//\{\{TOUCHES\}\}/$R_TOUCHES}; c=${c//\{\{SUPERSEDES\}\}/$R_SUPERSEDES}; c=${c//\{\{PHASE\}\}/$R_PHASE}
  c=${c//\{\{TASK_TITLE\}\}/$R_TASK_TITLE}; c=${c//\{\{CHECKPOINT\}\}/$R_CHECKPOINT}; c=${c//\{\{PLAN\}\}/$R_PLAN}
  c=${c//\{\{DATE\}\}/$today}; c=${c//\{\{SLUG\}\}/$R_SLUG}
  printf '%s\n' "$c"
}

# 파일의 "## Header" 섹션 첫 줄 값
status_of()      { section "$1" Status | head -n1 | tr -d '[:space:]'; }
checkpoint_of()  { section "$1" "Last Checkpoint" | grep -oE '^`[0-9a-f]{7,40}`$' | head -n1 | tr -d '`' || true; }
