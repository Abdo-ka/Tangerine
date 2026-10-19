# Verification snapshot — 2026-10-19

Local environment: Apple silicon, macOS 27.0.1. This records observed results,
not a guarantee for every input file or a supported-hardware certification.

| Check | Observed result |
| --- | --- |
| Native production build | Passed |
| Swift tests | 13 passed, including native OCR/background removal through the actual Python worker |
| Python integration tests | 28 passed; generated image/media/document/archive fixtures, original hashes, unsafe archives, partial batches, cancellation, OGG Opus fallback and transparent-animation WebM output |
| Reference format catalog | 275 routes |
| Full generated conversion matrix | 259 passed, 0 failed; 16 Pages routes separately passed interactive testing |
| Python lint/format and dependency checks | Passed |
| App bundle signature | Ad-hoc signature; deep/strict verification passed |
| Bundled engine isolation | Image and LibreOffice conversions succeeded with PATH restricted to system tools |
| DMG installer | Image checksum verified; mounted app passed deep/strict signature verification; mounted worker produced independently parsed JPEG and PDF outputs with originals unchanged; simplified wheel layout visually inspected; LZMA image verified |
| GitHub-hosted native fixtures | All 13 pass on macOS 26, including foreground-mask transparency. The older macOS 14 virtual image lacks the inference context / AppleM2ScalerCSCDriver; native checks now use macOS 26 without changing assertions. Engine and source-build checks retain macOS 14 coverage. |
| Main window/tool text | Visually inspected; matching adaptive foreground/background colors, readable fields and labels |
| UI output checks | Image conversion, exact crop, background removal, three-page PDF split and video crop opened with independent parsers |

The route report is generated at `.build/matrix-report.json` and retained as a
GitHub Actions artifact; generated matrix reports are not committed.
The full matrix generates its own RAR4 stored-file fixture; no proprietary archive
writer or downloaded fixture is needed.

Reproduce:

```sh
swift test
.venv/bin/python -m unittest discover -s Tests/Python -v
.venv/bin/python scripts/matrix_smoke.py
.venv/bin/ruff check Resources scripts Tests/Python
.venv/bin/ruff format --check Resources scripts Tests/Python
```

Pages routes require an installed Apple Pages app and interactive macOS Automation
permission. AirDrop recipients, Finder clipboard paste, multi-display drag behavior,
accessibility, clean-machine compatibility and public release signing/notarization
remain manual release checks. Current bundled Homebrew dependencies require macOS
26; the build audits and records the actual minimum instead of advertising macOS
14 compatibility for that binary.

Native player verification: the AppKit player opened and played the generated
four-second clip without the previous SwiftUI AVKit bridge crash. A half-width,
half-height crop exported 320x180 video with its audio stream preserved.

The custom Liquid Glass treatment was removed after desktop screenshots revealed
underlying application text interfering with the sidebar. The window, structural
chrome and wheel use opaque surfaces. The logo keeps the original orange-and-white style with a closed tangerine outline.

Pages edition compatibility: both classic Pages and Creator Studio identifiers
are supported. All 16 routes completed in the actual packaged app using generated
files. The eight Pages outputs passed ZIP/IWA structure checks. The eight exports
were independently parsed (DOCX, PDF, text, Markdown, HTML, EPUB and PNG/JPEG pages).
The Pages source remained byte-for-byte unchanged. Native LaunchServices document
opening fixes the sandbox access error for copied Pages inputs. The observations
are recorded separately in [verification/pages-matrix.json](verification/pages-matrix.json);
headless CI still reports those 16 routes as manual.
