#!/usr/bin/env bash
# Dashboard provider: authenticated GitHub username
gh api /user --jq '.login' 2>/dev/null
