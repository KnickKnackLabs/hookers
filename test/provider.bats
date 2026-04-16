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

@test "model provider reads HOOKERS_MODEL" {
  HOOKERS_MODEL="openai/gpt-5.4" run hookers provider model
  [ "$status" -eq 0 ]
  [ "$output" = "openai/gpt-5.4" ]
}

@test "model provider falls back to provider and id" {
  HOOKERS_MODEL_PROVIDER="openai" HOOKERS_MODEL_ID="gpt-5.4" run hookers provider model
  [ "$status" -eq 0 ]
  [ "$output" = "openai/gpt-5.4" ]
}
