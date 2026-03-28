#!/usr/bin/env bash
# jane-hud — CLI for Atlas HUD notification system
# Talks to localhost:7070 (HUD HTTP API)
# Falls back to ~/.atlas/status.json if server unavailable
#
# Usage:
#   jane-hud notify "text" [--level active] [--renderer lcd] [--color green] [--size xl]
#   jane-hud alert "System down"              # critical, text, red
#   jane-hud info "Deploy done"               # active, text, green
#   jane-hud lcd "HELLO" [--color amber]      # lcd renderer, static
#   jane-hud rsvp "Speed reading" [--wpm 200] # text renderer, rsvp presentation
#   jane-hud scanner                           # KITT scanner mode
#   jane-hud histogram 0.3 0.7 0.5 0.9        # histogram with data
#   jane-hud queue                             # list current queue
#   jane-hud queue clear                       # clear queue
#   jane-hud dismiss <id>                      # dismiss notification
#   jane-hud config show|set|focus             # configuration
#   jane-hud capabilities                      # what can this HUD do?
#   jane-hud status                            # what's currently showing?

set -euo pipefail

HUD_URL="${HUD_URL:-http://localhost:7070}"
STATUS_FILE="$HOME/.atlas/status.json"
QUEUE_FILE="$HOME/.atlas/status-queue.json"
CONFIG_FILE="$HOME/.atlas/hud-config.json"
NOTIFY_SCRIPT="$(cd "$(dirname "$0")" && pwd)/jane-notify.sh"

# ── Colors ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────────────────

has_jq() { command -v jq &>/dev/null; }

# Pretty-print JSON — uses jq if available, otherwise raw output
pp_json() {
    if has_jq; then
        jq '.' 2>/dev/null || cat
    else
        cat
    fi
}

# Escape a string for safe JSON embedding
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Check if the HUD HTTP server is running
check_server() {
    curl -s --max-time 1 "$HUD_URL/capabilities" >/dev/null 2>&1
}

# POST JSON to the HUD server, fall back to file write
hud_post() {
    local endpoint="$1"
    local payload="$2"

    if check_server; then
        local response
        response=$(curl -s --max-time 5 -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$HUD_URL$endpoint" 2>&1)
        echo -e "${GREEN}*${RESET} Sent to HUD server"
        echo "$response" | pp_json
        return 0
    else
        return 1
    fi
}

# GET from the HUD server
hud_get() {
    local endpoint="$1"

    if check_server; then
        local response
        response=$(curl -s --max-time 5 "$HUD_URL$endpoint" 2>&1)
        echo "$response" | pp_json
        return 0
    else
        return 1
    fi
}

# Build a timestamp
now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Write status.json directly (fallback mode)
write_status_file() {
    local severity="$1"
    local source="$2"
    local message="$3"
    local banner="$4"
    local statusbar_json="$5"

    local msg_esc banner_json
    msg_esc=$(json_escape "$message")

    if [[ -n "$banner" ]]; then
        banner_json="\"$(json_escape "$banner")\""
    else
        banner_json="null"
    fi

    mkdir -p "$(dirname "$STATUS_FILE")"
    cat > "$STATUS_FILE" <<EOF
{
  "status": "$severity",
  "source": "$source",
  "message": "$msg_esc",
  "banner": $banner_json,
  "bannerStyle": null,
  "updated": "$(now_iso)",
  "details": [],
  "slots": null,
  "statusBar": $statusbar_json
}
EOF
}

# Map notification level to severity for status.json
level_to_severity() {
    case "$1" in
        critical) echo "red" ;;
        active)   echo "yellow" ;;
        passive)  echo "green" ;;
        *)        echo "green" ;;
    esac
}

# ── Commands ────────────────────────────────────────────────────────────────

