#!/usr/bin/env bash
# Show git status of current work directory
cd /Users/admin/Work/atlas 2>/dev/null || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
AHEAD=$(git rev-list @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')

STATUS="${BRANCH} ${CHANGES}M ${AHEAD}↑"

curl -s -X POST http://localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"git-status\",
    \"level\": \"passive\",
    \"title\": \"$STATUS\",
    \"renderer\": \"text\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"green\"
  }"
