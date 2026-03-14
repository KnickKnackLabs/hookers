#!/usr/bin/env bash
# Dashboard provider: count of uncommitted changes
git status --short 2>/dev/null | wc -l | tr -d ' '