cmd_notify() {
    local text=""
    local level="active"
    local renderer="text"
    local presentation="static"
    local color=""
    local size="medium"
    local mode="content"
    local data="null"
    local source="jane"

    # First positional arg is text
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        text="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --level|-l)       level="${2:-active}"; shift 2 ;;
            --renderer|-r)    renderer="${2:-text}"; shift 2 ;;
            --presentation|-p) presentation="${2:-static}"; shift 2 ;;
            --color|-c)       color="${2:-}"; shift 2 ;;
            --size|-s)        size="${2:-medium}"; shift 2 ;;
            --mode|-m)        mode="${2:-content}"; shift 2 ;;
            --data|-d)        data="$2"; shift 2 ;;
            --source)         source="${2:-jane}"; shift 2 ;;
            --wpm)            data="[${2:-150}]"; shift 2 ;;
            *)                shift ;;
        esac
    done

    if [[ -z "$text" && "$mode" == "content" ]]; then
        echo -e "${RED}Error:${RESET} notify requires text argument"
        echo "Usage: jane-hud notify \"message\" [--level active] [--renderer lcd] [--color green]"
        exit 1
    fi

    # Build data array if it's a plain number (for progress mode)
    if [[ "$data" != "null" && ! "$data" =~ ^\[ ]]; then
        data="[$data]"
    fi

    # Build statusBar JSON
    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local text_json="null"
    [[ -n "$text" ]] && text_json="\"$(json_escape "$text")\""

    local statusbar_json
    statusbar_json=$(cat <<EOF
{"mode":"$mode","renderer":"$renderer","presentation":"$presentation","size":"$size","color":$color_json,"text":$text_json,"data":$data}
EOF
)

    # Build the full notification payload
    local severity
    severity=$(level_to_severity "$level")

    # Server API expects: title, body, renderer, presentation, size, color, data at top level
    local data_field=""
    [[ "$data" != "null" ]] && data_field="\"data\":$data,"

    local color_field=""
    [[ -n "$color" ]] && color_field="\"color\":\"$color\","

    local payload
    payload=$(cat <<EOF
{
  "source": "$source",
  "level": "$level",
  "title": "$(json_escape "$text")",
  "body": "$(json_escape "$text")",
  "renderer": "$renderer",
  "presentation": "$presentation",
  "size": "$size",
  ${color_field}
  ${data_field}
  "statusBar": $statusbar_json
}
EOF
)

    # Try HTTP API first, fall back to file write
    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "$severity" "$source" "$text" "$text" "$statusbar_json"

    # Clear queue on green
    if [[ "$severity" == "green" ]]; then
        echo '{"messages":[]}' > "$QUEUE_FILE"
    fi

    echo -e "${GREEN}*${RESET} Status: $severity | Mode: $mode | Renderer: $renderer | Size: $size"
}

cmd_alert() {
    local text="${1:-}"
    shift || true
    if [[ -z "$text" ]]; then
        echo -e "${RED}Error:${RESET} alert requires a message"
        exit 1
    fi
    cmd_notify "$text" --level critical --renderer text --color red --size large "$@"
}

cmd_info() {
    local text="${1:-}"
    shift || true
    if [[ -z "$text" ]]; then
        echo -e "${RED}Error:${RESET} info requires a message"
        exit 1
    fi
    cmd_notify "$text" --level active --renderer text --color green --size medium "$@"
}

cmd_lcd() {
    local text="${1:-}"
    shift || true
    if [[ -z "$text" ]]; then
        echo -e "${RED}Error:${RESET} lcd requires text"
        exit 1
    fi
    local color="amber"
    local size="large"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-amber}"; shift 2 ;;
            --size|-s)  size="${2:-large}"; shift 2 ;;
            *)          shift ;;
        esac
    done
    cmd_notify "$text" --level active --renderer lcd --presentation static --color "$color" --size "$size"
}

cmd_rsvp() {
    local text="${1:-}"
    shift || true
    if [[ -z "$text" ]]; then
        echo -e "${RED}Error:${RESET} rsvp requires text"
        exit 1
    fi
    local wpm=150
    local renderer="text"
    local size="xl"
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --wpm|-w)      wpm="${2:-150}"; shift 2 ;;
            --lcd)         renderer="lcd"; shift ;;
            --size|-s)     size="${2:-xl}"; shift 2 ;;
            --color|-c)    color="${2:-}"; shift 2 ;;
            *)             shift ;;
        esac
    done
    local extra_args=()
    [[ -n "$color" ]] && extra_args+=(--color "$color")
    cmd_notify "$text" --level active --renderer "$renderer" --presentation rsvp --wpm "$wpm" --size "$size" "${extra_args[@]}"
}

cmd_scanner() {
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-}"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local statusbar_json="{\"mode\":\"scanner\",\"size\":\"small\",\"color\":$color_json,\"text\":null,\"data\":null,\"renderer\":null,\"presentation\":null}"

    local payload="{\"source\":\"jane\",\"level\":\"passive\",\"title\":\"Scanner active\",\"body\":\"\",\"statusBar\":$statusbar_json}"

    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "green" "jane" "Scanner active" "" "$statusbar_json"
    echo -e "${GREEN}*${RESET} Scanner mode activated"
}

