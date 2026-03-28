#!/usr/bin/env bash
# Demo all banner themes — run this to see each one in the notch
# Usage: bash recipes/demo.sh [delay_seconds]

DELAY="${1:-8}"
N="/Users/admin/Work/brain/.tools/jane-notify.sh"

echo "🎬 Banner Theme Demo — ${DELAY}s per theme"
echo ""

echo "1/5 ▸ SCROLL (classic ticker)"
bash "$N" yellow "Scroll demo" -b "⚠️ TRAFFIC SPIKE ★ scalable-media 3x ★ GatherFeed queue: 847 ★ investigating" --style scroll
sleep "$DELAY"

echo "2/5 ▸ TYPEWRITER (character by character)"
bash "$N" yellow "Typewriter demo" -b "DEPLOYING ★ api-server v2.4.1 ★ production ★ 12 files changed" --style typewriter
sleep "$DELAY"

echo "3/5 ▸ FLASH (urgent blink)"
bash "$N" red "Flash demo" -b "🔴 CRITICAL ⚡ auth-service DOWN ⚡ 3 endpoints failing ⚡ rollback?" --style flash
sleep "$DELAY"

echo "4/5 ▸ SLIDE (spring in, pause, slide out)"
bash "$N" yellow "Slide demo" -b "🚀 DEPLOYED ★ v2.4.1 ★ production ★ all tests passing" --style slide
sleep "$DELAY"

echo "5/5 ▸ SPLIT-FLAP (airport departure board)"
bash "$N" yellow "Split-flap demo" -b "GATE B12 ★ BOARDING ★ SFO TO NRT ★ ON TIME" --style split-flap
sleep "$DELAY"

echo ""
echo "✓ Demo complete — returning to green"
bash "$N" green "Demo complete"
