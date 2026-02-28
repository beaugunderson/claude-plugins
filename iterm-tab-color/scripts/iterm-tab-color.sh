#!/usr/bin/env bash
# iTerm2 tab color + title for Claude Code sessions
# Green = working, Yellow = waiting for you, Clear on exit

# Detect iTerm — directly or via tmux
IN_TMUX=0
if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
  [[ -n "${TMUX:-}" ]] && IN_TMUX=1
elif [[ -n "${TMUX:-}" ]]; then
  # Inside tmux without TERM_PROGRAM — check outer terminal
  if tmux show-environment TERM_PROGRAM 2>/dev/null | grep -q 'iTerm.app'; then
    IN_TMUX=1
  else
    exit 0
  fi
else
  exit 0
fi

INPUT=$(cat)

# Extract fields from JSON without python — values are simple strings, no escaping needed
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)
CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4)
TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
PROJECT="${CWD##*/}"
PROJECT="${PROJECT:-claude}"

# Output target — overridable for testing
TTY="${ITERM_TAB_COLOR_TTY:-/dev/tty}"

# State file so "approval" persists across PostToolUse events from sub-agents.
# session_id is stable across all hook invocations in one session.
APPROVAL_FLAG="${ITERM_TAB_COLOR_APPROVAL_FLAG:-/tmp/iterm-tab-color-approval-${SESSION_ID}}"

# Debug logging — set ITERM_TAB_COLOR_DEBUG=1 to enable
# Logs are split per session: /tmp/iterm-tab-color-debug/{project}-{session}.log
DEBUG_DIR="${ITERM_TAB_COLOR_DEBUG_DIR:-/tmp/iterm-tab-color-debug}"
debug() {
  [[ "${ITERM_TAB_COLOR_DEBUG:-}" == "1" ]] || return 0
  mkdir -p "$DEBUG_DIR"
  local logfile="$DEBUG_DIR/${PROJECT}-${SESSION_ID:0:8}.log"
  local approval_exists="no"
  [[ -f "$APPROVAL_FLAG" ]] && approval_exists="yes"
  # Log the user's prompt as a context separator
  if [[ "$EVENT" == "UserPromptSubmit" && -n "$PROMPT" ]]; then
    local short="${PROMPT:0:120}"
    printf "%s ── %s ──\n" \
      "$(date '+%H:%M:%S.%3N' 2>/dev/null || date '+%H:%M:%S')" "$short" \
      >> "$logfile" 2>/dev/null || true
  fi
  printf "%s %-20s tool=%-20s flag=%s → %s (%s)\n" \
    "$(date '+%H:%M:%S.%3N' 2>/dev/null || date '+%H:%M:%S')" \
    "$EVENT" "${TOOL:-—}" "$approval_exists" "$STATUS" "$1" \
    >> "$logfile" 2>/dev/null || true
}

# Send an OSC escape sequence, wrapping in DCS passthrough for tmux
# Requires: set -g allow-passthrough on  (in tmux.conf)
osc() {
  if [[ "$IN_TMUX" -eq 1 ]]; then
    printf "\033Ptmux;\033\033]%s\a\033\\\\" "$1" >> "$TTY" 2>/dev/null || true
  else
    printf "\033]%s\a" "$1" >> "$TTY" 2>/dev/null || true
  fi
}

if [ "$EVENT" = "SessionEnd" ]; then
  rm -f "$APPROVAL_FLAG"
  STATUS="reset"; debug "clear"
  osc "6;1;bg;*;default"
  osc "0;"
  exit 0
fi

case "$EVENT" in
  PermissionRequest)
    touch "$APPROVAL_FLAG"
    R=200 G=160 B=40; STATUS="approval" ;;
  UserPromptSubmit)
    rm -f "$APPROVAL_FLAG"
    R=60  G=140 B=70; STATUS="working"  ;;
  PostToolUse)
    rm -f "$APPROVAL_FLAG"
    R=60  G=140 B=70; STATUS="working"  ;;
  Notification)
    R=200 G=160 B=40; STATUS="done"     ;;
  Stop)
    rm -f "$APPROVAL_FLAG"
    R=200 G=160 B=40; STATUS="done"     ;;
  *)
    R=200 G=160 B=40; STATUS="waiting"  ;;
esac

debug "$( [[ "$R" -eq 60 ]] && echo green || echo yellow )"

osc "6;1;bg;red;brightness;$R"
osc "6;1;bg;green;brightness;$G"
osc "6;1;bg;blue;brightness;$B"
osc "0;$PROJECT: $STATUS"
