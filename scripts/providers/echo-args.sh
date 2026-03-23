#!/usr/bin/env bash
# Test provider — echoes each arg on its own line, for verifying arg forwarding.
for arg in "$@"; do
  echo "$arg"
done
