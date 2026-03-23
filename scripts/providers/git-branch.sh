#!/usr/bin/env bash
# Dashboard provider: current git branch
# Uses HOOKERS_CWD (set by dashboard.sh from Claude Code's hook context)
# to report the workspace branch, not the provider's own repo branch.
DIR="${HOOKERS_CWD:-.}"
git -C "$DIR" branch --show-current 2>/dev/null