cmd_histogram() {
    local values=()
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-}"; shift 2 ;;
            *)
                if [[ "$1" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                    values+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ ${#values[@]} -eq 0 ]]; then
        echo -e "${RED}Error:${RESET} histogram requires numeric data values"
        echo "Usage: jane-hud histogram 0.3 0.7 0.5 0.9"
        exit 1
    fi

    # Build JSON array
    local data_json="["
    local first=true
    for v in "${values[@]}"; do
        $first || data_json+=","
        first=false
        data_json+="$v"
    done
    data_json+="]"

    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local statusbar_json="{\"mode\":\"histogram\",\"size\":\"small\",\"color\":$color_json,\"text\":null,\"data\":$data_json,\"renderer\":null,\"presentation\":null}"

    local payload="{\"source\":\"jane\",\"level\":\"passive\",\"title\":\"Histogram\",\"body\":\"\",\"data\":$data_json,\"statusBar\":$statusbar_json}"

    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "green" "jane" "Histogram" "" "$statusbar_json"
    echo -e "${GREEN}*${RESET} Histogram: ${#values[@]} data points"
}

cmd_progress() {
    local value="${1:-}"
    shift || true
    if [[ -z "$value" ]]; then
        echo -e "${RED}Error:${RESET} progress requires a value (0.0 - 1.0)"
        exit 1
    fi
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-}"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local statusbar_json="{\"mode\":\"progress\",\"size\":\"small\",\"color\":$color_json,\"text\":null,\"data\":[$value],\"renderer\":null,\"presentation\":null}"

    local payload="{\"source\":\"jane\",\"level\":\"passive\",\"title\":\"Progress: $value\",\"body\":\"\",\"data\":[$value],\"statusBar\":$statusbar_json}"

    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "green" "jane" "Progress: $value" "" "$statusbar_json"

    # Show a visual bar
    local pct
    pct=$(printf '%.0f' "$(echo "$value * 100" | bc 2>/dev/null || echo "0")")
    local filled=$((pct / 5))
    local empty=$((20 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo -e "${GREEN}*${RESET} Progress: [${bar}] ${pct}%"
}

cmd_sparkline() {
    local values=()
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-}"; shift 2 ;;
            *)
                if [[ "$1" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                    values+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ ${#values[@]} -eq 0 ]]; then
        echo -e "${RED}Error:${RESET} sparkline requires numeric data values"
        exit 1
    fi

    local data_json="["
    local first=true
    for v in "${values[@]}"; do
        $first || data_json+=","
        first=false
        data_json+="$v"
    done
    data_json+="]"

    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local statusbar_json="{\"mode\":\"sparkline\",\"size\":\"small\",\"color\":$color_json,\"text\":null,\"data\":$data_json,\"renderer\":null,\"presentation\":null}"

    local payload="{\"source\":\"jane\",\"level\":\"passive\",\"title\":\"Sparkline\",\"body\":\"\",\"data\":$data_json,\"statusBar\":$statusbar_json}"

    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "green" "jane" "Sparkline" "" "$statusbar_json"
    echo -e "${GREEN}*${RESET} Sparkline: ${#values[@]} data points"
}

cmd_heartbeat() {
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-}"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local statusbar_json="{\"mode\":\"heartbeat\",\"size\":\"small\",\"color\":$color_json,\"text\":null,\"data\":null,\"renderer\":null,\"presentation\":null}"

    local payload="{\"source\":\"jane\",\"level\":\"passive\",\"title\":\"Heartbeat\",\"body\":\"\",\"statusBar\":$statusbar_json}"

    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "green" "jane" "Heartbeat" "" "$statusbar_json"
    echo -e "${GREEN}*${RESET} Heartbeat mode activated"
}

cmd_vu() {
    local color=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color|-c) color="${2:-}"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local color_json="null"
    [[ -n "$color" ]] && color_json="\"$color\""

    local statusbar_json="{\"mode\":\"vu\",\"size\":\"small\",\"color\":$color_json,\"text\":null,\"data\":null,\"renderer\":null,\"presentation\":null}"

    local payload="{\"source\":\"jane\",\"level\":\"passive\",\"title\":\"VU Meter\",\"body\":\"\",\"statusBar\":$statusbar_json}"

    if hud_post "/notify" "$payload"; then
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running, writing to status.json"
    write_status_file "green" "jane" "VU Meter" "" "$statusbar_json"
    echo -e "${GREEN}*${RESET} VU meter mode activated"
}

# ── Queue Management ────────────────────────────────────────────────────────

cmd_queue() {
    local action="${1:-list}"

    case "$action" in
        list)
            if hud_get "/queue"; then
                return 0
            fi
            # Fallback: read local queue file
            echo -e "${DIM}(reading local queue file)${RESET}"
            if [[ -f "$QUEUE_FILE" ]]; then
                pp_json < "$QUEUE_FILE"
            else
                echo -e "${DIM}Queue is empty${RESET}"
            fi
            ;;
        clear)
            if check_server; then
                # Get all queue items and dismiss each
                local queue_data
                queue_data=$(curl -s --max-time 5 "$HUD_URL/queue" 2>&1)
                if has_jq; then
                    local ids
                    ids=$(echo "$queue_data" | jq -r '(.pending // [])[] | .id' 2>/dev/null)
                    local active_id
                    active_id=$(echo "$queue_data" | jq -r '.active.id // empty' 2>/dev/null)
                    local count=0
                    if [[ -n "$active_id" ]]; then
                        curl -s --max-time 5 -X DELETE "$HUD_URL/notify/$active_id" >/dev/null 2>&1
                        ((count++)) || true
                    fi
                    while IFS= read -r id; do
                        [[ -z "$id" ]] && continue
                        curl -s --max-time 5 -X DELETE "$HUD_URL/notify/$id" >/dev/null 2>&1
                        ((count++)) || true
                    done <<< "$ids"
                    echo -e "${GREEN}*${RESET} Dismissed $count notifications from queue"
                else
                    echo -e "${RED}Error:${RESET} jq is required to clear queue via server"
                fi
                return 0
            fi
            echo -e "${YELLOW}*${RESET} HUD server not running, clearing local queue"
            echo '{"messages":[]}' > "$QUEUE_FILE"
            echo -e "${GREEN}*${RESET} Queue cleared"
            ;;
        *)
            echo -e "${RED}Error:${RESET} Unknown queue action: $action"
            echo "Usage: jane-hud queue [list|clear]"
            exit 1
            ;;
    esac
}

cmd_dismiss() {
    local id="${1:-}"
    if [[ -z "$id" ]]; then
        echo -e "${RED}Error:${RESET} dismiss requires a notification ID"
        echo "Usage: jane-hud dismiss <id>"
        exit 1
    fi

    # Server uses DELETE /notify/:id
    if check_server; then
        local response
        response=$(curl -s --max-time 5 -X DELETE "$HUD_URL/notify/$id" 2>&1)
        echo -e "${GREEN}*${RESET} Dismiss sent to HUD server"
        echo "$response" | pp_json
        return 0
    fi

    echo -e "${YELLOW}*${RESET} HUD server not running — cannot dismiss by ID without server"
    echo -e "${DIM}Tip: Use 'jane-hud queue clear' to clear all notifications${RESET}"
}

# ── Configuration ───────────────────────────────────────────────────────────

cmd_config() {
    local action="${1:-show}"
    shift || true

    case "$action" in
        show)
            if hud_get "/config"; then
                return 0
            fi
            echo -e "${DIM}(reading local config file)${RESET}"
            if [[ -f "$CONFIG_FILE" ]]; then
                pp_json < "$CONFIG_FILE"
            else
                echo -e "${DIM}No config file found at $CONFIG_FILE${RESET}"
                echo -e "${DIM}Using system defaults${RESET}"
            fi
            ;;
        set)
            local key="${1:-}"
            local value="${2:-}"
            if [[ -z "$key" || -z "$value" ]]; then
                echo -e "${RED}Error:${RESET} config set requires key and value"
                echo "Usage: jane-hud config set <key> <value>"
                echo "Examples:"
                echo "  jane-hud config set athena.policy allow"
                echo "  jane-hud config set athena.rateLimit 10"
                exit 1
            fi

            # Server uses PUT /config with channels array
            local payload="{\"channels\":[{\"source\":\"$(json_escape "$key")\",\"policy\":\"$(json_escape "$value")\"}]}"

            if check_server; then
                local response
                response=$(curl -s --max-time 5 -X PUT \
                    -H "Content-Type: application/json" \
                    -d "$payload" \
                    "$HUD_URL/config" 2>&1)
                echo -e "${GREEN}*${RESET} Config sent to HUD server"
                echo "$response" | pp_json
                return 0
            fi

            # Fallback: use jq to modify local config
            echo -e "${YELLOW}*${RESET} HUD server not running, updating local config"
            if has_jq && [[ -f "$CONFIG_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
                echo -e "${GREEN}*${RESET} Config updated: $key = $value"
            elif has_jq; then
                echo "{\"$key\": \"$value\"}" | jq '.' > "$CONFIG_FILE"
                echo -e "${GREEN}*${RESET} Config created: $key = $value"
            else
                echo -e "${RED}Error:${RESET} jq is required for local config edits"
                exit 1
            fi
            ;;
        focus)
            local mode="${1:-}"
            if [[ -z "$mode" ]]; then
                # No argument: show current focus state
                if hud_get "/focus"; then
                    return 0
                fi
                # Fallback: read from config file
                echo -e "${DIM}(reading local config)${RESET}"
                if has_jq && [[ -f "$CONFIG_FILE" ]]; then
                    jq '{active_focus: .active_focus, focus_scheduling: .focus_scheduling, profiles: [.focus_profiles[]?.name]}' "$CONFIG_FILE" 2>/dev/null || echo -e "${DIM}No focus config${RESET}"
                else
                    echo -e "${DIM}No focus config found${RESET}"
                fi
                return 0
            fi

            case "$mode" in
                off)
                    # Deactivate focus mode
                    if check_server; then
                        local response
                        response=$(curl -s --max-time 5 -X DELETE "$HUD_URL/focus" 2>&1)
                        echo -e "${GREEN}*${RESET} Focus mode deactivated"
                        echo "$response" | pp_json
                        return 0
                    fi
                    echo -e "${YELLOW}*${RESET} HUD server not running, updating local config"
                    if has_jq; then
                        if [[ -f "$CONFIG_FILE" ]]; then
                            local tmp; tmp=$(mktemp)
                            jq 'del(.active_focus)' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
                        fi
                        echo -e "${GREEN}*${RESET} Focus mode disabled"
                    else
                        echo -e "${RED}Error:${RESET} jq is required for local config edits"
                        exit 1
                    fi
                    ;;
                list)
                    # List all available profiles
                    if hud_get "/focus/profiles"; then
                        return 0
                    fi
                    echo -e "${DIM}(reading local config)${RESET}"
                    if has_jq && [[ -f "$CONFIG_FILE" ]]; then
                        jq '.focus_profiles // []' "$CONFIG_FILE" 2>/dev/null || echo "[]"
                    else
                        echo -e "Built-in profiles: work, sleep, personal"
                    fi
                    ;;
                schedule)
                    # Toggle scheduling: jane-hud config focus schedule on|off
                    local toggle="${2:-}"
                    if [[ -z "$toggle" ]]; then
                        echo "Usage: jane-hud config focus schedule <on|off>"
                        exit 1
                    fi
                    local enabled="true"
                    [[ "$toggle" == "off" ]] && enabled="false"

                    local payload="{\"scheduling\":$enabled}"
                    if check_server; then
                        local response
                        response=$(curl -s --max-time 5 -X PUT \
                            -H "Content-Type: application/json" \
                            -d "$payload" \
                            "$HUD_URL/focus" 2>&1)
                        echo -e "${GREEN}*${RESET} Focus scheduling: $toggle"
                        echo "$response" | pp_json
                        return 0
                    fi
                    echo -e "${YELLOW}*${RESET} HUD server not running, updating local config"
                    if has_jq && [[ -f "$CONFIG_FILE" ]]; then
                        local tmp; tmp=$(mktemp)
                        jq --argjson e "$enabled" '.focus_scheduling = $e' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
                        echo -e "${GREEN}*${RESET} Focus scheduling: $toggle"
                    fi
                    ;;
                work|sleep|personal|*)
                    # Activate a named focus profile
                    local payload="{\"name\":\"$(json_escape "$mode")\"}"
                    if check_server; then
                        local response
                        response=$(curl -s --max-time 5 -X PUT \
                            -H "Content-Type: application/json" \
                            -d "$payload" \
                            "$HUD_URL/focus" 2>&1)
                        echo -e "${GREEN}*${RESET} Focus mode: $mode"
                        echo "$response" | pp_json
                        return 0
                    fi
                    echo -e "${YELLOW}*${RESET} HUD server not running, updating local config"
                    if has_jq; then
                        if [[ -f "$CONFIG_FILE" ]]; then
                            local tmp; tmp=$(mktemp)
                            jq --arg m "$mode" '.active_focus = $m' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
                        else
                            echo "{\"active_focus\":\"$mode\"}" | jq '.' > "$CONFIG_FILE"
                        fi
                        echo -e "${GREEN}*${RESET} Focus mode: $mode"
                    else
                        echo -e "${RED}Error:${RESET} jq is required for local config edits"
                        exit 1
                    fi
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Error:${RESET} Unknown config action: $action"
            echo "Usage: jane-hud config <show|set|focus>"
            exit 1
            ;;
    esac
}

