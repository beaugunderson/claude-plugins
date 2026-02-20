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

if [ "$EVENT" = "SessionEnd" ]; then
  printf "\033]6;1;bg;*;default\a" > /dev/tty 2>/dev/null || true
  printf "\033]0;\a" > /dev/tty 2>/dev/null || true
  exit 0
fi

case "$EVENT" in
  UserPromptSubmit|PostToolUse)
                     R=60  G=140 B=70;  STATUS="working"  ;;
  Stop)              R=200 G=160 B=40;  STATUS="done"     ;;
  PermissionRequest) R=200 G=160 B=40;  STATUS="approval" ;;
  *)                 R=200 G=160 B=40;  STATUS="waiting"  ;;
esac

printf "\033]6;1;bg;red;brightness;%d\a"   "$R" > /dev/tty 2>/dev/null || true
printf "\033]6;1;bg;green;brightness;%d\a" "$G" > /dev/tty 2>/dev/null || true
printf "\033]6;1;bg;blue;brightness;%d\a"  "$B" > /dev/tty 2>/dev/null || true
printf "\033]0;%s: %s\a" "$PROJECT" "$STATUS" > /dev/tty 2>/dev/null || true
