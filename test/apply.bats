#!/usr/bin/env bats

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_DIR="$(mktemp -d)"
  TEST_SETTINGS="$TEST_DIR/.claude/settings.local.json"
  mkdir -p "$TEST_DIR/.claude"
  echo '{}' > "$TEST_SETTINGS"
}

teardown() {
  rm -rf "$TEST_DIR"
}

run_apply() {
  CALLER_PWD="$TEST_DIR" mise -C "$REPO_DIR" run -q apply -- --scope local "$@"
}

run_unapply() {
  CALLER_PWD="$TEST_DIR" mise -C "$REPO_DIR" run -q unapply -- --scope local "$@"
}

run_list() {
  CALLER_PWD="$TEST_DIR" mise -C "$REPO_DIR" run -q list -- --scope local "$@"
}

@test "apply single hook" {
  run run_apply session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 new"* ]]

  # Verify hook is in settings
  run jq '.hooks.SessionStart | length' "$TEST_SETTINGS"
  [ "$output" = "1" ]
}

@test "apply is idempotent" {
  run run_apply session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 new"* ]]

  run run_apply session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]
}

@test "apply detects updated hooks" {
  run run_apply session-id
  [ "$status" -eq 0 ]

  # Manually change the command (simulating a catalog update)
  jq '.hooks.SessionStart[0].hooks[0].command = "bash -c '\''# hookers:session-id\necho old'\''"' \
    "$TEST_SETTINGS" > "$TEST_SETTINGS.tmp" && mv "$TEST_SETTINGS.tmp" "$TEST_SETTINGS"

  run run_apply session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 updated"* ]]
}

@test "apply multiple hooks" {
  run run_apply session-id anti-compact
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 new"* ]]

  # Verify both events exist
  EVENTS=$(jq '.hooks | keys | length' "$TEST_SETTINGS")
  [ "$EVENTS" -eq 2 ]
}

@test "apply all hooks when no args given" {
  run run_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"new"* ]]
}

@test "apply --dry-run does not modify settings" {
  run run_apply --dry-run session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would add"* ]]

  # Settings should still be empty
  HOOKS=$(jq '.hooks // {} | length' "$TEST_SETTINGS")
  [ "$HOOKS" -eq 0 ]
}

@test "apply rejects unknown hook name" {
  run run_apply nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"No catalog entry"* ]]
}

@test "unapply removes hook by marker" {
  run run_apply session-id
  [ "$status" -eq 0 ]

  run run_unapply session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 1"* ]]

  # Settings should have no hooks
  HOOKS=$(jq '.hooks // {} | length' "$TEST_SETTINGS")
  [ "$HOOKS" -eq 0 ]
}

@test "unapply preserves other hooks" {
  run run_apply session-id dashboard
  [ "$status" -eq 0 ]

  run run_unapply session-id
  [ "$status" -eq 0 ]

  # Dashboard should still be there
  run run_list --json
  [[ "$output" == *"hookers:dashboard"* ]]
  [[ "$output" != *"hookers:session-id"* ]]
}

@test "unapply reports missing hooks" {
  run run_unapply session-id
  [ "$status" -eq 0 ]
  [[ "$output" == *"No hooks found"* ]]
}

@test "full cycle: apply, unapply, re-apply" {
  run run_apply session-id
  [[ "$output" == *"1 new"* ]]

  run run_unapply session-id
  [[ "$output" == *"Removed 1"* ]]

  run run_apply session-id
  [[ "$output" == *"1 new"* ]]
}
