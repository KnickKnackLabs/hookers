#!/usr/bin/env bats

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "catalog lists all hooks" {
  run mise -C "$REPO_DIR" run -q catalog
  [ "$status" -eq 0 ]
  [[ "$output" == *"session-id"* ]]
  [[ "$output" == *"anti-compact"* ]]
  [[ "$output" == *"dashboard"* ]]
  [[ "$output" == *"anti-compact-kill"* ]]
}

@test "catalog --json outputs valid JSON" {
  run mise -C "$REPO_DIR" run -q catalog -- --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null 2>&1
  [ $? -eq 0 ]
}

@test "each catalog entry has name and description" {
  run mise -C "$REPO_DIR" run -q catalog -- --json
  [ "$status" -eq 0 ]
  COUNT=$(echo "$output" | jq '[.[] | select(.name and .description)] | length')
  TOTAL=$(echo "$output" | jq 'length')
  [ "$COUNT" -eq "$TOTAL" ]
}

@test "each catalog entry has a hookers marker in its command" {
  run mise -C "$REPO_DIR" run -q catalog -- --json
  [ "$status" -eq 0 ]
  # Every hook command should contain "# hookers:<name>"
  UNMARKED=$(echo "$output" | jq '
    [.[] | . as $entry |
      .hooks | to_entries[] | .value[] | .hooks[] |
      select(.command | contains("# hookers:" + $entry.name) | not)
    ] | length
  ')
  [ "$UNMARKED" -eq 0 ]
}
