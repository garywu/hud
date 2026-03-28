#!/usr/bin/env bash
# Pomodoro plugin — countdown timer, reads state from state.json
set -euo pipefail

STATE_DIR="$HOME/.atlas/plugins/pomodoro"
STATE_FILE="$STATE_DIR/state.json"

# Initialize state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
    cat > "$STATE_FILE" <<'EOF'
{"status":"idle","end_time":0,"work_minutes":25,"break_minutes":5}
EOF
fi

# Handle start/stop commands via first argument
case "${1:-tick}" in
    start)
        WORK_MIN="${PLUGIN_WORK_MINUTES:-25}"
        END_TIME=$(( $(date +%s) + WORK_MIN * 60 ))
        cat > "$STATE_FILE" <<EOF
{"status":"work","end_time":$END_TIME,"work_minutes":$WORK_MIN,"break_minutes":${PLUGIN_BREAK_MINUTES:-5}}
EOF
        echo "Pomodoro started: $WORK_MIN minutes"
        exit 0
        ;;
    stop)
        cat > "$STATE_FILE" <<'EOF'
{"status":"idle","end_time":0,"work_minutes":25,"break_minutes":5}
EOF
        echo "Pomodoro stopped"
        exit 0
        ;;
esac

# Tick: read state and push to HUD
STATUS=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('status','idle'))" 2>/dev/null || echo "idle")
END_TIME=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('end_time',0))" 2>/dev/null || echo "0")

if [[ "$STATUS" == "idle" ]]; then
    curl -s -X POST localhost:7070/notify \
        -H "Content-Type: application/json" \
        -d '{
        "source": "pomodoro",
        "level": "passive",
        "title": "READY",
        "renderer": "lcd",
        "presentation": "static",
        "size": "medium",
        "color": "green"
    }'
    exit 0
fi

NOW=$(date +%s)
REMAINING=$(( END_TIME - NOW ))

if [[ $REMAINING -le 0 ]]; then
    # Timer expired
    if [[ "$STATUS" == "work" ]]; then
        # Switch to break
        BREAK_MIN=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('break_minutes',5))" 2>/dev/null || echo "5")
        NEW_END=$(( NOW + BREAK_MIN * 60 ))
        cat > "$STATE_FILE" <<EOF
{"status":"break","end_time":$NEW_END,"work_minutes":25,"break_minutes":$BREAK_MIN}
EOF
        curl -s -X POST localhost:7070/notify \
            -H "Content-Type: application/json" \
            -d '{
            "source": "pomodoro",
            "level": "active",
            "title": "BREAK TIME",
            "renderer": "lcd",
            "presentation": "static",
            "size": "large",
            "color": "green"
        }'
    else
        # Break over, go idle
        cat > "$STATE_FILE" <<'EOF'
{"status":"idle","end_time":0,"work_minutes":25,"break_minutes":5}
EOF
        curl -s -X POST localhost:7070/notify \
            -H "Content-Type: application/json" \
            -d '{
            "source": "pomodoro",
            "level": "active",
            "title": "SESSION DONE",
            "renderer": "lcd",
            "presentation": "static",
            "size": "large",
            "color": "amber"
        }'
    fi
    exit 0
fi

# Format remaining time as MM:SS
MINS=$(( REMAINING / 60 ))
SECS=$(( REMAINING % 60 ))
TIME_STR=$(printf "%02d:%02d" "$MINS" "$SECS")

# Color based on status
COLOR="red"
[[ "$STATUS" == "break" ]] && COLOR="green"

curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"pomodoro\",
    \"level\": \"passive\",
    \"title\": \"$TIME_STR\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"$COLOR\"
}"
