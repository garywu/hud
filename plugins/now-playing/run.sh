#!/usr/bin/env bash
# Get currently playing from macOS Music/Spotify
TRACK=$(osascript -e 'tell application "Music" to get name of current track' 2>/dev/null || \
        osascript -e 'tell application "Spotify" to get name of current track' 2>/dev/null || \
        echo "")

ARTIST=$(osascript -e 'tell application "Music" to get artist of current track' 2>/dev/null || \
         osascript -e 'tell application "Spotify" to get artist of current track' 2>/dev/null || \
         echo "")

if [ -n "$TRACK" ]; then
  curl -s -X POST http://localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
      \"source\": \"now-playing\",
      \"level\": \"passive\",
      \"title\": \"$ARTIST - $TRACK\",
      \"renderer\": \"text\",
      \"presentation\": \"static\",
      \"size\": \"medium\"
    }"
fi
