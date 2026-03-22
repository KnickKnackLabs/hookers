#!/usr/bin/env bats

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

run_time() {
  mise -C "$REPO_DIR" run -q provider -- time "$@"
}

@test "time defaults to datetime" {
  run run_time
  [ "$status" -eq 0 ]
  # "2026-03-21 14:23 UTC"
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}\ [A-Z]+$ ]]
}

@test "time time format" {
  run run_time time
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{2}:[0-9]{2}\ [A-Z]+$ ]]
}

@test "time date format" {
  run run_time date
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

@test "time day format" {
  run run_time day
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)$ ]]
}

@test "time unix format" {
  run run_time unix
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "time with timezone" {
  run run_time time America/New_York
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{2}:[0-9]{2}\ (EST|EDT)$ ]]
}

@test "time rejects unknown format" {
  run run_time bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown format"* ]]
}
