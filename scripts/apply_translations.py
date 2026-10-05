#!/usr/bin/env python3
"""Merge translations into Vervain/Localizable.xcstrings.

Usage: scripts/apply_translations.py translations.json

translations.json: {"<key>": {"tr": "...", "de": "...", "es": "...", "fr": "...", "zh-Hans": "..."}, ...}
Keys missing from the catalog are added (English value = the key). Existing
translations are only overwritten when --force is passed.
"""
import json, pathlib, sys

CATALOG = pathlib.Path(__file__).resolve().parent.parent / "Vervain" / "Localizable.xcstrings"


def main() -> None:
    force = "--force" in sys.argv
    source = pathlib.Path([a for a in sys.argv[1:] if not a.startswith("--")][0])
    translations = json.loads(source.read_text())
    catalog = json.loads(CATALOG.read_text())
    strings = catalog["strings"]
    added = updated = 0
    for key, langs in translations.items():
        entry = strings.setdefault(key, {})
        loc = entry.setdefault("localizations", {})
        if "en" not in loc:
            loc["en"] = {"stringUnit": {"state": "translated", "value": key}}
            added += 1
        for lang, value in langs.items():
            if lang in loc and not force:
                continue
            loc[lang] = {"stringUnit": {"state": "translated", "value": value}}
            updated += 1
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n")
    print(f"added {added} keys, wrote {updated} translations")


if __name__ == "__main__":
    main()
