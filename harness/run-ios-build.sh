#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HARNESS_ROOT="${TMPDIR:-/tmp}/loopline-ios-harness"
DERIVED_DATA="$HARNESS_ROOT/DerivedData"
CLANG_CACHE="$HARNESS_ROOT/clang-module-cache"
SWIFT_CACHE="$HARNESS_ROOT/swift-module-cache"
mkdir -p "$DERIVED_DATA" "$CLANG_CACHE" "$SWIFT_CACHE"

echo "Loopline iPhone build harness"
echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Destination: generic iOS device (no simulator or network dependency)"

xcodebuild \
    -project "$ROOT_DIR/Loopline.xcodeproj" \
    -scheme Loopline \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
    SWIFT_MODULECACHE_PATH="$SWIFT_CACHE" \
    -quiet \
    build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug-iphoneos/Loopline.app"
test -d "$APP_BUNDLE"
test -f "$APP_BUNDLE/Info.plist"
echo "Verified app bundle: $APP_BUNDLE"
