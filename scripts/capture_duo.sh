#!/usr/bin/env bash
# Captures App Store scenes on an already-running, unfolded iPhone Duo simulator (inner display).
# Usage: capture_duo.sh <app-path> <out-dir> [udid]
set -euo pipefail
APP="$1"; OUT="$2"; BUNDLE=com.seagomezar.loopline
UDID="${3:-$(xcrun simctl list devices | grep 'iPhone Duo' | grep Booted | grep -o '[0-9A-F-]\{36\}' | head -1)}"
[ -n "$UDID" ] || { echo "No booted iPhone Duo"; exit 1; }
mkdir -p "$OUT"
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
data_dir="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
mkdir -p "$data_dir/Documents/Fixtures"
cp "$(dirname "$0")"/fixtures/part-*.png "$data_dir/Documents/Fixtures/"
for lang in ${LANGS:-en es}; do
  case "$lang" in es) locale=es_MX ;; *) locale=en_US ;; esac
  first=1
  for scene in ${SCENES:-7 1 2 3 4}; do
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -AppleLanguages "($lang)" -AppleLocale "$locale" \
      -LooplineHarnessMode -LooplineProjectRoot "Screenshots-duo-$lang" \
      -LooplineSeedTrackCount 4 -LooplineScreenshotScene "$scene" >/dev/null
    if [ "$first" = 1 ]; then sleep 75; first=0; else sleep 15; fi
    perl -e 'alarm 60; exec @ARGV' xcrun simctl io "$UDID" screenshot --display=primary-1 "$OUT/duoinner_${lang}_scene_${scene}.png" >/dev/null 2>&1 || true
    echo "captured duo $lang scene $scene"
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear || true
