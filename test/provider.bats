#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/test_helper.bash"
}

@test "provider runs bundled scripts" {
  run hookers provider git-branch
  [ "$status" -eq 0 ]
}

@test "provider rejects unknown name" {
  run hookers provider nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"No provider"* ]]
}

@test "provider forwards args to script" {
  run hookers provider time date
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}
