import Foundation

struct FileCategory: Identifiable, Hashable {
  let id: String
  let name: String
  let symbol: String
  let extensions: [String]
  static let all: [FileCategory] = [
    .init(
      id: "image", name: "Images", symbol: "photo",
      extensions: [
        "jpg", "jpeg", "png", "webp", "heic", "heif", "tif", "tiff", "avif", "bmp", "svg",
      ]),
    .init(
      id: "video", name: "Video", symbol: "film",
      extensions: ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"]),
    .init(
      id: "audio", name: "Audio", symbol: "waveform",
      extensions: ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "aif", "wma"]),
    .init(id: "pdf", name: "PDF", symbol: "doc.richtext", extensions: ["pdf"]),
    .init(
      id: "document", name: "Documents", symbol: "doc.text",
      extensions: ["docx", "pages", "md", "markdown", "txt", "rtf", "rtfd", "textclipping", "html"]),
    .init(
      id: "slides", name: "Slides", symbol: "rectangle.on.rectangle", extensions: ["ppt", "pptx"]),
    .init(
      id: "spreadsheet", name: "Spreadsheets", symbol: "tablecells",
      extensions: ["xlsx", "xls", "ods", "csv", "tsv"]),
    .init(id: "epub", name: "EPUB", symbol: "book.closed", extensions: ["epub"]),
    .init(
      id: "subtitle", name: "Subtitles", symbol: "captions.bubble", extensions: ["srt", "vtt"]),
    .init(
      id: "archive", name: "Archives", symbol: "archivebox",
      extensions: ["zip", "tar", "gz", "tgz", "rar"]),
  ]
  static func of(_ url: URL) -> FileCategory? {
    all.first { $0.extensions.contains(url.pathExtension.lowercased()) }
  }
}

struct Tool: Identifiable, Hashable {
  let id: String
  let name: String
  let symbol: String
  let detail: String
  let categories: [String]
  var combines: Bool { ["createPDF", "mergePDF", "joinVideos", "createCollage"].contains(id) }
  static let all: [Tool] = [
    .init(
      id: "compress", name: "Compress", symbol: "arrow.down.right.and.arrow.up.left",
      detail: "Reduce file size, with quality and size controls.",
      categories: ["image", "video", "audio", "pdf"]),
    .init(
      id: "removeMetadata", name: "Edit metadata", symbol: "tag",
      detail: "Inspect, edit or strip embedded information.",
      categories: ["image", "video", "audio", "pdf"]),
    .init(
      id: "editImage", name: "Edit photo", symbol: "slider.horizontal.3",
      detail: "Exposure, contrast, saturation, sharpness and rotation.", categories: ["image"]),
    .init(
      id: "annotateImage", name: "Annotate", symbol: "pencil.tip",
      detail: "Add text, arrows, shapes and numbered callouts.", categories: ["image"]),
    .init(
      id: "frameImage", name: "Add background", symbol: "photo.artframe",
      detail: "Solid, gradient or image backgrounds with rounded corners.", categories: ["image"]),
    .init(
      id: "cropImage", name: "Crop image", symbol: "crop",
      detail: "Choose a ratio or crop to exact pixel dimensions.", categories: ["image"]),
    .init(
      id: "resizeImage", name: "Resize image", symbol: "arrow.up.left.and.arrow.down.right",
      detail: "Set exact dimensions or scale while preserving the aspect ratio.",
      categories: ["image"]),
    .init(
      id: "removeBackground", name: "Remove background", symbol: "person.crop.rectangle",
      detail: "Keep the foreground subject on a transparent background, locally.",
      categories: ["image"]),
    .init(
      id: "redactImage", name: "Redact photo", symbol: "eye.slash",
      detail: "Find faces or text locally; blur or cover private areas.", categories: ["image"]),
    .init(
      id: "createPDF", name: "Create PDF", symbol: "doc.badge.plus",
      detail: "Combine images into a PDF, one image per page.", categories: ["image"]),
    .init(
      id: "createCollage", name: "Make collage", symbol: "rectangle.3.group",
      detail: "Arrange images in a grid, row, column or featured layout.", categories: ["image"]),
    .init(
      id: "normalizeAudio", name: "Normalize volume", symbol: "waveform",
      detail: "Normalize loudness to a target LUFS level.", categories: ["audio"]),
    .init(
      id: "audioToVideo", name: "Audio visualizer", symbol: "waveform.path",
      detail: "An orange waveform or a still background, exported as MP4.", categories: ["audio"]),
    .init(
      id: "trimAudio", name: "Trim audio", symbol: "scissors",
      detail: "Trim a range or remove silence from the ends.", categories: ["audio"]),
    .init(
      id: "audioChannels", name: "Audio channels", symbol: "hifispeaker.2",
      detail: "Convert to mono or stereo.", categories: ["audio"]),
    .init(
      id: "redactAudio", name: "Bleep audio", symbol: "speaker.slash",
      detail: "Replace one or more time ranges with a tone.", categories: ["audio"]),
    .init(
      id: "muteVideo", name: "Remove audio", symbol: "speaker.slash.fill",
      detail: "Export a silent copy of your video.", categories: ["video"]),
    .init(
      id: "trimVideo", name: "Trim video", symbol: "scissors",
      detail: "Keep a precise range with frame-by-frame preview.", categories: ["video"]),
    .init(
      id: "splitVideo", name: "Split video", symbol: "film.stack",
      detail: "Export separate clips at your chosen time points.", categories: ["video"]),
    .init(
      id: "cropVideo", name: "Crop video", symbol: "crop",
      detail: "Crop the picture while preserving the audio.", categories: ["video"]),
    .init(
      id: "changeVideoSpeed", name: "Playback speed", symbol: "speedometer",
      detail: "Slow down or speed up, preserving audio pitch.", categories: ["video"]),
    .init(
      id: "joinVideos", name: "Join videos", symbol: "film.stack",
      detail: "Arrange clips and combine them into one MP4.", categories: ["video"]),
    .init(
      id: "videoSnapshots", name: "Save frames", symbol: "camera",
      detail: "Export full-resolution PNGs at chosen timestamps.", categories: ["video"]),
    .init(
      id: "redactVideo", name: "Redact video", symbol: "eye.slash",
      detail: "Cover a region for all or part of a video.", categories: ["video"]),
    .init(
      id: "splitPDF", name: "Split PDF", symbol: "rectangle.split.2x1",
      detail: "Save every page as a separate PDF.", categories: ["pdf"]),
    .init(
      id: "organizePDF", name: "Organize PDF", symbol: "square.grid.2x2",
      detail: "Reorder, rotate, duplicate or remove pages.", categories: ["pdf"]),
    .init(
      id: "mergePDF", name: "Merge PDFs", symbol: "doc.on.doc",
      detail: "Combine PDFs in the order you choose.", categories: ["pdf"]),
    .init(
      id: "extractArchive", name: "Extract archive", symbol: "shippingbox",
      detail: "Safely unpack ZIP, TAR, GZIP or RAR.", categories: ["archive"]),
  ]
}

