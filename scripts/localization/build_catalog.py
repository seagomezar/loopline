#!/usr/bin/env python3
"""Builds the String Catalogs from scripts/localization/es.json (English key -> Spanish).

Run after adding UI text:
  1. Build the app (Xcode emits *.stringsdata with every localized key).
  2. python3 scripts/localization/build_catalog.py --check   # lists keys missing a translation
  3. Add the missing keys to es.json, then run without --check.
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ES = json.load(open(os.path.join(ROOT, "scripts/localization/es.json"), encoding="utf-8"))

INFO_PLIST_EN = {
    "CFBundleDisplayName": "Overdubly",
    "CFBundleName": "Overdubly",
    "NSCameraUsageDescription": "Overdubly uses the camera to record each part of your video.",
    "NSMicrophoneUsageDescription": "Overdubly uses the microphone to record your voice or instrument.",
    "NSPhotoLibraryAddUsageDescription": "Overdubly saves finished performances to your Photos library when you choose.",
}

INFO_PLIST_ES = {
    "CFBundleDisplayName": "Overdubly",
    "CFBundleName": "Overdubly",
    "NSCameraUsageDescription": "Overdubly usa la cámara para grabar cada parte de tu video.",
    "NSMicrophoneUsageDescription": "Overdubly usa el micrófono para grabar tu voz o tu instrumento.",
    "NSPhotoLibraryAddUsageDescription": "Overdubly guarda tus videos terminados en Fotos cuando tú lo eliges.",
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def catalog(strings, english=None):
    # Explicit English entries make Xcode emit en.lproj. Without it the bundle only has es.lproj
    # and iOS would show Spanish to everyone.
    english = english or {}
    return {
        "sourceLanguage": "en",
        "strings": {key: {"localizations": {"en": unit(english.get(key, key)), "es": unit(value)}}
                    for key, value in sorted(strings.items())},
        "version": "1.0",
    }


def write(path, data):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")


def extracted_keys():
    keys = set()
    pattern = os.path.join(ROOT, "build/sim/Build/Intermediates.noindex/Loopline.build/*/Loopline.build/Objects-normal/*/*.stringsdata")
    for path in glob.glob(pattern):
        for entries in json.load(open(path)).get("tables", {}).values():
            keys.update(entry["key"] for entry in entries)
    return keys


if "--check" in sys.argv:
    missing = sorted(k for k in extracted_keys() if k not in ES)
    print("\n".join(missing) if missing else "All extracted keys are translated.")
    sys.exit(1 if missing else 0)

write(os.path.join(ROOT, "LooplineApp/Resources/Localizable.xcstrings"), catalog(ES))
write(os.path.join(ROOT, "LooplineApp/Resources/InfoPlist.xcstrings"), catalog(INFO_PLIST_ES, INFO_PLIST_EN))
print(f"Wrote {len(ES)} strings and {len(INFO_PLIST_ES)} Info.plist strings.")
