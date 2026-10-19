#!/usr/bin/env python3
"""Record actual deployment targets and prevent claiming an unsupported macOS version."""

import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
info_path = root / "Contents/Info.plist"
info = plistlib.loads(info_path.read_bytes())
minimum = tuple(map(int, info.get("LSMinimumSystemVersion", "14.0").split(".")[:2]))
entries = {}
for path in root.rglob("*"):
    if not path.is_file() or path.is_symlink():
        continue
    with path.open("rb") as source:
        magic = source.read(4)
    if magic not in {
        b"\xcf\xfa\xed\xfe",
        b"\xfe\xed\xfa\xcf",
        b"\xca\xfe\xba\xbe",
        b"\xbe\xba\xfe\xca",
    }:
        continue
    output = subprocess.run(["vtool", "-show-build", str(path)], text=True, capture_output=True)
    versions = re.findall(r"minos\s+(\d+)\.(\d+)", output.stdout)
    if not versions:
        legacy = subprocess.run(["otool", "-l", str(path)], text=True, capture_output=True).stdout
        versions = re.findall(
            r"cmd LC_VERSION_MIN_MACOSX\n\s+cmdsize \d+\n\s+version (\d+)\.(\d+)",
            legacy,
        )
    if versions:
        version = max((int(a), int(b)) for a, b in versions)
        minimum = max(minimum, version)
        entries[str(path.relative_to(root))] = ".".join(map(str, version))
info["LSMinimumSystemVersion"] = ".".join(map(str, minimum))
info_path.write_bytes(plistlib.dumps(info))
(root / "Contents/Resources/deployment-targets.json").write_text(
    json.dumps({"minimum_macos": info["LSMinimumSystemVersion"], "binaries": entries}, indent=2)
)
print(
    f"Inspected {len(entries)} native binaries. Packaged app requires macOS {info['LSMinimumSystemVersion']} or later."
)
