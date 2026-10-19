#!/usr/bin/env python3
"""Bundle Homebrew FFmpeg and all non-system dylibs with relative install names."""

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
binaries = root / "bin"
libraries = root / "lib"
binaries.mkdir(exist_ok=True)
libraries.mkdir(exist_ok=True)
media = shutil.which("ffmpeg")
if media is None:
    raise SystemExit("Missing FFmpeg. Run scripts/bootstrap.sh first.")
configuration = subprocess.check_output([media, "-buildconf"], stderr=subprocess.STDOUT, text=True)
if "--enable-nonfree" in configuration:
    raise SystemExit("Refusing to redistribute an FFmpeg build configured with --enable-nonfree.")
(root / "ffmpeg-buildconf.txt").write_text(configuration)
queue = []
mappings = {}
hashes = {}
for name in ("ffmpeg", "ffprobe"):
    original = Path(shutil.which(name) or "").resolve()
    if not original.is_file():
        raise SystemExit(f"Missing {name}; run scripts/bootstrap.sh")
    destination = binaries / name
    shutil.copy2(original, destination)
    queue.append((original, destination))
visited = set()
while queue:
    original, target = queue.pop(0)
    if target in visited:
        continue
    visited.add(target)
    target.chmod(0o755)
    listing = subprocess.check_output(["otool", "-L", str(original)], text=True).splitlines()[1:]
    for line in listing:
        dependency = line.strip().split(" (")[0]
        if dependency.startswith(("/System/", "/usr/lib/")):
            continue
        if dependency.startswith("@"):
            if dependency.startswith("@loader_path/"):
                path = original.parent / dependency.removeprefix("@loader_path/")
            elif dependency.startswith("@rpath/"):
                name = dependency.removeprefix("@rpath/")
                commands = subprocess.check_output(
                    ["otool", "-l", str(original)], text=True
                ).splitlines()
                search = [
                    original.parent,
                    Path("/opt/homebrew/lib"),
                    Path("/usr/local/lib"),
                ]
                for index, command in enumerate(commands):
                    if command.strip() == "cmd LC_RPATH":
                        for detail in commands[index + 1 : index + 5]:
                            if detail.strip().startswith("path "):
                                value = (
                                    detail.strip()[5:]
                                    .split(" (offset")[0]
                                    .replace("@loader_path", str(original.parent))
                                )
                                search.append(Path(value))
                path = next(
                    (folder / name for folder in search if (folder / name).is_file()),
                    None,
                )
                if path is None:
                    raise SystemExit(f"Unresolved dependency {dependency} in {original}")
            else:
                raise SystemExit(f"Unresolved dependency {dependency} in {original}")
        else:
            path = Path(dependency)
        if not path.is_file():
            raise SystemExit(f"Missing dylib {path}")
        path = path.resolve()
        copied = libraries / path.name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if path.name in hashes and hashes[path.name] != digest:
            raise SystemExit(f"Conflicting dylibs: {path.name}")
        hashes[path.name] = digest
        if not copied.exists():
            shutil.copy2(path, copied)
            queue.append((path, copied))
        replacement = (
            "@loader_path/" if target.parent == libraries else "@loader_path/../lib/"
        ) + path.name
        subprocess.run(
            ["install_name_tool", "-change", dependency, replacement, str(target)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        mappings[str(path)] = str(copied.relative_to(root))
    if target.parent == libraries:
        subprocess.run(
            ["install_name_tool", "-id", "@loader_path/" + target.name, str(target)],
            check=True,
            stderr=subprocess.PIPE,
        )
for target in sorted(visited):
    subprocess.run(
        ["codesign", "--force", "--sign", "-", str(target)],
        check=True,
        stderr=subprocess.PIPE,
    )

(root / "native-manifest.json").write_text(json.dumps(mappings, indent=2))
print(f"Bundled FFmpeg, FFprobe and {len(hashes)} libraries.")
