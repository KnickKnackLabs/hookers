#!/usr/bin/env bats

load dashboard-helpers

# Helper: run dashboard with cache enabled
run_cached() {
  HOOKERS_SESSION_ID="test-session" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    run run_dashboard
}

# Counter command that increments a file and outputs the new value.
# Usage in config: counter_cmd "$COUNTER_FILE"
counter_cmd() {
  echo "val=\$(( \$(cat $1) + 1 )); echo \$val; echo \$val > $1"
}

@test "cache hit skips provider execution" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  cat > "$TEST_CONFIG" << EOF
{"items": [{"label": "test", "command": "$(counter_cmd "$COUNTER")", "cache": 60}]}
EOF

  # First run — cache miss
  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 1"* ]]

  # Second run — cache hit, command should NOT run
  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 1"* ]]
  [ "$(cat "$COUNTER")" = "1" ]
}

@test "expired cache re-runs the provider" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  cat > "$TEST_CONFIG" << EOF
{"items": [{"label": "test", "command": "$(counter_cmd "$COUNTER")", "cache": 1}]}
EOF

  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 1"* ]]

  sleep 2

  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 2"* ]]
}

@test "items without cache key always run" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  cat > "$TEST_CONFIG" << EOF
{"items": [{"label": "test", "command": "$(counter_cmd "$COUNTER")"}]}
EOF

  HOOKERS_SESSION_ID="test-session" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 1"* ]]

  HOOKERS_SESSION_ID="test-session" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 2"* ]]
}

@test "no caching when HOOKERS_SESSION_ID is unset" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  cat > "$TEST_CONFIG" << EOF
{"items": [{"label": "test", "command": "$(counter_cmd "$COUNTER")", "cache": 60}]}
EOF

  # No HOOKERS_SESSION_ID set
  HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 1"* ]]

  HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 2"* ]]
}

@test "different sessions have separate caches" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "test", "command": "echo $HOOKERS_SESSION_ID", "cache": 60}]}
EOF

  HOOKERS_SESSION_ID="session-a" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: session-a"* ]]

  HOOKERS_SESSION_ID="session-b" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: session-b"* ]]
}

@test "cache hit reports zero duration" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "test", "command": "sleep 1 && echo hello", "cache": 60}]}
EOF

  # First run — slow provider
  HOOKERS_SESSION_ID="test-session" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    HOOKERS_DASHBOARD_NO_DURATION="" HOOKERS_DASHBOARD_DURATION_THRESHOLD="1" \
    run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: hello"* ]]
  [[ "$output" == *"(1s)"* ]] || [[ "$output" == *"(2s)"* ]]

  # Second run — cache hit, no duration
  HOOKERS_SESSION_ID="test-session" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    HOOKERS_DASHBOARD_NO_DURATION="" HOOKERS_DASHBOARD_DURATION_THRESHOLD="1" \
    run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: hello"* ]]
  [[ "$output" != *"(1s)"* ]]
  [[ "$output" != *"(2s)"* ]]
}

@test "duplicate commands at different positions have separate caches" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "first", "command": "date +%s%N", "cache": 60},
  {"label": "second", "command": "date +%s%N", "cache": 60}
]}
EOF

  run_cached
  [ "$status" -eq 0 ]
  # Both items run the same command but should cache independently
  # Extract values — they may differ due to nanosecond timing
  local first second
  first=$(echo "$output" | grep -o 'first: [0-9]*' | cut -d' ' -f2)
  second=$(echo "$output" | grep -o 'second: [0-9]*' | cut -d' ' -f2)
  [ -n "$first" ]
  [ -n "$second" ]

  # Second run — both should return their own cached values
  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"first: $first"* ]]
  [[ "$output" == *"second: $second"* ]]
}

@test "failed provider does not cache empty result" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  # Command that fails first time (outputs nothing), succeeds second time
  cat > "$TEST_CONFIG" << EOF
{"items": [{"label": "test", "command": "val=\$(( \$(cat $COUNTER) + 1 )); echo \$val > $COUNTER; if [ \$val -ge 2 ]; then echo ok; fi", "cache": 60}]}
EOF

  # First run — counter=1, outputs nothing (below threshold)
  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" != *"test:"* ]]

  # Second run — counter=2, should output "ok" (not stuck on cached empty)
  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: ok"* ]]
}

@test "cache TTL of 0 disables caching" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  cat > "$TEST_CONFIG" << EOF
{"items": [{"label": "test", "command": "$(counter_cmd "$COUNTER")", "cache": 0}]}
EOF

  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 1"* ]]

  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"test: 2"* ]]
}

@test "mixed cached and uncached items" {
  COUNTER="$TEST_HOME/counter"
  echo "0" > "$COUNTER"

  cat > "$TEST_CONFIG" << EOF
{"items": [
  {"label": "cached", "command": "echo stable", "cache": 60},
  {"label": "live", "command": "$(counter_cmd "$COUNTER")"}
]}
EOF

  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"cached: stable"* ]]
  [[ "$output" == *"live: 1"* ]]

  run_cached
  [ "$status" -eq 0 ]
  [[ "$output" == *"cached: stable"* ]]
  [[ "$output" == *"live: 2"* ]]
}
