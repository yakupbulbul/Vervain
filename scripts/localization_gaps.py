#!/usr/bin/env python3
"""Find strings the app uses that Localizable.xcstrings does not translate yet.

Usage: scripts/localization_gaps.py <derived-data-dir> [catalog]

Reads the .stringsdata files Xcode writes during a build with
SWIFT_EMIT_LOC_STRINGS=YES (the authoritative list of every localizable string
in the code, with exact format specifiers) and compares them with the catalog.
Prints one JSON object per line between GAPS-BEGIN and GAPS-END.
"""
import json, pathlib, sys

LANGS = ["de", "es", "fr", "tr", "zh-Hans"]


def main() -> int:
    root = pathlib.Path(sys.argv[1])
    catalog_path = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "Vervain/Localizable.xcstrings")
    catalog = json.loads(catalog_path.read_text())["strings"]

    used = {}
    for path in root.rglob("*.stringsdata"):
        try:
            data = json.loads(path.read_text())
        except ValueError:
            continue
        for entry in data.get("tables", {}).get("Localizable", []):
            used.setdefault(entry["key"], pathlib.Path(data.get("source", "")).name)

    gaps = []
    for key, source in sorted(used.items()):
        loc = catalog.get(key, {}).get("localizations", {})
        missing = [l for l in LANGS if not loc.get(l, {}).get("stringUnit", {}).get("value")]
        if missing:
            gaps.append({"key": key, "file": source, "missing": missing})

    print("GAPS-BEGIN")
    for gap in gaps:
        print(json.dumps(gap, ensure_ascii=False))
    print("GAPS-END")
    print(f"{len(used)} strings used in code, {len(gaps)} lack translations")
    return 1 if gaps else 0


if __name__ == "__main__":
    sys.exit(main())
