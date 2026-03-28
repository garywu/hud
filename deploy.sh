#!/usr/bin/env bash
# Atlas HUD — Build & Hot-Swap Deploy
# Builds the new version, then swaps the running app.
# The app restarts itself via launchd (if installed) or manually.
#
# Usage: bash deploy.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODEPROJ="$PROJECT_DIR/AtlasHUD.xcodeproj"
BUILD_DIR="/Users/admin/Library/Developer/Xcode/DerivedData/AtlasHUD-blllhwhlwfacvafdrfxsfockswyx/Build/Products/Debug"
APP_NAME="Notchy.app"
INSTALL_DIR="$HOME/.atlas/hud"

echo "╔═══════════════════════════════════╗"
echo "║  Atlas HUD — Build & Deploy       ║"
echo "╚═══════════════════════════════════╝"

# 1. Build (without touching the running app)
echo ""
echo "▸ Building..."
cd "$PROJECT_DIR"
BUILD_OUTPUT=$(xcodebuild -project "$XCODEPROJ" -scheme Notchy -configuration Debug build 2>&1)
if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
  echo "  ✓ Build succeeded"
else
  echo "  ✗ Build failed:"
  echo "$BUILD_OUTPUT" | grep "error:" | head -5
  exit 1
fi

# 2. Install to ~/.atlas/hud/
echo ""
echo "▸ Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copy new build (while old is still running)
cp -R "$BUILD_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME.new"
echo "  ✓ New version staged"

# 3. Swap — kill old, move new into place, launch
echo ""
echo "▸ Swapping..."
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Remove old, move new
rm -rf "$INSTALL_DIR/$APP_NAME"
mv "$INSTALL_DIR/$APP_NAME.new" "$INSTALL_DIR/$APP_NAME"
echo "  ✓ Swapped"

# 4. Re-sign (cp can strip ad-hoc signature)
echo ""
echo "▸ Signing..."
codesign --force --sign - "$INSTALL_DIR/$APP_NAME" 2>/dev/null && echo "  ✓ Signed" || echo "  ⚠ Sign skipped"

# 5. Launch
echo ""
echo "▸ Launching..."
open "$INSTALL_DIR/$APP_NAME"
echo "  ✓ Running from $INSTALL_DIR/$APP_NAME"

echo ""
echo "✅ Deploy complete. HUD is live."
