#!/usr/bin/env bash
# Calendar plugin — show next meeting with countdown
set -euo pipefail

# Try icalBuddy first (faster, no permissions dialog)
NEXT=$(icalBuddy -n -nc -li 1 -npn -nrd -df "" -tf "%H:%M" eventsToday 2>/dev/null | head -1)

if [ -z "$NEXT" ]; then
  # Fallback to AppleScript
  NEXT=$(osascript -e 'tell application "Calendar"
    set now to current date
    set nextEvent to ""
    repeat with cal in calendars
      repeat with evt in (events of cal whose start date > now)
        set nextEvent to summary of evt & " " & time string of start date of evt
        exit repeat
      end repeat
      if nextEvent is not "" then exit repeat
    end repeat
    return nextEvent
  end tell' 2>/dev/null || true)
fi

if [ -n "$NEXT" ]; then
  # Escape quotes for JSON safety
  NEXT=$(echo "$NEXT" | sed 's/"/\\"/g')
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"calendar\",
    \"level\": \"passive\",
    \"title\": \"$NEXT\",
    \"renderer\": \"text\",
    \"presentation\": \"static\",
    \"size\": \"medium\"
  }"
else
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"calendar\",
    \"level\": \"passive\",
    \"title\": \"NO UPCOMING MEETINGS\",
    \"renderer\": \"text\",
    \"presentation\": \"static\",
    \"size\": \"medium\"
  }"
fi
