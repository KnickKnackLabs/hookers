#!/usr/bin/env bash
# Dashboard provider: current git repo (owner/name from remote origin)
# Uses HOOKERS_DASHBOARD_CWD (set by dashboard.sh from Claude Code's hook context)
DIR="${HOOKERS_DASHBOARD_CWD:-.}"
git -C "$DIR" remote get-url origin 2>/dev/null | sed 's|.*github\.com[:/]||; s|\.git$||'
