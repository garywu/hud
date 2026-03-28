#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  Status Bar Display Demo                                 ║
# ║  Cycles through ALL display modes and sizes              ║
# ║                                                          ║
# ║  Usage: bash demo-statusbar.sh [speed]                   ║
# ║  speed: fast (3s) | normal (5s) | slow (8s)              ║
# ╚══════════════════════════════════════════════════════════╝

set -euo pipefail

SPEED="${1:-normal}"
case "$SPEED" in
  fast)   D=3 ;;
  slow)   D=8 ;;
  *)      D=5 ;;
esac

STATUS_FILE="$HOME/.atlas/status.json"

write_status() {
  local mode="$1"
  local size="$2"
  local text="${3:-}"
  local data="${4:-null}"
  local msg="${5:-Demo: $mode $size}"

  cat > "$STATUS_FILE" << EOF
{
  "status": "green",
  "source": "jane",
  "message": "$msg",
  "banner": "$text",
  "bannerStyle": null,
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": [],
  "slots": null,
  "statusBar": { "mode": "$mode", "size": "$size", "text": "$text", "data": $data }
}
EOF
}

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║  Status Bar Display Demo               ║"
echo "  ║  ${D}s per mode                          ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""
echo "  ━━━ SCANNER MODES (4pt) ━━━"
echo ""

echo "  1/18 ▸ Scanner: KITT sweep"
write_status "scanner" "small" "" "null" "KITT Scanner"
sleep "$D"

echo "  2/18 ▸ Scanner: Histogram"
write_status "histogram" "small" "" "[0.3,0.7,0.5,0.9,0.2,0.8,0.4,0.6,0.1,0.95,0.5,0.3,0.7,0.4,0.8,0.6,0.2,0.9,0.5,0.7]" "Histogram"
sleep "$D"

echo "  3/18 ▸ Scanner: Progress 25%"
write_status "progress" "small" "" "[0.25]" "Progress 25%"
sleep "$D"

echo "  4/18 ▸ Scanner: Progress 65%"
write_status "progress" "small" "" "[0.65]" "Progress 65%"
sleep "$D"

echo "  5/18 ▸ Scanner: Progress 90%"
write_status "progress" "small" "" "[0.90]" "Progress 90%"
sleep "$D"

echo "  6/18 ▸ Scanner: Heartbeat"
write_status "heartbeat" "small" "" "null" "Heartbeat"
sleep "$D"

echo "  7/18 ▸ Scanner: VU Meter"
write_status "vu" "small" "" "null" "VU Meter"
sleep "$D"

echo "  8/18 ▸ Scanner: Sparkline"
write_status "sparkline" "small" "" "[0.2,0.3,0.5,0.4,0.7,0.6,0.8,0.5,0.9,0.7,0.4,0.6,0.8,0.3,0.5,0.7,0.9,0.6,0.4,0.8]" "Sparkline"
sleep "$D"

echo ""
echo "  ━━━ LCD MODES (dot-matrix) ━━━"
echo ""

echo "  9/18 ▸ LCD: Small (13pt)"
write_status "lcd" "small" "JANE ONLINE" "null" "LCD Small"
sleep "$D"

echo "  10/18 ▸ LCD: Medium (21pt)"
write_status "lcd" "medium" "ATLAS HUD SYSTEM" "null" "LCD Medium"
sleep "$D"

echo "  11/18 ▸ LCD: Large (28pt)"
write_status "lcd" "large" "HELLO WORLD" "null" "LCD Large"
sleep "$D"

echo ""
echo "  ━━━ TEXT MODES (plain monospace) ━━━"
echo ""

echo "  12/18 ▸ Text: Small (10pt)"
write_status "text" "small" "System nominal — all agents reporting" "null" "Text Small"
sleep "$D"

echo "  13/18 ▸ Text: Medium (14pt)"
write_status "text" "medium" "Athena: daily brief ready for review" "null" "Text Medium"
sleep "$D"

echo "  14/18 ▸ Text: Large (18pt)"
write_status "text" "large" "DEPLOY COMPLETE" "null" "Text Large"
sleep "$D"

echo ""
echo "  ━━━ SEVERITY × DISPLAY ━━━"
echo ""

echo "  15/18 ▸ Yellow + Histogram"
cat > "$STATUS_FILE" << EOF
{
  "status": "yellow",
  "source": "athena",
  "message": "Traffic anomaly",
  "banner": "TRAFFIC SPIKE DETECTED",
  "bannerStyle": null,
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": [],
  "slots": null,
  "statusBar": { "mode": "histogram", "size": "small", "data": [0.5,0.6,0.8,0.9,0.95,0.7,0.6,0.5,0.4,0.3,0.5,0.7,0.9,0.8,0.6,0.4,0.3,0.5,0.7,0.8] }
}
EOF
sleep "$D"

echo "  16/18 ▸ Red + LCD"
cat > "$STATUS_FILE" << EOF
{
  "status": "red",
  "source": "jane",
  "message": "System alert",
  "banner": "CRITICAL ALERT",
  "bannerStyle": null,
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": [],
  "slots": null,
  "statusBar": { "mode": "lcd", "size": "medium", "text": "ALERT CPU 98 PCT" }
}
EOF
sleep "$D"

echo "  17/18 ▸ SOS + Heartbeat"
cat > "$STATUS_FILE" << EOF
{
  "status": "sos",
  "source": "jane",
  "message": "DEAD STOP",
  "banner": "SOS",
  "bannerStyle": null,
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": [],
  "slots": null,
  "statusBar": { "mode": "heartbeat", "size": "small" }
}
EOF
sleep "$D"

echo "  18/18 ▸ Green + KITT (home state)"
echo '{"messages":[]}' > "$HOME/.atlas/status-queue.json"
cat > "$STATUS_FILE" << EOF
{
  "status": "green",
  "source": "jane",
  "message": "All systems nominal",
  "banner": null,
  "bannerStyle": null,
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": [],
  "slots": null,
  "statusBar": { "mode": "scanner", "size": "small" }
}
EOF
sleep "$D"

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║  ✅ Demo complete — 18 permutations    ║"
echo "  ║                                       ║"
echo "  ║  3 engines × sizes + severity combos  ║"
echo "  ║  Scanner: KITT, histogram, progress,  ║"
echo "  ║    heartbeat, VU, sparkline           ║"
echo "  ║  LCD: small, medium, large            ║"
echo "  ║  Text: small, medium, large           ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""
