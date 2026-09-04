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
is_work_working() {
  [[ "$1" == *"red;brightness;39"* ]] && [[ "$1" == *"green;brightness;136"* ]] && [[ "$1" == *"blue;brightness;232"* ]]
}
is_work_idle() {
  [[ "$1" == *"red;brightness;24"* ]] && [[ "$1" == *"green;brightness;59"* ]] && [[ "$1" == *"blue;brightness;91"* ]]
}
# Personal palette (pc alias → CLAUDE_CONFIG_DIR=~/.claude-personal).
is_personal_working() {
  [[ "$1" == *"red;brightness;50"* ]] && [[ "$1" == *"green;brightness;184"* ]] && [[ "$1" == *"blue;brightness;102"* ]]
}
is_personal_idle() {
  [[ "$1" == *"red;brightness;29"* ]] && [[ "$1" == *"green;brightness;73"* ]] && [[ "$1" == *"blue;brightness;52"* ]]
}

# --- Tests ---

@test "early exit when not iTerm" {
  unset TERM_PROGRAM
  run_hook "UserPromptSubmit"
  [ ! -s "$TTY_OUT" ]
}

@test "UserPromptSubmit sets work tab to bright blue" {
  run_hook "UserPromptSubmit"
  is_work_working "$(cat "$TTY_OUT")"
}

@test "PermissionRequest sets work tab to dark blue and creates approval flag" {
  run_hook "PermissionRequest"
  is_work_idle "$(cat "$TTY_OUT")"
  [ -f "$APPROVAL_FLAG" ]
}

@test "PostToolUse after PermissionRequest clears flag and goes bright blue" {
  run_hook "PermissionRequest"
  [ -f "$APPROVAL_FLAG" ]
  : > "$TTY_OUT"
  run_hook "PostToolUse"
  is_work_working "$(cat "$TTY_OUT")"
  [ ! -f "$APPROVAL_FLAG" ]
}

@test "PostToolUse without pending approval sets bright blue" {
  run_hook "PostToolUse"
  is_work_working "$(cat "$TTY_OUT")"
  [ ! -f "$APPROVAL_FLAG" ]
}

@test "UserPromptSubmit clears approval flag" {
  run_hook "PermissionRequest"
  [ -f "$APPROVAL_FLAG" ]
  : > "$TTY_OUT"
  run_hook "UserPromptSubmit"
  [ ! -f "$APPROVAL_FLAG" ]
  is_work_working "$(cat "$TTY_OUT")"
}

@test "Notification always sets dark blue" {
  run_hook "Notification"
  is_work_idle "$(cat "$TTY_OUT")"
}

@test "Notification after Stop stays dark blue" {
  run_hook "Stop"
  : > "$TTY_OUT"
  run_hook "Notification"
  is_work_idle "$(cat "$TTY_OUT")"
}

@test "Stop clears approval flag and sets dark blue" {
  run_hook "PermissionRequest"
  : > "$TTY_OUT"
  run_hook "Stop"
  [ ! -f "$APPROVAL_FLAG" ]
  is_work_idle "$(cat "$TTY_OUT")"
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

@test "personal config uses bright green while working" {
  export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
  run_hook "UserPromptSubmit"
  is_personal_working "$(cat "$TTY_OUT")"
}

@test "personal config uses dark green while idle" {
  export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
  run_hook "Stop"
  is_personal_idle "$(cat "$TTY_OUT")"
}

@test "teams config keeps the blue work palette" {
  export CLAUDE_CONFIG_DIR="$HOME/.claude-teams"
  run_hook "UserPromptSubmit"
  is_work_working "$(cat "$TTY_OUT")"
}
