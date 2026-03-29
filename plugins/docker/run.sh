#!/usr/bin/env bash
# Docker status plugin — show running containers
set -euo pipefail

# Check if docker is available
if ! command -v docker &>/dev/null; then
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"docker\",
    \"level\": \"passive\",
    \"title\": \"DOCKER: NOT INSTALLED\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"small\",
    \"color\": \"red\"
  }"
  exit 0
fi

# Check if docker daemon is running
if ! docker info &>/dev/null; then
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"docker\",
    \"level\": \"passive\",
    \"title\": \"DOCKER: DAEMON OFF\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"small\",
    \"color\": \"red\"
  }"
  exit 0
fi

COUNT=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
NAMES=$(docker ps --format '{{.Names}}' 2>/dev/null | head -3 | tr '\n' ' ')

if [ "$COUNT" = "0" ] || [ -z "$COUNT" ]; then
  MSG="DOCKER: NO CONTAINERS"
  COLOR="blue"
else
  MSG="DOCKER: ${COUNT} UP ${NAMES}"
  COLOR="green"
fi

curl -s -X POST localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
  \"source\": \"docker\",
  \"level\": \"passive\",
  \"title\": \"$MSG\",
  \"renderer\": \"lcd\",
  \"presentation\": \"static\",
  \"size\": \"small\",
  \"color\": \"$COLOR\"
}"
