#!/usr/bin/env python3
"""Register Swift files in the committed Vervain.xcodeproj without Xcode.

Usage: scripts/add_to_xcodeproj.py Vervain/Services/Foo.swift VervainTests/FooTests.swift

Creates missing intermediate groups, a file reference, a build file and the
Sources-phase entry. Idempotent. Top-level dir picks the target:
Vervain -> app, VervainTests -> unit tests.
"""
import hashlib, re, sys, pathlib

PBX = pathlib.Path(__file__).resolve().parent.parent / "Vervain.xcodeproj" / "project.pbxproj"
ROOT_GROUPS = {"Vervain": "E383F69184F4552E5A41D010", "VervainTests": "261FB8D961FEC76F15EA523A"}
PHASE_MARKER = {"Vervain": "SystemJunkViewModel.swift in Sources", "VervainTests": "CleanupCategoryTests.swift in Sources"}


def ident(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def group_re(gid):
    return re.compile(r"(\t\t%s /\* [^*]* \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)(.*?)(\t\t\t\);\n)" % gid, re.S)


def find_child_group(s, parent_id, name):
    m = group_re(parent_id).search(s)
    for line in m.group(2).splitlines():
        cm = re.match(r"\t+([0-9A-F]{24}) /\* (.*) \*/,", line)
        if cm and cm.group(2) == name:
            body = re.search(r"^\t\t%s /\*[^*]*\*/ = \{\n\t\t\tisa = PBXGroup;.*?\n\t\t\};" % cm.group(1), s, re.S | re.M)
            if body and "path = %s;" % name in body.group(0):
                return cm.group(1)
    return None


def add_child(s, parent_id, entry_line):
    m = group_re(parent_id).search(s)
    return s[:m.end(2)] + entry_line + s[m.end(2):]


def add(s, rel):
    parts = rel.split("/")
    top, name = parts[0], parts[-1]
    if top not in ROOT_GROUPS:
        raise SystemExit("unsupported path: " + rel)
    if name in s and re.search(r"path = %s;" % re.escape(name), s) and ("/* %s */" % name) in s:
        # same file name already registered somewhere; skip duplicates by name
        if any(("/* %s */" % name) in l and "PBXFileReference" in l for l in s.splitlines()):
            return s
    parent = ROOT_GROUPS[top]
    for d in parts[1:-1]:
        gid = find_child_group(s, parent, d)
        if gid is None:
            gid = ident("group:" + "/".join(parts[:parts.index(d) + 1]))
            s = add_child(s, parent, "\t\t\t\t%s /* %s */,\n" % (gid, d))
            block = "\t\t%s /* %s */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t);\n\t\t\tpath = %s;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n" % (gid, d, d)
            s = s.replace("/* End PBXGroup section */", block + "/* End PBXGroup section */")
        parent = gid
    fid, bid = ident("file:" + rel), ident("build:" + rel)
    s = s.replace("/* End PBXBuildFile section */", "\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n/* End PBXBuildFile section */" % (bid, name, fid, name))
    s = s.replace("/* End PBXFileReference section */", "\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = %s; sourceTree = \"<group>\"; };\n/* End PBXFileReference section */" % (fid, name, name))
    s = add_child(s, parent, "\t\t\t\t%s /* %s */,\n" % (fid, name))
    marker = PHASE_MARKER[top]
    mm = re.search(r"\t\t\t\t[0-9A-F]{24} /\* %s \*/,\n" % re.escape(marker), s)
    return s[:mm.start()] + "\t\t\t\t%s /* %s in Sources */,\n" % (bid, name) + s[mm.start():]


def main():
    s = PBX.read_text()
    for rel in sys.argv[1:]:
        s = add(s, rel)
    PBX.write_text(s)


if __name__ == "__main__":
    main()