enum Catalog {
  static func formats(for url: URL) -> [String] {
    let ext = url.pathExtension.lowercased()
    let category = FileCategory.of(url)?.id
    var outputs: [String]
    switch category {
    case "image": outputs = ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"]
    case "audio": outputs = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]
    case "video":
      outputs =
        ext == "gif"
        ? ["mp4", "mov", "mkv", "webm", "avi", "wmv"]
        : ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "mp3"]
    case "pdf": outputs = ["docx", "pages", "pptx", "xlsx", "jpg", "png", "epub", "txt", "md"]
    case "slides": outputs = ["pdf", "jpg", "png"]
    case "spreadsheet": outputs = ["xlsx", "ods", "csv", "tsv", "pdf"]
    case "document": outputs = ["docx", "pages", "pdf", "txt", "md", "html", "epub", "png", "jpg"]
    case "epub": outputs = ["pdf", "docx", "pages", "txt", "md", "html"]
    case "subtitle": outputs = ["srt", "vtt", "txt"]
    case "archive": outputs = ["zip", "tar", "gz"]
    default: outputs = []
    }
    let normalized =
      ["jpeg": "jpg", "tif": "tiff", "heif": "heic", "aif": "aiff", "markdown": "md", "tgz": "gz"][
        ext] ?? ext
    return outputs.filter { $0 != normalized }
  }
  static func formats(for urls: [URL]) -> [String] {
    guard let first = urls.first else { return [] }
    return formats(for: first).filter { format in
      urls.allSatisfy { formats(for: $0).contains(format) }
    }
  }
  static func tools(for urls: [URL]) -> [Tool] {
    guard !urls.isEmpty else { return [] }
    return Tool.all.filter { tool in
      urls.allSatisfy { tool.categories.contains(FileCategory.of($0)?.id ?? "") }
    }
  }
  static let actions = [
    ("airDrop", "AirDrop", "airplayaudio"), ("float", "Float", "pin"),
    ("copy", "Copy", "doc.on.doc"), ("move", "Move", "folder"), ("copyPath", "Copy path", "link"),
    ("openTerminal", "Terminal", "terminal"),
  ]
}
