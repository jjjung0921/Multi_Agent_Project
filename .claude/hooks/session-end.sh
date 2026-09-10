#!/usr/bin/env bash
# Claude Code SessionEnd 훅 — 이 세션이 잡은 스트림 .lock 을 놓는다 (다음 세션이 --force 없이 시작).
# 종료 절차(test → ai-end.sh --set-checkpoint → close commit → push)는 대신하지 않는다 — 그건 Agent 가 AGENTS.md 대로 한다.
set -u
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" || exit 0
branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
case "$branch" in ws/*) rm -f ".ai/work/${branch#ws/}/.lock";; esac
exit 0
