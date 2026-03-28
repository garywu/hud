#!/usr/bin/env bash
# Fetch weather from wttr.in and push to HUD LCD
WEATHER=$(curl -s "wttr.in/?format=%t+%C" 2>/dev/null | head -1)
TEMP=$(echo "$WEATHER" | awk '{print $1}')
COND=$(echo "$WEATHER" | cut -d' ' -f2-)

curl -s -X POST http://localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"weather\",
    \"level\": \"passive\",
    \"title\": \"${TEMP} ${COND}\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"large\",
    \"color\": \"amber\"
  }"
