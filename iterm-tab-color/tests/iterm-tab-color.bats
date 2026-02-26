#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/iterm-tab-color.sh"

setup() {
  export TERM_PROGRAM="iTerm.app"
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
  echo "{\"hook_event_name\":\"${event}\",\"cwd\":\"${cwd}\"}" | bash "$SCRIPT"
}

# --- Tests ---

@test "early exit when not iTerm" {
  unset TERM_PROGRAM
  run_hook "UserPromptSubmit"
  [ ! -s "$TTY_OUT" ]
}

@test "UserPromptSubmit sets green and working" {
  run_hook "UserPromptSubmit"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;60"* ]]
  [[ "$output" == *"green;brightness;140"* ]]
  [[ "$output" == *"blue;brightness;70"* ]]
  [[ "$output" == *"working"* ]]
}

@test "PermissionRequest sets yellow and creates approval flag" {
  run_hook "PermissionRequest"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;200"* ]]
  [[ "$output" == *"green;brightness;160"* ]]
  [[ "$output" == *"blue;brightness;40"* ]]
  [[ "$output" == *"approval"* ]]
  [ -f "$APPROVAL_FLAG" ]
}

@test "PostToolUse after PermissionRequest stays yellow" {
  run_hook "PermissionRequest"
  : > "$TTY_OUT"
  run_hook "PostToolUse"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;200"* ]]
  [[ "$output" == *"approval"* ]]
  [ -f "$APPROVAL_FLAG" ]
}

@test "PostToolUse without pending approval sets green" {
  run_hook "PostToolUse"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;60"* ]]
  [[ "$output" == *"working"* ]]
  [ ! -f "$APPROVAL_FLAG" ]
}

@test "UserPromptSubmit clears approval flag" {
  run_hook "PermissionRequest"
  [ -f "$APPROVAL_FLAG" ]
  : > "$TTY_OUT"
  run_hook "UserPromptSubmit"
  [ ! -f "$APPROVAL_FLAG" ]
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"working"* ]]
}

@test "PreToolUse sets green and working" {
  run_hook "PreToolUse"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;60"* ]]
  [[ "$output" == *"working"* ]]
}

@test "PreToolUse clears approval flag" {
  run_hook "PermissionRequest"
  [ -f "$APPROVAL_FLAG" ]
  : > "$TTY_OUT"
  run_hook "PreToolUse"
  [ ! -f "$APPROVAL_FLAG" ]
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"working"* ]]
}

@test "Notification without approval stays green" {
  run_hook "Notification"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;60"* ]]
  [[ "$output" == *"working"* ]]
}

@test "Notification during approval stays yellow" {
  run_hook "PermissionRequest"
  : > "$TTY_OUT"
  run_hook "Notification"
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;200"* ]]
  [[ "$output" == *"approval"* ]]
}

@test "Stop clears approval flag and sets done" {
  run_hook "PermissionRequest"
  : > "$TTY_OUT"
  run_hook "Stop"
  [ ! -f "$APPROVAL_FLAG" ]
  output="$(cat "$TTY_OUT")"
  [[ "$output" == *"red;brightness;200"* ]]
  [[ "$output" == *"done"* ]]
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
  [[ "$output" == *"cool-project"* ]]
}
