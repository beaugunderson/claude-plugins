#!/usr/bin/env bash
# iTerm2 tab color + title for Claude Code sessions
# Green = working, Yellow = waiting for you, Clear on exit
[[ "${TERM_PROGRAM:-}" != "iTerm.app" ]] && exit 0

INPUT=$(cat)

# Extract fields from JSON without python — values are simple strings, no escaping needed
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)
CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4)
TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
PROJECT="${CWD##*/}"
PROJECT="${PROJECT:-claude}"

# Output target — overridable for testing
TTY="${ITERM_TAB_COLOR_TTY:-/dev/tty}"

# State file so "approval" persists across PostToolUse events from sub-agents.
# session_id is stable across all hook invocations in one session.
APPROVAL_FLAG="${ITERM_TAB_COLOR_APPROVAL_FLAG:-/tmp/iterm-tab-color-approval-${SESSION_ID}}"

# Debug logging — set ITERM_TAB_COLOR_DEBUG=1 to enable
DEBUG_LOG="${ITERM_TAB_COLOR_DEBUG_LOG:-/tmp/iterm-tab-color-debug.log}"
debug() {
  [[ "${ITERM_TAB_COLOR_DEBUG:-}" == "1" ]] || return 0
  local approval_exists="no"
  [[ -f "$APPROVAL_FLAG" ]] && approval_exists="yes"
  printf "%s sid=%-8s event=%-20s tool=%-20s approval_flag=%s → %s (%s)\n" \
    "$(date '+%H:%M:%S.%3N' 2>/dev/null || date '+%H:%M:%S')" \
    "${SESSION_ID:0:8}" "$EVENT" "${TOOL:-—}" "$approval_exists" "$STATUS" "$1" \
    >> "$DEBUG_LOG" 2>/dev/null || true
}

if [ "$EVENT" = "SessionEnd" ]; then
  rm -f "$APPROVAL_FLAG"
  STATUS="reset"; debug "clear"
  printf "\033]6;1;bg;*;default\a" >> "$TTY" 2>/dev/null || true
  printf "\033]0;\a" >> "$TTY" 2>/dev/null || true
  exit 0
fi

case "$EVENT" in
  PermissionRequest)
    touch "$APPROVAL_FLAG"
    R=200 G=160 B=40; STATUS="approval" ;;
  UserPromptSubmit)
    rm -f "$APPROVAL_FLAG"
    R=60  G=140 B=70; STATUS="working"  ;;
  PostToolUse|Notification)
    if [ -f "$APPROVAL_FLAG" ]; then
      R=200 G=160 B=40; STATUS="approval"
    else
      R=60  G=140 B=70; STATUS="working"
    fi ;;
  Stop)
    rm -f "$APPROVAL_FLAG"
    R=200 G=160 B=40; STATUS="done"     ;;
  *)
    R=200 G=160 B=40; STATUS="waiting"  ;;
esac

debug "$( [[ "$R" -eq 60 ]] && echo green || echo yellow )"

printf "\033]6;1;bg;red;brightness;%d\a"   "$R" >> "$TTY" 2>/dev/null || true
printf "\033]6;1;bg;green;brightness;%d\a" "$G" >> "$TTY" 2>/dev/null || true
printf "\033]6;1;bg;blue;brightness;%d\a"  "$B" >> "$TTY" 2>/dev/null || true
printf "\033]0;%s: %s\a" "$PROJECT" "$STATUS" >> "$TTY" 2>/dev/null || true
