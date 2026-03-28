#!/usr/bin/env bash
# System Monitor plugin — reads CPU load and pushes to HUD as sparkline
set -euo pipefail

LOAD=$(sysctl -n vm.loadavg | awk '{print $2}')
CORES=$(sysctl -n hw.ncpu)
PCT=$(echo "$LOAD $CORES" | awk '{printf "%.0f", ($1/$2)*100}')

curl -s -X POST localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
  \"source\": \"system-monitor\",
  \"level\": \"passive\",
  \"title\": \"CPU ${PCT}%\",
  \"renderer\": \"text\",
  \"presentation\": \"static\",
  \"size\": \"small\"
}"
