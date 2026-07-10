#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/iterm-tab-color.sh"

setup() {
  export TERM_PROGRAM="iTerm.app"
  # Default to the work palette; personal tests set this explicitly.
  unset CLAUDE_CONFIG_DIR
  TTY_OUT="$(mktemp)"
  export ITERM_TAB_COLOR_TTY="$TTY_OUT"
  APPROVAL_FLAG="$(mktemp -u)"
  export ITERM_TAB_COLOR_APPROVAL_FLAG="$APPROVAL_FLAG"
}

teardown() {
  rm -f "$TTY_OUT" "$APPROVAL_FLAG"
}

run_hook() {
  local event="$1"
  local cwd="${2:-/home/user/my-project}"
  echo "{\"hook_event_name\":\"${event}\",\"cwd\":\"${cwd}\",\"session_id\":\"TESTING\"}" | bash "$SCRIPT"
}

# State is surfaced only through tab color, not the title, so assert on color.
is_green() {
  [[ "$1" == *"red;brightness;60"* ]] && [[ "$1" == *"green;brightness;140"* ]] && [[ "$1" == *"blue;brightness;70"* ]]
}
is_yellow() {
  [[ "$1" == *"red;brightness;200"* ]] && [[ "$1" == *"green;brightness;160"* ]] && [[ "$1" == *"blue;brightness;40"* ]]
}
# Personal palette (pc alias → CLAUDE_CONFIG_DIR=~/.claude-personal).
is_blue() {
  [[ "$1" == *"red;brightness;60"* ]] && [[ "$1" == *"green;brightness;110"* ]] && [[ "$1" == *"blue;brightness;210"* ]]
}
is_orange() {
  [[ "$1" == *"red;brightness;230"* ]] && [[ "$1" == *"green;brightness;120"* ]] && [[ "$1" == *"blue;brightness;30"* ]]
}

# --- Tests ---

@test "early exit when not iTerm" {
  unset TERM_PROGRAM
  run_hook "UserPromptSubmit"
  [ ! -s "$TTY_OUT" ]
}

@test "UserPromptSubmit sets green" {
  run_hook "UserPromptSubmit"
  is_green "$(cat "$TTY_OUT")"
}

@test "PermissionRequest sets yellow and creates approval flag" {
  run_hook "PermissionRequest"
  is_yellow "$(cat "$TTY_OUT")"
  [ -f "$APPROVAL_FLAG" ]
}

@test "PostToolUse after PermissionRequest clears flag and goes green" {
  run_hook "PermissionRequest"
  [ -f "$APPROVAL_FLAG" ]
  : > "$TTY_OUT"
  run_hook "PostToolUse"
  is_green "$(cat "$TTY_OUT")"
  [ ! -f "$APPROVAL_FLAG" ]
}

@test "PostToolUse without pending approval sets green" {
  run_hook "PostToolUse"
  is_green "$(cat "$TTY_OUT")"
  [ ! -f "$APPROVAL_FLAG" ]
}

@test "UserPromptSubmit clears approval flag" {
  run_hook "PermissionRequest"
  [ -f "$APPROVAL_FLAG" ]
  : > "$TTY_OUT"
  run_hook "UserPromptSubmit"
  [ ! -f "$APPROVAL_FLAG" ]
  is_green "$(cat "$TTY_OUT")"
}

@test "Notification always sets yellow" {
  run_hook "Notification"
  is_yellow "$(cat "$TTY_OUT")"
}

@test "Notification after Stop stays yellow" {
  run_hook "Stop"
  : > "$TTY_OUT"
  run_hook "Notification"
  is_yellow "$(cat "$TTY_OUT")"
}

@test "Stop clears approval flag and sets yellow" {
  run_hook "PermissionRequest"
  : > "$TTY_OUT"
  run_hook "Stop"
  [ ! -f "$APPROVAL_FLAG" ]
  is_yellow "$(cat "$TTY_OUT")"
}

@test "SessionEnd clears flag and resets colors" {
  run_hook "PermissionRequest"
  : > "$TTY_OUT"
  run_hook "SessionEnd"
  [ ! -f "$APPROVAL_FLAG" ]
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"bg;*;default"* ]]
}

@test "project name extracted from cwd" {
  run_hook "UserPromptSubmit" "/Users/beau/p/cool-project"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"0;cool-project"* ]]
}

@test "home directory shows ~ as the title" {
  run_hook "UserPromptSubmit" "$HOME"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"0;~"* ]]
}

@test "status word is not written into the title" {
  run_hook "UserPromptSubmit"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"0;my-project"* ]]
  [[ "$output" != *"working"* ]]
}

@test "personal config uses blue while working" {
  export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
  run_hook "UserPromptSubmit"
  is_blue "$(cat "$TTY_OUT")"
}

@test "personal config uses orange while waiting" {
  export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
  run_hook "Stop"
  is_orange "$(cat "$TTY_OUT")"
}

@test "teams config keeps the work palette" {
  export CLAUDE_CONFIG_DIR="$HOME/.claude-teams"
  run_hook "UserPromptSubmit"
  is_green "$(cat "$TTY_OUT")"
}
