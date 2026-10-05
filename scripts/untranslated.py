#!/usr/bin/env python3
"""List strings that still need translating, from Xcode's exported XLIFF files.

Usage: scripts/untranslated.py build/loc

Prints one JSON object per line between the markers UNTRANSLATED-BEGIN and
UNTRANSLATED-END: {"id": ..., "source": ..., "note": ..., "missing": [langs]}.
Exits 1 if anything is missing, so it can gate CI once the catalog is complete.
"""
import json, pathlib, sys
import xml.etree.ElementTree as ET

NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}


def main(folder: str) -> int:
    missing = {}
    for path in sorted(pathlib.Path(folder).glob("*.xcloc/Localized Contents/*.xliff")):
        lang = path.stem
        root = ET.parse(path).getroot()
        for file_el in root.findall("x:file", NS):
            if "Localizable" not in file_el.get("original", ""):
                continue
            for unit in file_el.iter("{%s}trans-unit" % NS["x"]):
                target = unit.find("x:target", NS)
                state = target.get("state") if target is not None else None
                text = (target.text or "").strip() if target is not None else ""
                if target is None or not text or state in ("new", "needs-translation"):
                    source = unit.find("x:source", NS)
                    note = unit.find("x:note", NS)
                    entry = missing.setdefault(unit.get("id"), {
                        "id": unit.get("id"),
                        "source": (source.text or "") if source is not None else "",
                        "note": (note.text or "") if note is not None else "",
                        "missing": [],
                    })
                    entry["missing"].append(lang)
    print("UNTRANSLATED-BEGIN")
    for entry in missing.values():
        print(json.dumps(entry, ensure_ascii=False))
    print("UNTRANSLATED-END")
    print(f"{len(missing)} strings need translation")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/loc"))
