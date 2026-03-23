#!/usr/bin/env bats

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "provider runs bundled scripts" {
  run mise -C "$REPO_DIR" run -q provider -- git-branch
  [ "$status" -eq 0 ]
}

@test "provider rejects unknown name" {
  run mise -C "$REPO_DIR" run -q provider -- nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"No provider"* ]]
}

@test "provider forwards args to script" {
  run mise -C "$REPO_DIR" run -q provider -- time date
  [ "$status" -eq 0 ]
  # date format: "2026-03-21"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

@test "provider forwards multi-word quoted args" {
  run mise -C "$REPO_DIR" run -q provider -- echo-args "hello world" single "foo bar"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | sed -n '1p')" = "hello world" ]
  [ "$(echo "$output" | sed -n '2p')" = "single" ]
  [ "$(echo "$output" | sed -n '3p')" = "foo bar" ]
}

@test "provider handles no args" {
  run mise -C "$REPO_DIR" run -q provider -- echo-args
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
