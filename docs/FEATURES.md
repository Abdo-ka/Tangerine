# Capabilities and verification

This file distinguishes implemented behavior from verified parity. All 26 reference
tool identifiers have implementations, plus image resizing and background removal. The reference catalog contains 275 routes. The generated matrix verifies 259 routes;
16 Apple Pages routes have separately passed interactive native-app testing on the
local Mac. They remain manual checks in headless CI. Complex real-world
file fidelity still needs broader validation. See VERIFICATION.md.

## Conversion matrix

| Input | Outputs | Notes |
| --- | --- | --- |
| JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP, SVG | JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP, PDF | SVG input only; rasterized. Animated image frames are not preserved by image tools. |
| MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA | Other listed audio formats | Lossy encoding uses FFmpeg; metadata is not guaranteed to survive. |
| MP4, MOV, MKV, WebM, AVI, WMV | Other listed video formats, GIF, MP3 | Codecs are transcoded; GIF→video supported. MP3 export requires an audio track. |
| PDF | DOCX, Pages, PPTX, XLSX, JPG, PNG, EPUB, TXT, Markdown | Page images at 300 DPI. OCR for scanned text through the app. |
| DOCX, Pages, MD, TXT, RTF, RTFD, text clippings, HTML | DOCX, Pages, PDF, TXT, MD, HTML, EPUB, JPG, PNG | RTF/RTFD/clippings are input only. See fidelity limits below. |
| PPT/PPTX | PDF, JPG, PNG | LibreOffice required; PPT input only. |
| XLSX/XLS/ODS/CSV/TSV | XLSX, ODS, CSV, TSV, PDF | LibreOffice required; XLS input only. Delimited exports use the first sheet. |
| EPUB | PDF, DOCX, Pages, TXT, MD, HTML | Text reconstruction; DRM-protected books unsupported. |
| SRT/VTT | SRT, VTT, TXT | Cue text/timing; styling and some advanced WebVTT features are simplified. |
| ZIP/TAR/GZIP/RAR | ZIP, TAR, GZIP; extract | RAR input only; GZIP outputs a `.tar.gz` archive. Links/special entries rejected. |

Same-format conversion is omitted from the UI. Mixed selections offer the
intersection of compatible routes and tools. Conversion quality varies by source.
OGG audio uses Vorbis when the bundled FFmpeg provides it, otherwise Opus. Both
produce Ogg containers; the selected codec depends on the packaged encoder set.

## Tools

| Category | Implemented tools |
| --- | --- |
| Images | Compress, metadata, adjustments, annotations, background, crop, resize, remove background, redaction, create PDF, collage |
| Video | Compress, metadata, mute, trim, split, crop, speed, join, snapshots, redaction |
| Audio | Compress, metadata, normalize, trim, channels, visualize, bleep |
| PDF | Compress, metadata, split, organize, merge |
| Archives | Extract |

Compression and metadata are shared tools, giving **28 unique tool IDs**, including the two additional image tools.

## File actions

AirDrop, floating shelf, Finder-compatible clipboard copy, move, copy path, and
Terminal are implemented with AppKit. Their interactive behavior requires the
manual checklist in CONTRIBUTING.md; unit tests cannot certify recipient pickers,
Finder paste operations or OS permission dialogs.

## Current fidelity and interface limits

- PDF→DOCX/Pages reconstructs editable text, rather than preserving original layout.
  PDF→XLSX uses detected tables or splits text lines into cells. PDF→PPTX preserves
  each page as an image, rather than individually editable slide objects.
- Most document/EPUB interchange reconstructs paragraphs and basic headings. Complex
  layouts, original rich-text styling, embedded images and document metadata may be
  simplified. DOCX→PDF/HTML uses LibreOffice for better fidelity.
- EPUB exports offer reflowable text or original page images through conversion options.
- Image tools operate on the first frame of animated or multi-frame images.
- Crop/redaction offers visual region selection for images and video frames. Audio
  has waveform range handles, numeric times and playback. Native playback support
  varies by input codec; conversion support is broader than AVFoundation previews.
- Annotation output and previews support text/arrows/shapes/callouts. Background
  compositing is currently export-only. Photo sliders show an approximate preview;
  rotation, sharpness and effects are applied on export.
- PDF organization provides thumbnail reordering, per-page rotation, duplication and
  removal, plus numeric page-order input and an optional rotation for all pages.
- Image compression supports a target size and scale. Video/audio provide presets,
  bitrate and approximate target-size/percentage-reduction controls. Exact media
  byte counts are not guaranteed by bitrate-based encoding.
- Collage supports grid/row/column/featured layouts and spacing. Corner radius applies
  to regular grid/row/column tiles. Shelf edge pinning and custom wheel keys are implemented.
- Face/text detection uses Vision on images. Review detection results; detection is
  not proof that every sensitive area was found. Large-file memory/resource limits
  need broader testing. RAR uses a bounded libarchive streaming reader with path/link checks. The app
  is not a sandbox for actively hostile files.
- Global wheel interactions across macOS versions, Spaces and displays require manual
  testing. Defaults are Shift/Command/Control; Settings lets you choose distinct modifier keys.
- Pages requires the separate Apple Pages app and macOS Automation permission. It is
  not exercised by headless CI. Encrypted PDFs require a password in tool JSON options;
  right-click a format and choose Options to enter a password.
- Only the local Apple silicon development environment has been exercised. macOS 14
  and other hardware require clean-machine validation before supported releases.

## Automated coverage

Swift tests cover catalog compatibility, aliases, unique tool IDs and input-only
formats. Python integration tests generate fixtures for image formats, PDF tools and
exports, document/book conversion, subtitles, archives, media formats and all tools.
They assert selected output properties and unchanged input hashes. Malformed crop
and archive traversal tests verify failure does not publish output.

Pages conversion, global drag behavior, AirDrop, clipboard paste, Terminal,
window behavior, accessibility and OS permission flows also need explicit manual
validation. A passing suite is a contributor-preview gate, not a perfection claim.
