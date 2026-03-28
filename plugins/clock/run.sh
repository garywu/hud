#!/usr/bin/env bash
# Clock plugin — show current time on LCD
set -euo pipefail

FORMAT="${PLUGIN_FORMAT:-24h}"

if [[ "$FORMAT" == "12h" ]]; then
    TIME=$(date +"%I:%M:%S %p")
else
    TIME=$(date +%H:%M:%S)
fi

curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"clock\",
    \"level\": \"passive\",
    \"title\": \"$TIME\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"blue\"
}"
