#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ -n "${LOOPLINE_TEST_DESTINATION:-}" ]]; then
    DESTINATION="$LOOPLINE_TEST_DESTINATION"
else
    SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
runtimes = json.load(sys.stdin)["devices"]
def version(name):
    return tuple(map(int, re.findall(r"[0-9]+", name)))
for runtime in sorted(runtimes, key=version, reverse=True):
    for device in runtimes[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
raise SystemExit("Install an iPhone simulator before running the UI harness.")
')"
    DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
fi
HARNESS_ROOT="${TMPDIR:-/tmp}/loopline-ui-harness"
mkdir -p "$HARNESS_ROOT"

xcodebuild \
    -project Loopline.xcodeproj \
    -scheme Loopline \
    -configuration Debug \
    -destination "$DESTINATION" \
    -derivedDataPath "$HARNESS_ROOT/DerivedData" \
    -disableAutomaticPackageResolution \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    test
