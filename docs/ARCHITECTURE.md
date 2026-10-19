# Architecture

The app is a Swift package with one executable and an XCTest target. It uses native
macOS frameworks; it does not host a web page or connect to a conversion server.

| Component | Responsibility |
| --- | --- |
| `Catalog.swift` | File categories, compatible batch formats, 28 tool descriptors, six actions |
| `ContentView.swift` | Workspace, input order, conversion grid, activity, output selection |
| `ToolSheet.swift` | Tool parameters, source previews, region selection, metadata, JSON overrides |
| `AppModel.swift` | Serialized job queue, cancellation, subprocess I/O, Vision OCR and detection |
| `DragWheel.swift` | AppKit drag destination panel and floating file shelf |
| `Resources/engine.py` | Local conversion implementations and staged output publication |
| `scripts/build-app.sh` | Release build, frozen worker, media/office bundling, local signing |

## Job lifecycle

The UI snapshots inputs, destination and options at submission. AppModel processes
one request at a time and uses Task.detached for the blocking worker. Native PDF
text extraction/OCR and foreground background removal happen there. The worker receives a JSON request in a private
temporary directory. Its result and diagnostics go to separate files, avoiding
pipe-buffer deadlocks. Errors are attached to the job.

The Python worker creates a temporary directory on the destination volume for each
output. It validates that an output exists and is nonempty before renaming it into
place. Existing names get a numeric suffix. For a batch, individual successful
outputs are committed independently; the whole batch is not a transaction.

Cancellation sends SIGTERM to the worker. The worker terminates the active child
process group and unwinds temporary directories. Cancellation is checked between OCR pages. A Vision request currently in flight
can finish before cancellation is observed; it does not publish files.

## External engines

- Pillow + pillow-heif: raster image transforms and encoding.
- PyMuPDF: PDF/SVG rendering, PDF operations, table extraction and text documents.
- FFmpeg/FFprobe: media encoding, filtering and inspection.
- LibreOffice: presentation/spreadsheet conversion and layout-preserving DOCX exports.
- Apple Pages: its proprietary file format, driven with argument-based AppleScript.
- python-docx/python-pptx/openpyxl/EbookLib: document reconstruction and book exports.

## Boundaries

The catalog and the engine must evolve together. UI metadata and parameters are
not proof of implementation. Integration tests parse resulting files and assert
contents/dimensions/duration where appropriate. The feature matrix records the
remaining fidelity and manual-validation gaps.

The app is not App Sandbox enabled: Finder integration, subprocesses, file actions
and Pages automation need broader access. Developer ID distribution is the intended
release path. App Store sandboxing would require a separate design.
