# Contributing

Welcome. Small, tested improvements are particularly useful in this early preview.
Read [AGENTS.md](AGENTS.md) first. No contributor agreement is required; by
contributing you agree to license your contribution under AGPL-3.0-or-later.

## Development

1. Fork and clone the repository. Create a branch for a focused change.
2. Install Xcode/Swift, Python 3.13 and Homebrew.
3. Run `scripts/bootstrap.sh --with-office`.
4. Run `swift run` or open Package.swift in Xcode.
5. Run `swift test` and `.venv/bin/python -m unittest discover -s Tests/Python -v`.
6. Run `.venv/bin/python scripts/matrix_smoke.py` for the full generated format matrix.
   Pages routes are explicitly reported as interactive checks.
7. Run `.venv/bin/ruff check Resources scripts Tests/Python` and
   `.venv/bin/ruff format --check Resources scripts Tests/Python`.

Keep generated artifacts out of Git. All test fixtures must be generated or have
clear redistribution permission; never submit private documents or recordings.

## Useful contributions

- Improve layout fidelity of document conversions.
- Add fixtures for the format matrix, scanned PDFs, RTL and complex scripts.
- Improve accessible keyboard navigation and VoiceOver descriptions.
- Test Finder drag behavior across displays, Spaces and macOS versions.
- Improve video crop/redaction UI and audio waveform selection.
- Build signed/notarized release automation and test on clean Macs.

## Pull requests

Explain the problem, the resulting behavior, and how you verified it. Include
screenshots for UI changes and a small generated fixture for conversion bugs.
A passing build alone does not establish that a file conversion is correct.
Open the output with a parser/player and assert the property you changed.

## Manual UI checklist

- Launch the packaged app and the Swift development build.
- Drop one file, several files, mixed types and a folder; remove/reorder inputs.
- Convert each supported category, choose another output folder, and retry a
  duplicate name. Confirm the originals' hashes do not change.
- Inspect crop coordinates, annotation placement, image redaction regions and
  PDF organization. Use valid, invalid, encrypted and malformed inputs.
- Preview/trim/split media, including clips without audio. Cancel a long job and
  confirm no child converter or partial output is left running.
- Start dragging from Finder, trigger each wheel mode, release the modifier,
  hover options, drop, cancel, and repeat across monitors/Spaces.
- Exercise AirDrop, shelf drag-out, copy/paste in Finder, Copy Path, Terminal and
  Move (including collision errors). Move intentionally changes original paths.
- Deny and then grant Pages Automation permission. Errors must be understandable.
- Check VoiceOver, keyboard focus, enlarged text, light/dark system appearances.

## Bug reports

Use the issue templates. Include macOS version, architecture, app version, source
and target format, expected/actual behavior, and a non-sensitive reproduction.
For vulnerabilities, follow SECURITY.md instead of posting private files publicly.
