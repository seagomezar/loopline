#!/usr/bin/env bash
# Captures raw App Store scenes (English and Spanish) from the iPhone 17 Pro Max, iPad Pro 13" (M5),
# and iPhone Duo (inner + outer displays) simulators.
# Usage: capture_scenes.sh <app-path> <out-dir>
set -euo pipefail
APP="$1"; OUT="$2"; BUNDLE=com.seagomezar.loopline
mkdir -p "$OUT"
# kind:Device Type Name — simulators are created on demand (latest installed iOS runtime).
declare -a DEVICES=("iphone:iPhone 17 Pro Max" "ipad:iPad Pro 13-inch (M5)" "duo:iPhone Duo")
if [ -n "${ONLY:-}" ]; then
  filtered=(); for e in "${DEVICES[@]}"; do [ "${e%%:*}" = "$ONLY" ] && filtered+=("$e"); done; DEVICES=("${filtered[@]}")
fi
wait_booted() {
  local id="$1"
  for _ in $(seq 1 90); do
    if xcrun simctl list devices | grep -q "$id) (Booted)"; then sleep 8; return 0; fi
    sleep 2
  done
  echo "simulator $id did not boot" >&2; return 1
}
udid_for() {
  local name="$1" id
  id="$(xcrun simctl list devices available -j | python3 -c "import sys,json;n=sys.argv[1];print(next((d['udid'] for r in json.load(sys.stdin)['devices'].values() for d in r if d['name']==n),''))" "$name")"
  if [ -z "$id" ]; then
    if [ "$name" = "iPhone Duo" ]; then
      # The Duo ships with its own runtime variant (iPhone19,4).
      runtime="$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*-iPhone19-4' | tail -1)"
      id="$(xcrun simctl create "$name" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo "$runtime")"
    else
      id="$(xcrun simctl create "$name" "$name")"
    fi
  fi
  echo "$id"
}
for entry in "${DEVICES[@]}"; do
  kind="${entry%%:*}"; udid="$(udid_for "${entry#*:}")"
  # English system locale so the status bar date matches across localizations.
  xcrun simctl boot "$udid" 2>/dev/null || true
  wait_booted "$udid"
  if [ "$(xcrun simctl spawn "$udid" defaults read -g AppleLocale 2>/dev/null)" != "en_US" ]; then
    xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en-US
    xcrun simctl spawn "$udid" defaults write -g AppleLocale en_US
    xcrun simctl shutdown "$udid"; sleep 3; xcrun simctl boot "$udid"; wait_booted "$udid"
  fi
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  # Illustrated performers (scripts/fixtures/part-N.png) replace the generated placeholder clips.
  data_dir="$(xcrun simctl get_app_container "$udid" "$BUNDLE" data)"
  mkdir -p "$data_dir/Documents/Fixtures"
  cp "$(dirname "$0")"/fixtures/part-*.png "$data_dir/Documents/Fixtures/" 2>/dev/null || true
  for lang in ${LANGS:-en es}; do
    case "$lang" in es) locale=es_MX ;; *) locale=en_US ;; esac
    first=1
    root="Screenshots-$kind-$lang"
    for scene in ${SCENES:-7 1 2 3 4 6}; do
      xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
      xcrun simctl launch "$udid" "$BUNDLE" -AppleLanguages "($lang)" -AppleLocale "$locale" \
        -LooplineHarnessMode -LooplineProjectRoot "$root" \
        -LooplineSeedTrackCount 4 -LooplineScreenshotScene "$scene" >/dev/null
      # First launch per language generates the seeded media; later launches reuse it.
      if [ "$first" = 1 ]; then sleep 90; first=0; else sleep 16; fi
      if [ "$kind" = duo ]; then
        # The simulator boots folded, so the outer display (1398x2034, screen "primary") shows the app.
        # The inner display ("primary-1", 2007x2853) needs the device unfolded in Device Hub.
        perl -e 'alarm 60; exec @ARGV' xcrun simctl io "$udid" screenshot --display=primary "$OUT/duoouter_${lang}_scene_${scene}.png" >/dev/null 2>&1 || true
      else
        xcrun simctl io "$udid" screenshot "$OUT/${kind}_${lang}_scene_${scene}.png" >/dev/null 2>&1
      fi
      echo "captured $kind $lang scene $scene"
    done
  done
  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
done
