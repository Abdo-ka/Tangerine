#!/usr/bin/env python3
"""Verify the frozen image, media and office engines without development PATH."""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pymupdf
from docx import Document
from PIL import Image

app = Path(sys.argv[1]).resolve()
engine = app / "Contents/Resources/engine"
environment = {**os.environ, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"}
for key in ("TANGERINE_FFMPEG", "TANGERINE_FFPROBE", "TANGERINE_SOFFICE"):
    environment.pop(key, None)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)


def convert(source, extension, destination):
    original = hashlib.sha256(source.read_bytes()).digest()
    request = destination / "request.json"
    request.write_text(
        json.dumps(
            {
                "inputs": [str(source)],
                "operation": "convert",
                "format": extension,
                "destination": str(destination),
                "options": {},
            }
        )
    )
    result = subprocess.run(
        [str(engine / "tangerine-engine"), str(request)],
        env=environment,
        capture_output=True,
        text=True,
        check=True,
        timeout=180,
    )
    assert hashlib.sha256(source.read_bytes()).digest() == original
    return Path(json.loads(result.stdout)["outputs"][0])


with tempfile.TemporaryDirectory(prefix="tangerine-package-") as folder:
    directory = Path(folder)
    image = directory / "image.png"
    Image.new("RGB", (81, 53), "orange").save(image)
    with Image.open(convert(image, "jpg", directory)) as result:
        assert result.size == (81, 53)
    document = Document()
    document.add_paragraph("Tangerine packaged office engine")
    source = directory / "document.docx"
    document.save(source)
    with pymupdf.open(convert(source, "pdf", directory)) as result:
        assert "Tangerine packaged office engine" in "".join(p.get_text() for p in result)
    gif = directory / "animation.gif"
    Image.new("RGB", (88, 64), "orange").save(
        gif, save_all=True, append_images=[Image.new("RGB", (88, 64), "green")], duration=250
    )
    video = convert(gif, "webm", directory)
    metadata = json.loads(
        subprocess.check_output(
            [
                str(engine / "bin/ffprobe"),
                "-v",
                "error",
                "-show_streams",
                "-show_format",
                "-of",
                "json",
                str(video),
            ],
            env=environment,
            text=True,
        )
    )
    stream = next(item for item in metadata["streams"] if item["codec_type"] == "video")
    assert (stream["width"], stream["height"]) == (88, 64)
    assert float(metadata["format"]["duration"]) > 0
print("Frozen image, LibreOffice and FFmpeg fixtures passed; original hashes preserved.")
