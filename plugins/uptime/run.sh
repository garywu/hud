#!/usr/bin/env bash
# Show system uptime, load average, and memory on LCD

# Parse uptime — macOS format: "up X days, H:MM"
RAW_UPTIME=$(uptime | sed 's/.*up //' | sed 's/,.*//')

# Load average (1-min)
LOAD=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')

# Memory: total and used (macOS)
TOTAL_MEM_PAGES=$(sysctl -n hw.memsize 2>/dev/null)
TOTAL_MEM_GB=$(echo "scale=0; ${TOTAL_MEM_PAGES} / 1073741824" | bc)

# Get memory pressure from vm_stat
PAGES_FREE=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
PAGES_INACTIVE=$(vm_stat 2>/dev/null | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')
PAGES_ACTIVE=$(vm_stat 2>/dev/null | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
PAGES_WIRED=$(vm_stat 2>/dev/null | awk '/Pages wired/ {gsub(/\./,"",$4); print $4}')
PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null)

USED_BYTES=$(echo "(${PAGES_ACTIVE:-0} + ${PAGES_WIRED:-0}) * ${PAGE_SIZE:-4096}" | bc)
USED_GB=$(echo "scale=1; ${USED_BYTES} / 1073741824" | bc)

TITLE="UP ${RAW_UPTIME} | LOAD ${LOAD} | RAM ${USED_GB}/${TOTAL_MEM_GB}G"

curl -s -X POST http://localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"uptime\",
    \"level\": \"passive\",
    \"title\": \"${TITLE}\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"cyan\"
  }"
