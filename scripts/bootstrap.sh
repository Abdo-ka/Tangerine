#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then echo 'The desktop app requires macOS.' >&2; exit 1; fi
command -v swift >/dev/null || { echo 'Install Xcode or the Command Line Tools first.' >&2; exit 1; }
if [[ -z "${PYTHON_BIN:-}" ]]; then
    PYTHON_BIN="$(command -v python3.13 || command -v python3)"
fi
"$PYTHON_BIN" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 13) else "Python 3.13 or later is required. Install it and rerun setup.")' 
"$PYTHON_BIN" -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
    command -v brew >/dev/null || { echo 'Install Homebrew, then run: brew install ffmpeg' >&2; exit 1; }
    brew install ffmpeg
fi
if [[ "${1:-}" == '--with-office' ]]; then
    if [[ ! -d /Applications/LibreOffice.app ]]; then
        brew fetch --retry --cask libreoffice
        brew install --cask libreoffice
    fi
fi
printf '%s\n' 'Dependencies ready. Use swift run, or scripts/build-app.sh to package the app.'
