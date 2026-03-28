#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  ATLAS HUD — STORE DEMO                                 ║
# ║  Jane: Your AI in the notch                              ║
# ║                                                          ║
# ║  Cycles through all HUD capabilities:                    ║
# ║  • Severity levels (green → yellow → red)                ║
# ║  • Banner animation themes                               ║
# ║  • Panel data slots                                      ║
# ║  • Theme switching                                       ║
# ║  • Priority queue                                        ║
# ║                                                          ║
# ║  Usage: bash demo-full.sh [speed]                        ║
# ║  speed: fast (4s) | normal (7s) | slow (12s)             ║
# ╚══════════════════════════════════════════════════════════╝

set -euo pipefail

SPEED="${1:-normal}"
case "$SPEED" in
  fast)   D=4 ;;
  slow)   D=12 ;;
  *)      D=7 ;;
esac

N="/Users/admin/Work/brain/.tools/jane-notify.sh"
THEME_DIR="/Users/admin/Work/atlas/apps/hud/themes"
Q="$HOME/.atlas/status-queue.json"

echo ""
echo "  ╔═══════════════════════════════════╗"
echo "  ║   ATLAS HUD — STORE DEMO          ║"
echo "  ║   Jane: Your AI in the notch      ║"
echo "  ║   ${D}s per scene                    ║"
echo "  ╚═══════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────
# ACT 1: Meet Jane
# ─────────────────────────────────────────
echo "━━━ ACT 1: Meet Jane ━━━"
echo ""

echo "  Scene 1/16: Jane wakes up"
bash "$N" green "Jane online. All systems nominal."
sleep "$D"

echo "  Scene 2/16: Jane is watching"
bash "$N" yellow "Monitoring 6 repositories" -b "👁️ WATCHING ★ atlas ★ api-mom ★ scram-jet ★ open-dash ★ social-good ★ scalable-media" --style typewriter
sleep "$D"

# ─────────────────────────────────────────
# ACT 2: Banner Themes
# ─────────────────────────────────────────
echo ""
echo "━━━ ACT 2: Banner Animation Themes ━━━"
echo ""

echo "  Scene 3/16: Scroll (classic ticker)"
bash "$N" yellow "Banner: Scroll" -b "📡 SCROLL ★ classic LED ticker ★ continuous left-to-right ★ perfect for long messages ★ ambient updates" --style scroll
sleep "$D"

echo "  Scene 4/16: Typewriter (character by character)"
bash "$N" yellow "Banner: Typewriter" -b "⌨️ TYPEWRITER ★ one character at a time ★ dramatic reveal ★ cursor blink" --style typewriter
sleep "$D"

echo "  Scene 5/16: Flash (urgent blink)"
bash "$N" red "Banner: Flash" -b "🔴 FLASH ★ THREE BLINKS ★ THEN HOLD ★ MAXIMUM URGENCY" --style flash
sleep "$D"

echo "  Scene 6/16: Slide (spring bounce)"
bash "$N" yellow "Banner: Slide" -b "🚀 SLIDE ★ spring in ★ pause ★ slide out ★ deploy notifications" --style slide
sleep "$D"

echo "  Scene 7/16: Split-Flap (airport board)"
bash "$N" yellow "Banner: Split-Flap" -b "GATE B12 ★ BOARDING ★ SFO TO NRT ★ ON TIME" --style split-flap
sleep "$D"

# ─────────────────────────────────────────
# ACT 3: Severity Levels
# ─────────────────────────────────────────
echo ""
echo "━━━ ACT 3: Severity-Driven Layout ━━━"
echo ""

echo "  Scene 8/16: Green (collapsed — just dots)"
bash "$N" green "All systems nominal"
sleep "$D"

echo "  Scene 9/16: Yellow (medium expansion)"
bash "$N" yellow "Athena flagged anomaly" -b "⚠️ API LATENCY ★ p99: 1.2s ★ threshold: 500ms ★ investigating" --style scroll
sleep "$D"

echo "  Scene 10/16: Red (full expansion)"
bash "$N" red "SYSTEM ALERT" -b "🔴 CRITICAL ⚡ auth-service DOWN ⚡ 3 endpoints failing ⚡ last deploy: Mulan PR #42 ⚡ rollback recommended" --style flash
sleep "$D"

echo "  Scene 11/16: Recovery → Green"
bash "$N" yellow "Recovering..." -b "🔄 ROLLING BACK ★ PR #42 reverted ★ redeploying v2.3.9" --style typewriter
sleep "$D"
bash "$N" green "All clear. Rollback successful."
sleep 3

# ─────────────────────────────────────────
# ACT 4: Data Panels
# ─────────────────────────────────────────
echo ""
echo "━━━ ACT 4: Data Panel Slots ━━━"
echo ""

echo "  Scene 12/16: Metrics dashboard"
bash "$N" yellow "System metrics" \
  -b "📊 DASHBOARD ★ real-time metrics" --style scroll \
  --slot "qps:metric:QPS:1.2k:up" \
  --slot "p99:metric:P99:142ms:down" \
  --slot "cpu:metric:CPU:34%:flat"
sleep "$D"

echo "  Scene 13/16: Agent status"
bash "$N" yellow "Agent status" \
  -b "🏛️ C-SUITE STATUS ★ all agents reporting" --style typewriter \
  --slot "athena:agent_status:Athena:active" \
  --slot "hermes:agent_status:Hermes:active" \
  --slot "heph:agent_status:Hephaestus:idle"
sleep "$D"

# ─────────────────────────────────────────
# ACT 5: Theme Switching
# ─────────────────────────────────────────
echo ""
echo "━━━ ACT 5: Live Theme Switching ━━━"
echo ""

echo "  Scene 14/16: Theme → LCARS (Star Trek)"
cp "$THEME_DIR/lcars.json" ~/.atlas/hud-theme.json
bash "$N" yellow "LCARS ACTIVE" -b "YELLOW ALERT ★ ANOMALOUS READINGS ★ SECTOR 7 ★ ALL STATIONS REPORT" --style typewriter
sleep "$D"

echo "  Scene 15/16: Theme → Cyberpunk"
cp "$THEME_DIR/cyberpunk.json" ~/.atlas/hud-theme.json
bash "$N" red "BREACH DETECTED" -b "🔴 PERIMETER BREACH ★ NODE 7F3A ★ TRACING ORIGIN ★ COUNTERMEASURES ACTIVE" --style flash
sleep "$D"

echo "  Scene 16/16: Theme → Minimal (default)"
cp "$THEME_DIR/minimal.json" ~/.atlas/hud-theme.json
bash "$N" green "Demo complete"
sleep 3

# ─────────────────────────────────────────
# CURTAIN CALL
# ─────────────────────────────────────────
echo ""
echo "  ╔═══════════════════════════════════╗"
echo "  ║   ✅ DEMO COMPLETE                ║"
echo "  ║                                   ║"
echo "  ║   Jane is your AI in the notch.   ║"
echo "  ║   Always watching. Always there.  ║"
echo "  ║                                   ║"
echo "  ║   atlas/apps/hud/                 ║"
echo "  ╚═══════════════════════════════════╝"
echo ""
