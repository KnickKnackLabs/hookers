#!/usr/bin/env bash
# Dashboard provider: current git repo (owner/name from remote origin)
# Uses HOOKERS_CWD (set by dashboard.sh from Claude Code's hook context)
set -euo pipefail
DIR="${HOOKERS_CWD:-.}"
git -C "$DIR" remote get-url origin 2>/dev/null | sed 's|.*github\.com[:/]||; s|\.git$||'
