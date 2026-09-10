#!/usr/bin/env bash
# Claude Code SessionStart 훅 — 세션이 열릴 때 scripts/ai-start.sh 를 자동 실행하고 그 출력을 컨텍스트에 넣는다.
# 등록: .claude/settings.json (hooks.SessionStart). Codex·Gemini 등 다른 Agent 는 AGENTS.md Session Procedure 대로 직접 실행한다.
# stdin: {"source": "startup|resume|clear|compact", ...}   stdout: Agent 컨텍스트에 추가된다. 항상 exit 0.
set -u
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" || exit 0
input=$(cat 2>/dev/null || true)
source=$(printf '%s' "$input" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# 이 세션의 모든 명령에 AI_AGENT 를 남겨 commit-msg 훅이 'Agent: claude-code' trailer 를 붙이게 한다.
export AI_AGENT=claude-code
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo 'export AI_AGENT=claude-code' >> "$CLAUDE_ENV_FILE"

[ -f scripts/ai-start.sh ] || { echo "[ai-start] scripts/ai-start.sh 가 없다 — 템플릿 구조가 아니다."; exit 0; }

# startup 은 그대로, resume/clear/compact 는 같은 세션이 남긴 .lock 이므로 --force 로 이어 간다.
opt=""
case "$source" in resume|clear|compact) opt="--force";; esac

echo "[ai-start] (source=${source:-startup}) 세션 시작 점검 — 아래 next steps 를 따른다 (AGENTS.md Session Procedure)."
bash scripts/ai-start.sh $opt 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "[ai-start] exit $rc — 위 안내를 따른다: 스트림 없음 → scripts/ai-stream.sh open …, 소유자 다름 → take, 죽은 세션의 .lock → 사용자에게 확인한 뒤 scripts/ai-start.sh --force. 해결 후 scripts/ai-start.sh 를 다시 실행하고, 그 전에는 구현을 시작하지 않는다."
fi
exit 0
