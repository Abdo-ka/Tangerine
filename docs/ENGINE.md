# Local worker API

During development:

```sh
.venv/bin/python Resources/engine.py /path/to/request.json
```

The frozen executable accepts the same argument. Standard input can also contain
the JSON request. Stdout is one JSON result; diagnostics go to stderr. Exit status
is zero for success and one for error.

```json
{
  "inputs": ["/absolute/path/photo.png"],
  "operation": "cropImage",
  "format": "",
  "destination": "/absolute/path/output",
  "options": {"x": 0.1, "y": 0.1, "width": 0.8, "height": 0.8}
}
```

Success: `{"outputs":["/absolute/path/output/photo cropImage.png"]}`.
Failure: `{"error":"Human-readable reason"}`. Destination defaults to the first
input's parent; it must exist. Original inputs are never intentionally overwritten.
For a batch, outputs completed before a later failure remain on disk. Partial batches return `outputs` alongside `errors:[{input,error}]`; the app
shows both successful output links and individual failures.

`operation: "convert"` uses `format`, a lowercase extension. Other operation IDs
are defined in Catalog.swift. Combined operations use input order. Other operations
process each input independently.

## Options

| Tools | Keys and defaults |
| --- | --- |
| Image convert/compress | `quality:80`, `scale:1`, `targetKB:0`; scale applies to compress |
| Crop image/video | `x:0`, `y:0`, `width:1`, `height:1` in normalized top-left coordinates |
| Resize image / crop image | `outputWidth`, `outputHeight` (pixels; zero/absent preserves crop proportions) |
| Edit image | `brightness:1`, `contrast:1`, `saturation:1`, `sharpness:1`, `rotation:0` clockwise, `effect:original/grayscale/sepia/invert/blur` |
| Annotate | `annotationType:text`, `text`, `fontSize`, `color:#ff702e`, `stroke:6`; or `annotations:[{type,text,x,y,width,height}]` |
| Background | `spacing:60`, `radius:24`, `background:#fff0df`, `gradient:false`, `color:#ff702e`, `backgroundImage` |
| Image redaction | `regions:[{x,y,width,height}]` or crop coordinates; `redaction:solid/blur`, `color:#000000` |
| Collage | `layout:grid/row/column/featured`, `cellSize:600`, `spacing:20`, `background:#fff8ef`, `radius:0` |
| Media compress | `audioKbps:128`, `videoKbps:1800`; `targetKB:0`, `reduction:0`; target size is approximate; lossless WAV/AIFF is compressed to FLAC |
| Normalize | `lufs:-16` |
| Trim | `start:0`, `end:0` (zero=end of file); audio `removeSilence:false` trims only ends |
| Channels | `channels:1` (mono) or `2` (stereo) |
| Audio visualizer | `outputWidth:1280`, `outputHeight:720`, optional `backgroundImage` for still image |
| Bleep | `ranges:"1:2.5,4:6"` seconds |
| Speed | `speed:2`, supported range 0.25–4, audio pitch maintained |
| Video split/snapshots | `times:"1,2.5,4"` seconds |
| Video redaction | crop coordinates, `start:0`, `end:0`, `redaction:solid/blur` |
| PDF organize | `pages:"3,1,2,2,4-6"`, `rotation:0/90/180/270` |
| PDF compress | `quality:65` for smaller embedded images; vectors/text retained |
| PDF password | `password` used for locked PDF operations |
| PDF text exports | `textOverride:["page 1 text","page 2 text"]`; native app supplies OCR text when needed |
| Metadata | `metadata:{}` removes tags; PDF uses standard PyMuPDF keys (`title`, `author`, `subject`, etc.); image supports title/author/copyright/camera; media supports FFmpeg metadata tags |

Advanced JSON options in a tool sheet override native controls. Invalid inputs
should fail with a job error, not modify originals. Do not supply sensitive paths
or passwords in public issue attachments.

Background removal is performed by the native app with Apple Vision and passed
to the worker as a temporary transparent PNG. The standalone Python worker cannot
run Apple Vision itself. PDF EPUB export accepts `epubLayout:reflowable/fixed`.
PDF organization also accepts `pageSelections:[{page:1,rotation:90}]`.

## Environment overrides

`TANGERINE_FFMPEG`, `TANGERINE_FFPROBE`, `TANGERINE_SOFFICE` can identify local
executables. Bundled tools are preferred over PATH, except explicit overrides.
The app's build script uses `TANGERINE_OFFICE_APP` to find a LibreOffice .app.

The worker has no upload/network client. It invokes tools with argument arrays,
uses per-conversion LibreOffice profiles, rejects archive traversal/links, and
publishes staged results. Resource-limit coverage is documented in FEATURES.md.
