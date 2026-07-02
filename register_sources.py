#!/usr/bin/env python3
"""Register all Swift sources in the BarnClimate Xcode project and set the
iOS deployment target to 14.0. Idempotent: re-running won't duplicate entries.
Uses deterministic 24-hex IDs derived from filenames so reruns are stable."""

import hashlib
import re
import glob
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
PBX = os.path.join(ROOT, "BarnClimate.xcodeproj", "project.pbxproj")
SRC_DIR = os.path.join(ROOT, "BarnClimate")

# The PBXGroup id for the "BarnClimate" group and the Sources build phase id.
GROUP_ID = "3AA4CF212FCC663A004BFB95"
SOURCES_PHASE_ID = "3AA4CF1B2FCC663A004BFB95"


def gen_id(seed):
    """Deterministic 24-char uppercase hex id, prefixed so it never collides
    with Xcode's existing 3AA4… ids."""
    h = hashlib.md5(seed.encode()).hexdigest().upper()
    return ("BC" + h)[:24]


def main():
    with open(PBX, "r") as f:
        pbx = f.read()

    swift_files = sorted(os.path.basename(p) for p in glob.glob(os.path.join(SRC_DIR, "*.swift")))

    build_file_lines = []
    file_ref_lines = []
    group_children = []
    sources_files = []

    for name in swift_files:
        ref_id = gen_id(name + ".ref")
        build_id = gen_id(name + ".build")

        # Skip if already present (idempotent).
        if ref_id in pbx:
            continue

        build_file_lines.append(
            f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};"
        )
        file_ref_lines.append(
            f"\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{name}\"; sourceTree = \"<group>\"; }};"
        )
        group_children.append(f"\t\t\t\t{ref_id} /* {name} */,")
        sources_files.append(f"\t\t\t\t{build_id} /* {name} in Sources */,")

    # 1) Insert PBXBuildFile entries.
    if build_file_lines:
        pbx = pbx.replace(
            "/* End PBXBuildFile section */",
            "\n".join(build_file_lines) + "\n/* End PBXBuildFile section */",
            1,
        )

    # 2) Insert PBXFileReference entries.
    if file_ref_lines:
        pbx = pbx.replace(
            "/* End PBXFileReference section */",
            "\n".join(file_ref_lines) + "\n/* End PBXFileReference section */",
            1,
        )

    # 3) Add file refs to the BarnClimate group children.
    if group_children:
        pattern = re.compile(
            r"(" + re.escape(GROUP_ID) + r" /\* BarnClimate \*/ = \{\s*isa = PBXGroup;\s*children = \()"
        )
        pbx = pattern.sub(lambda m: m.group(1) + "\n" + "\n".join(group_children), pbx, count=1)

    # 4) Add build files to the Sources build phase.
    if sources_files:
        pattern = re.compile(
            r"(" + re.escape(SOURCES_PHASE_ID) + r" /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;\s*buildActionMask = \d+;\s*files = \()"
        )
        pbx = pattern.sub(lambda m: m.group(1) + "\n" + "\n".join(sources_files), pbx, count=1)

    # 5) Set deployment target to 14.0 everywhere.
    pbx = pbx.replace("IPHONEOS_DEPLOYMENT_TARGET = 15.5;", "IPHONEOS_DEPLOYMENT_TARGET = 14.0;")

    with open(PBX, "w") as f:
        f.write(pbx)

    added = len(build_file_lines)
    print(f"Registered {added} new Swift file(s). Total swift files: {len(swift_files)}.")
    for name in swift_files:
        print("  •", name)


if __name__ == "__main__":
    main()
