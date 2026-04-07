#!/usr/bin/env bats

load dashboard-helpers

@test "--no-labels hides labels but keeps prefix" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "a", "command": "echo one"},
  {"label": "b", "command": "echo two"}
]}
EOF
  run run_dashboard --no-labels --no-duration
  [ "$status" -eq 0 ]
  [[ "$output" == "[dashboard] one | two" ]]
}

@test "--no-labels --no-prefix hides both" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "a", "command": "echo one"},
  {"label": "b", "command": "echo two"}
]}
EOF
  run run_dashboard --no-labels --no-prefix --no-duration
  [ "$status" -eq 0 ]
  [[ "$output" == "one | two" ]]
}
