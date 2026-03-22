#!/usr/bin/env bats

load dashboard-helpers

@test "--no-labels hides labels and prefix" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "a", "command": "echo one"},
  {"label": "b", "command": "echo two"}
]}
EOF
  run run_dashboard --no-labels
  [ "$status" -eq 0 ]
  [[ "$output" == "one | two" ]]
}
