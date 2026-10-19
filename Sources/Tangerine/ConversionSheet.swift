import SwiftUI

struct ConversionChoice: Identifiable {
  var id: String { format }
  let format: String
}
struct ConversionSheet: View {
  let format: String
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var quality = 85.0
  @State private var layout = "reflowable"
  @State private var password = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Convert to \(format.uppercased())").font(.title2.weight(.semibold))
      if ["jpg", "webp", "heic", "avif"].contains(format) {
        VStack(alignment: .leading) {
          HStack {
            Text("Image quality")
            Spacer()
            Text("\(Int(quality))%").monospacedDigit()
          }
          Slider(value: $quality, in: 10...100)
        }
      }
      if model.files.contains(where: { $0.pathExtension.lowercased() == "pdf" }) {
        SecureField("PDF password (if needed)", text: $password).textFieldStyle(.roundedBorder)
        if format == "epub" {
          Picker("Book layout", selection: $layout) {
            Text("Adjustable text").tag("reflowable")
            Text("Original page layout").tag("fixed")
          }
          Text(
            "Adjustable text works with reader font sizes. Original layout preserves each page as an image."
          ).font(.callout).foregroundStyle(.secondary)
        }
        if ["docx", "pages", "xlsx"].contains(format) {
          Text("Creates editable content. The original page layout may change.").font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      HStack {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("Convert") {
          model.submit(
            format: format,
            options: ["quality": quality, "password": password, "epubLayout": layout])
          dismiss()
        }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
      }
    }.padding(26).frame(width: 430).background(paper).foregroundStyle(ink).tint(accent)
  }
}
