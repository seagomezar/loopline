#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HARNESS_CACHE="${TMPDIR:-/tmp}/loopline-swift-cache"
mkdir -p "$HARNESS_CACHE"
export CLANG_MODULE_CACHE_PATH="$HARNESS_CACHE/clang"
export SWIFT_MODULECACHE_PATH="$HARNESS_CACHE/swift"
export SWIFT_DRIVER_CACHE_PATH="$HARNESS_CACHE/driver"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH" "$SWIFT_DRIVER_CACHE_PATH"

echo "Loopline offline core harness"
echo "Swift: $(swift --version | head -n 1)"

# Keep compiler module caches inside the permitted temporary area. This also
# makes the harness reproducible on locked-down CI machines without changing
# SwiftPM's package or source inputs.
CORE_CLANG_CACHE_DIR="${TMPDIR:-/tmp}/loopline-core-clang-module-cache"
mkdir -p "$CORE_CLANG_CACHE_DIR"
CLANG_MODULE_CACHE_PATH="$CORE_CLANG_CACHE_DIR" \
    swift test --package-path "$ROOT_DIR" --disable-sandbox