# ── Plugin Management ──────────────────────────────────────────────────────

cmd_plugin() {
    local action="${1:-}"
    shift || true

    case "$action" in
        list)
            if check_server; then
                local response
                response=$(curl -s --max-time 5 "$HUD_URL/plugins" 2>&1)
                if has_jq; then
                    echo -e "${BOLD}Installed Plugins${RESET}"
                    echo ""
                    echo "$response" | jq -r '.plugins[] | "  \(if .running then "●" else "○" end) \(.id)\t\(.name)\t\(if .running then "running (\(.tick_count) ticks)" else "stopped" end)"' 2>/dev/null
                    echo ""
                    local active
                    active=$(echo "$response" | jq -r '.active // "none"' 2>/dev/null)
                    echo -e "${DIM}Active: $active${RESET}"
                else
                    echo "$response" | pp_json
                fi
                return 0
            fi
            # Offline: scan plugin directories
            echo -e "${BOLD}Installed Plugins${RESET} ${DIM}(offline — scanning directories)${RESET}"
            echo ""
            local plugins_dir="$HOME/.atlas/plugins"
            if [[ -d "$plugins_dir" ]]; then
                for dir in "$plugins_dir"/*/; do
                    local manifest="$dir/manifest.json"
                    if [[ -f "$manifest" ]] && has_jq; then
                        local id name desc
                        id=$(jq -r '.id' "$manifest")
                        name=$(jq -r '.name' "$manifest")
                        desc=$(jq -r '.description' "$manifest")
                        echo -e "  ${CYAN}$id${RESET} — $name"
                        echo -e "    ${DIM}$desc${RESET}"
                    elif [[ -f "$manifest" ]]; then
                        echo "  $(basename "${dir%/}")"
                    fi
                done
            else
                echo -e "  ${DIM}No plugins directory found${RESET}"
            fi
            echo ""
            ;;

        start)
            local plugin_id="${1:-}"
            if [[ -z "$plugin_id" ]]; then
                echo -e "${RED}Error:${RESET} plugin start requires a plugin ID"
                echo "Usage: jane-hud plugin start <id>"
                exit 1
            fi
            if check_server; then
                local response
                response=$(curl -s --max-time 5 -X POST "$HUD_URL/plugins/$plugin_id/start" 2>&1)
                echo -e "${GREEN}*${RESET} Plugin start sent"
                echo "$response" | pp_json
            else
                echo -e "${YELLOW}*${RESET} HUD server not running — cannot start plugin"
            fi
            ;;

        stop)
            local plugin_id="${1:-}"
            if [[ -z "$plugin_id" ]]; then
                echo -e "${RED}Error:${RESET} plugin stop requires a plugin ID"
                echo "Usage: jane-hud plugin stop <id>"
                exit 1
            fi
            if check_server; then
                local response
                response=$(curl -s --max-time 5 -X POST "$HUD_URL/plugins/$plugin_id/stop" 2>&1)
                echo -e "${GREEN}*${RESET} Plugin stop sent"
                echo "$response" | pp_json
            else
                echo -e "${YELLOW}*${RESET} HUD server not running — cannot stop plugin"
            fi
            ;;

        active)
            if check_server; then
                local response
                response=$(curl -s --max-time 5 "$HUD_URL/plugins/active" 2>&1)
                echo "$response" | pp_json
            else
                echo -e "${YELLOW}*${RESET} HUD server not running"
            fi
            ;;

        install)
            local source_path="${1:-}"
            if [[ -z "$source_path" ]]; then
                echo -e "${RED}Error:${RESET} plugin install requires a source directory path"
                echo "Usage: jane-hud plugin install <path>"
                exit 1
            fi

            # Resolve to absolute path
            source_path=$(cd "$source_path" 2>/dev/null && pwd || echo "$source_path")

            if [[ ! -f "$source_path/manifest.json" ]]; then
                echo -e "${RED}Error:${RESET} No manifest.json found in $source_path"
                exit 1
            fi

            if has_jq; then
                local plugin_id
                plugin_id=$(jq -r '.id' "$source_path/manifest.json")
                local dest="$HOME/.atlas/plugins/$plugin_id"
                mkdir -p "$dest"
                cp -R "$source_path"/* "$dest/"
                # Make scripts executable
                chmod +x "$dest"/*.sh 2>/dev/null || true
                echo -e "${GREEN}*${RESET} Installed plugin: $plugin_id -> $dest"

                # Reload registry if server is running
                if check_server; then
                    curl -s --max-time 5 -X POST "$HUD_URL/plugins/reload" >/dev/null 2>&1
                    echo -e "${GREEN}*${RESET} Registry reloaded"
                fi
            else
                echo -e "${RED}Error:${RESET} jq is required for plugin install"
                exit 1
            fi
            ;;

        reload)
            if check_server; then
                local response
                response=$(curl -s --max-time 5 -X POST "$HUD_URL/plugins/reload" 2>&1)
                echo -e "${GREEN}*${RESET} Plugin registry reloaded"
                echo "$response" | pp_json
            else
                echo -e "${YELLOW}*${RESET} HUD server not running"
            fi
            ;;

        ""|help)
            echo -e "${BOLD}Plugin Management${RESET}"
            echo ""
            echo "  plugin list              List installed plugins"
            echo "  plugin start <id>        Start a plugin"
            echo "  plugin stop <id>         Stop a plugin"
            echo "  plugin active            Show active plugin"
            echo "  plugin install <path>    Install from directory"
            echo "  plugin reload            Reload plugin registry"
            ;;

        *)
            echo -e "${RED}Error:${RESET} Unknown plugin action: $action"
            echo "Usage: jane-hud plugin <list|start|stop|active|install|reload>"
            exit 1
            ;;
    esac
}

# ── Discovery ───────────────────────────────────────────────────────────────

cmd_capabilities() {
    if hud_get "/capabilities"; then
        return 0
    fi

    # Offline capabilities report
    echo -e "${BOLD}Atlas HUD Capabilities${RESET} ${DIM}(offline — reading local state)${RESET}"
    echo ""
    echo -e "${CYAN}Display Modes:${RESET}"
    echo "  scanner     KITT-style sweep animation"
    echo "  histogram   Bar chart from data array"
    echo "  sparkline   Line chart from data array"
    echo "  progress    Progress bar (0.0 - 1.0)"
    echo "  heartbeat   Pulsing heartbeat animation"
    echo "  vu          VU meter animation"
    echo "  heatmap     Heat map from data array"
    echo ""
    echo -e "${CYAN}Renderers:${RESET}"
    echo "  text        Smooth system font"
    echo "  lcd         5x7 dot-matrix pixels"
    echo ""
    echo -e "${CYAN}Presentations:${RESET}"
    echo "  static      Fixed in place"
    echo "  scroll      Scrolling left"
    echo "  rsvp        One word at a time (rapid serial visual presentation)"
    echo ""
    echo -e "${CYAN}Sizes:${RESET}"
    echo "  xs          13pt height"
    echo "  small       15pt height"
    echo "  medium      17pt height (default)"
    echo "  large       20pt height"
    echo "  xl          28pt height"
    echo ""
    echo -e "${CYAN}Colors:${RESET}"
    echo "  red green yellow blue white orange cyan amber"
    echo "  (or any hex value: #FF6600)"
    echo ""
    echo -e "${CYAN}Notification Levels:${RESET}"
    echo "  passive     Green severity — minimal display"
    echo "  active      Yellow severity — expanded display"
    echo "  critical    Red severity — full takeover"
}

cmd_status() {
    if hud_get "/status"; then
        return 0
    fi

    # Offline status report
    echo -e "${DIM}(reading local status file)${RESET}"
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo -e "${DIM}No status file found${RESET}"
        return 0
    fi

    if has_jq; then
        local status source message mode renderer size updated
        status=$(jq -r '.status // "unknown"' "$STATUS_FILE")
        source=$(jq -r '.source // "unknown"' "$STATUS_FILE")
        message=$(jq -r '.message // ""' "$STATUS_FILE")
        mode=$(jq -r '.statusBar.mode // "none"' "$STATUS_FILE")
        renderer=$(jq -r '.statusBar.renderer // "none"' "$STATUS_FILE")
        size=$(jq -r '.statusBar.size // "none"' "$STATUS_FILE")
        updated=$(jq -r '.updated // ""' "$STATUS_FILE")

        local status_color="$RESET"
        case "$status" in
            green)  status_color="$GREEN" ;;
            yellow) status_color="$YELLOW" ;;
            red)    status_color="$RED" ;;
        esac

        echo ""
        echo -e "${BOLD}Atlas HUD Status${RESET}"
        echo -e "  Severity:  ${status_color}${status}${RESET}"
        echo -e "  Source:    $source"
        echo -e "  Message:   $message"
        echo -e "  Mode:      $mode"
        echo -e "  Renderer:  $renderer"
        echo -e "  Size:      $size"
        echo -e "  Updated:   ${DIM}$updated${RESET}"
        echo ""
    else
        pp_json < "$STATUS_FILE"
    fi
}

# ── Usage ───────────────────────────────────────────────────────────────────

usage() {
    echo -e "${BOLD}jane-hud${RESET} — CLI for Atlas HUD notification system"
    echo ""
    echo -e "${CYAN}Notifications:${RESET}"
    echo "  notify <text> [opts]    Submit a notification"
    echo "    --level <l>           passive | active | critical"
    echo "    --renderer <r>        text | lcd"
    echo "    --presentation <p>    static | scroll | rsvp"
    echo "    --color <c>           red | green | amber | blue | #hex"
    echo "    --size <s>            xs | small | medium | large | xl"
    echo "    --mode <m>            content | scanner | histogram | ..."
    echo "    --data <d>            Numeric data (single value or JSON array)"
    echo "    --wpm <n>             Words per minute (for rsvp)"
    echo ""
    echo -e "${CYAN}Shortcuts:${RESET}"
    echo "  alert <text>            Critical red notification"
    echo "  info <text>             Active green notification"
    echo "  lcd <text> [--color]    LCD dot-matrix display"
    echo "  rsvp <text> [--wpm]     Speed reading display"
    echo "  scanner [--color]       KITT scanner animation"
    echo "  histogram <values...>   Bar chart display"
    echo "  progress <0.0-1.0>      Progress bar"
    echo "  sparkline <values...>   Line chart display"
    echo "  heartbeat               Heartbeat animation"
    echo "  vu                      VU meter animation"
    echo ""
    echo -e "${CYAN}Queue Management:${RESET}"
    echo "  queue [list]            List current queue"
    echo "  queue clear             Clear all notifications"
    echo "  dismiss <id>            Dismiss specific notification"
    echo ""
    echo -e "${CYAN}Configuration:${RESET}"
    echo "  config show             Show current config"
    echo "  config set <key> <val>  Set config value"
    echo "  config focus             Show current focus state"
    echo "  config focus <name>      Activate focus profile (work/sleep/personal)"
    echo "  config focus off         Deactivate focus mode"
    echo "  config focus list        List all focus profiles"
    echo "  config focus schedule on|off  Toggle auto-scheduling"
    echo ""
    echo -e "${CYAN}Plugins:${RESET}"
    echo "  plugin list             List installed plugins"
    echo "  plugin start <id>       Start a plugin"
    echo "  plugin stop <id>        Stop a plugin"
    echo "  plugin active           Show active plugin"
    echo "  plugin install <path>   Install from directory"
    echo "  plugin reload           Reload plugin registry"
    echo ""
    echo -e "${CYAN}Discovery:${RESET}"
    echo "  capabilities            Show HUD capabilities"
    echo "  status                  Show current display state"
    echo ""
    echo -e "${DIM}Talks to $HUD_URL, falls back to $STATUS_FILE${RESET}"
}

# ── Main ────────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    notify)       cmd_notify "$@" ;;
    alert)        cmd_alert "$@" ;;
    info)         cmd_info "$@" ;;
    lcd)          cmd_lcd "$@" ;;
    rsvp)         cmd_rsvp "$@" ;;
    scanner)      cmd_scanner "$@" ;;
    histogram)    cmd_histogram "$@" ;;
    progress)     cmd_progress "$@" ;;
    sparkline)    cmd_sparkline "$@" ;;
    heartbeat)    cmd_heartbeat "$@" ;;
    vu)           cmd_vu "$@" ;;
    queue)        cmd_queue "$@" ;;
    dismiss)      cmd_dismiss "$@" ;;
    config)       cmd_config "$@" ;;
    plugin)       cmd_plugin "$@" ;;
    capabilities) cmd_capabilities "$@" ;;
    status)       cmd_status "$@" ;;
    help|--help|-h) usage ;;
    *)
        echo -e "${RED}Error:${RESET} Unknown command: $COMMAND"
        echo "Run 'jane-hud help' for usage"
        exit 1
        ;;
esac
