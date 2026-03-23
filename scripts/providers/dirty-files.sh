#!/usr/bin/env bash
# Dashboard provider: count of uncommitted changes
DIR="${HOOKERS_CWD:-.}"
git -C "$DIR" status --short 2>/dev/null | wc -l | tr -d ' '
