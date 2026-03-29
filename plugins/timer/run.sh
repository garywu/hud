#!/usr/bin/env bash
# Timer plugin — countdown with alert on completion
# Usage: Create state file to start a timer
#   echo '{"target":1711900000,"label":"Focus"}' > ~/.atlas/plugins/timer/state.json
#   Or use: hud-cli timer 5m "Focus time"
set -euo pipefail

STATE_DIR="$HOME/.atlas/plugins/timer"
STATE="$STATE_DIR/state.json"

# No state file = no active timer, show idle
if [ ! -f "$STATE" ]; then
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"timer\",
    \"level\": \"passive\",
    \"title\": \"TIMER: IDLE\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"blue\"
  }"
  exit 0
fi

# Parse state — handle missing jq gracefully
if command -v jq &>/dev/null; then
  TARGET=$(jq -r '.target' "$STATE" 2>/dev/null || echo "")
  LABEL=$(jq -r '.label // "TIMER"' "$STATE" 2>/dev/null || echo "TIMER")
else
  TARGET=$(python3 -c "import json; d=json.load(open('$STATE')); print(d.get('target',''))" 2>/dev/null || echo "")
  LABEL=$(python3 -c "import json; d=json.load(open('$STATE')); print(d.get('label','TIMER'))" 2>/dev/null || echo "TIMER")
fi

if [ -z "$TARGET" ]; then
  rm -f "$STATE"
  exit 0
fi

NOW=$(date +%s)
REMAINING=$((TARGET - NOW))

if [ "$REMAINING" -le 0 ]; then
  # Timer complete — send active notification
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"timer\",
    \"level\": \"active\",
    \"title\": \"$LABEL: TIME IS UP\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"red\",
    \"sound\": true
  }"
  # Play system alert sound
  afplay /System/Library/Sounds/Glass.aiff &>/dev/null &
  # Remove state so it stops alerting after one cycle
  rm -f "$STATE"
  exit 0
fi

# Format remaining time
HOURS=$((REMAINING / 3600))
MINS=$(( (REMAINING % 3600) / 60 ))
SECS=$((REMAINING % 60))

if [ "$HOURS" -gt 0 ]; then
  DISPLAY=$(printf "%s %dH%02dM%02dS" "$LABEL" "$HOURS" "$MINS" "$SECS")
else
  DISPLAY=$(printf "%s %02dM%02dS" "$LABEL" "$MINS" "$SECS")
fi

# Urgency color: green > 5m, amber > 1m, red < 1m
if [ "$REMAINING" -gt 300 ]; then
  COLOR="green"
elif [ "$REMAINING" -gt 60 ]; then
  COLOR="amber"
else
  COLOR="red"
fi

curl -s -X POST localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
  \"source\": \"timer\",
  \"level\": \"passive\",
  \"title\": \"$DISPLAY\",
  \"renderer\": \"lcd\",
  \"presentation\": \"static\",
  \"size\": \"medium\",
  \"color\": \"$COLOR\"
}"
