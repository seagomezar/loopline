#!/usr/bin/env bash
# Captures raw App Store scenes from the iPhone 17 Pro Max and iPad Pro 13" (M5) simulators.
# Usage: capture_scenes.sh <app-path> <out-dir>
set -euo pipefail
APP="$1"; OUT="$2"; BUNDLE=com.seagomezar.loopline
mkdir -p "$OUT"
declare -a DEVICES=("iphone:7A7647AD-7FA7-4277-9F5D-E73E66701DD4" "ipad:25A8D394-D8D2-4581-A8BC-5A51FBBD5E87")
if [ -n "${ONLY:-}" ]; then DEVICES=($(printf "%s\n" "${DEVICES[@]}" | grep "^$ONLY:")); fi
for entry in "${DEVICES[@]}"; do
  kind="${entry%%:*}"; udid="${entry#*:}"
  # English system locale so the status bar date matches across localizations.
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  if [ "$(xcrun simctl spawn "$udid" defaults read -g AppleLocale 2>/dev/null)" != "en_US" ]; then
    xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en-US
    xcrun simctl spawn "$udid" defaults write -g AppleLocale en_US
    xcrun simctl shutdown "$udid"; xcrun simctl boot "$udid"; xcrun simctl bootstatus "$udid" -b >/dev/null
  fi
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  root="Screenshots-$kind"
  for scene in ${SCENES:-1 2 3 4 5}; do
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE" -LooplineHarnessMode -LooplineProjectRoot "$root" \
      -LooplineSeedTrackCount 4 -LooplineScreenshotScene "$scene" >/dev/null
    # First launch generates the seeded media; later launches reuse it.
    if [ "$scene" = "${SCENES:-1 2 3 4 5}" ] || [ "$scene" = 1 ]; then sleep 45; else sleep 14; fi
    xcrun simctl io "$udid" screenshot "$OUT/${kind}_scene_${scene}.png" >/dev/null 2>&1
    echo "captured $kind scene $scene"
  done
  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
done
