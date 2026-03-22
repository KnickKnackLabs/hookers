#!/usr/bin/env bats

load dashboard-helpers

@test "--color adds ANSI codes" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "test", "command": "echo hello"}]}
EOF
  run run_dashboard --color
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033['* ]]
  [[ "$output" == *"test:"* ]]
  [[ "$output" == *"hello"* ]]
}

@test "--no-color suppresses ANSI codes" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "test", "command": "echo hello"}]}
EOF
  run run_dashboard --no-color
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\033['* ]]
}
