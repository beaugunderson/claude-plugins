#!/usr/bin/env bash
# iTerm2 tab color + title for Claude Code sessions
# Green = working, Yellow = waiting for you, Clear on exit
[[ "${TERM_PROGRAM:-}" != "iTerm.app" ]] && exit 0

INPUT=$(cat)

# Extract fields from JSON without python — values are simple strings, no escaping needed
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)
CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4)
PROJECT="${CWD##*/}"
PROJECT="${PROJECT:-claude}"

# Output target — overridable for testing
TTY="${ITERM_TAB_COLOR_TTY:-/dev/tty}"

# State file so "approval" persists across PostToolUse events from sub-agents.
# PPID is the claude process — shared across all hook invocations in one session.
APPROVAL_FLAG="${ITERM_TAB_COLOR_APPROVAL_FLAG:-/tmp/iterm-tab-color-approval-${PPID}}"

if [ "$EVENT" = "SessionEnd" ]; then
  rm -f "$APPROVAL_FLAG"
  printf "\033]6;1;bg;*;default\a" >> "$TTY" 2>/dev/null || true
  printf "\033]0;\a" >> "$TTY" 2>/dev/null || true
  exit 0
fi

case "$EVENT" in
  PermissionRequest)
    touch "$APPROVAL_FLAG"
    R=200 G=160 B=40; STATUS="approval" ;;
  UserPromptSubmit|PreToolUse)
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

printf "\033]6;1;bg;red;brightness;%d\a"   "$R" >> "$TTY" 2>/dev/null || true
printf "\033]6;1;bg;green;brightness;%d\a" "$G" >> "$TTY" 2>/dev/null || true
printf "\033]6;1;bg;blue;brightness;%d\a"  "$B" >> "$TTY" 2>/dev/null || true
printf "\033]0;%s: %s\a" "$PROJECT" "$STATUS" >> "$TTY" 2>/dev/null || true
