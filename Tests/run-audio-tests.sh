#!/bin/bash

# Audio I/O Test Runner
# Compiles and runs the AudioIOManager tests and CLI test

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$SCRIPT_DIR/AudioIOTests"
HUD_DIR="$PROJECT_DIR/HUD"

echo "=== HUD Audio I/O Tests ==="
echo ""
echo "Test directories:"
echo "  Project:  $PROJECT_DIR"
echo "  Tests:    $TESTS_DIR"
echo "  HUD:      $HUD_DIR"
echo ""

# Check if test files exist
if [ ! -f "$TESTS_DIR/AudioIOManagerTests.swift" ]; then
    echo "ERROR: AudioIOManagerTests.swift not found at $TESTS_DIR"
    exit 1
fi

if [ ! -f "$TESTS_DIR/AudioIOCLITest.swift" ]; then
    echo "ERROR: AudioIOCLITest.swift not found at $TESTS_DIR"
    exit 1
fi

if [ ! -f "$HUD_DIR/AudioIOManager.swift" ]; then
    echo "ERROR: AudioIOManager.swift not found at $HUD_DIR"
    exit 1
fi

# Compile AudioIOManager
echo "Step 1: Compiling AudioIOManager.swift..."
swiftc -parse "$HUD_DIR/AudioIOManager.swift" && echo "  ✓ Syntax check passed" || {
    echo "  ✗ Syntax check failed"
    exit 1
}

echo ""
echo "Step 2: Compiling tests..."
swiftc -parse "$TESTS_DIR/AudioIOManagerTests.swift" && echo "  ✓ Unit tests syntax check passed" || {
    echo "  ✗ Unit tests syntax check failed"
    exit 1
}

swiftc -parse "$TESTS_DIR/AudioIOCLITest.swift" && echo "  ✓ CLI test syntax check passed" || {
    echo "  ✗ CLI test syntax check failed"
    exit 1
}

echo ""
echo "=== All syntax checks passed ==="
echo ""
echo "Note: Full unit tests require XCTest framework (run in Xcode)"
echo "      CLI test requires Xcode build system to link properly"
echo ""
echo "To run CLI test manually:"
echo "  cd $TESTS_DIR"
echo "  swift AudioIOCLITest.swift"
