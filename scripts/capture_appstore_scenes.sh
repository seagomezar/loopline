#!/usr/bin/env bash
# Captures raw App Store scenes from the iPhone 17 Pro Max and iPad Pro 13" (M5) simulators.
# Usage: capture_scenes.sh <app-path> <out-dir>
set -euo pipefail
APP="$1"; OUT="$2"; BUNDLE=com.seagomezar.loopline
mkdir -p "$OUT"
# kind:Device Type Name — simulators are created on demand (latest installed iOS runtime).
declare -a DEVICES=("iphone:iPhone 17 Pro Max" "ipad:iPad Pro 13-inch (M5)")
if [ -n "${DUO:-}" ]; then DEVICES=("duo:${DUO}"); fi
if [ -n "${ONLY:-}" ]; then
  filtered=(); for e in "${DEVICES[@]}"; do [ "${e%%:*}" = "$ONLY" ] && filtered+=("$e"); done; DEVICES=("${filtered[@]}")
fi
udid_for() {
  local name="$1" id
  id="$(xcrun simctl list devices available -j | python3 -c "import sys,json;n=sys.argv[1];print(next((d['udid'] for r in json.load(sys.stdin)['devices'].values() for d in r if d['name']==n),''))" "$name")"
  if [ -z "$id" ]; then id="$(xcrun simctl create "$name" "$name")"; fi
  echo "$id"
}
for entry in "${DEVICES[@]}"; do
  kind="${entry%%:*}"; udid="$(udid_for "${entry#*:}")"
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
  # Illustrated performers (scripts/fixtures/part-N.png) replace the generated placeholder clips.
  data_dir="$(xcrun simctl get_app_container "$udid" "$BUNDLE" data)"
  mkdir -p "$data_dir/Documents/Fixtures"
  cp "$(dirname "$0")"/fixtures/part-*.png "$data_dir/Documents/Fixtures/" 2>/dev/null || true
  first=1
  root="Screenshots-$kind"
  for scene in ${SCENES:-7 1 2 3 4 6}; do
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE" -LooplineHarnessMode -LooplineProjectRoot "$root" \
      -LooplineSeedTrackCount 4 -LooplineScreenshotScene "$scene" >/dev/null
    # First launch generates the seeded media; later launches reuse it.
    if [ "$first" = 1 ]; then sleep 50; first=0; else sleep 14; fi
    xcrun simctl io "$udid" screenshot "$OUT/${kind}_scene_${scene}.png" >/dev/null 2>&1
    echo "captured $kind scene $scene"
  done
  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
done
