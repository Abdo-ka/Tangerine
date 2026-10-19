import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFPageChoice: Identifiable {
  let id: UUID
  let page: Int
  var rotation: Int
  init(page: Int, rotation: Int = 0) {
    self.id = UUID()
    self.page = page
    self.rotation = rotation
  }
}

struct PDFOrganizer: View {
  let url: URL
  @Binding var pages: [PDFPageChoice]
  @State private var dragging: UUID?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
        ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
          VStack(spacing: 7) {
            PDFPageThumbnail(url: url, index: item.page - 1, rotation: item.rotation)
              .frame(height: 125).background(surface, in: RoundedRectangle(cornerRadius: 6))
              .overlay(RoundedRectangle(cornerRadius: 6).stroke(.primary.opacity(0.12)))
              .onDrag {
                dragging = item.id
                return NSItemProvider(object: item.id.uuidString as NSString)
              }
              .onDrop(
                of: [UTType.text],
                delegate: PageReorderDrop(
                  target: item.id, pages: $pages, dragging: $dragging, reduceMotion: reduceMotion))
            HStack {
              Text("Page \(item.page)").font(.caption)
              Spacer()
              Text("\(index+1)").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
              Button {
                if index > 0 { pages.swapAt(index, index - 1) }
              } label: {
                Image(systemName: "arrow.left")
              }.disabled(index == 0).help("Move earlier")
              Button {
                pages[index].rotation = (pages[index].rotation + 90) % 360
              } label: {
                Image(systemName: "rotate.right")
              }.help("Rotate page")
              Button {
                pages.insert(PDFPageChoice(page: item.page, rotation: item.rotation), at: index + 1)
              } label: {
                Image(systemName: "plus.square.on.square")
              }.help("Duplicate page")
              Button {
                pages.remove(at: index)
              } label: {
                Image(systemName: "minus.circle")
              }.disabled(pages.count == 1).help("Remove page")
            }.font(.system(size: 11)).buttonStyle(.borderless)
          }.accessibilityElement(children: .contain).accessibilityLabel(
            "Output page \(index+1), original page \(item.page), rotation \(item.rotation) degrees")
        }
      }.padding(4)
    }
  }
}
struct PDFPageThumbnail: View {
  let url: URL
  let index: Int
  let rotation: Int
  @State private var thumbnail: NSImage?
  var body: some View {
    Group {
      if let thumbnail {
        Image(nsImage: thumbnail).resizable().scaledToFit().rotationEffect(
          .degrees(Double(rotation)))
      } else {
        ProgressView().controlSize(.small)
      }
    }
    .padding(5).task {
      let source = url
      let page = index
      thumbnail = await Task.detached {
        PDFDocument(url: source)?.page(at: page)?.thumbnail(
          of: NSSize(width: 140, height: 160), for: .mediaBox)
      }.value
    }
  }
}
struct PageReorderDrop: DropDelegate {
  let target: UUID
  @Binding var pages: [PDFPageChoice]
  @Binding var dragging: UUID?
  let reduceMotion: Bool
  func validateDrop(info: DropInfo) -> Bool { dragging != nil }
  func dropEntered(info: DropInfo) {
    guard let dragging, dragging != target,
      let from = pages.firstIndex(where: { $0.id == dragging }),
      let to = pages.firstIndex(where: { $0.id == target })
    else { return }
    withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.3, dampingFraction: 1)) {
      pages.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }
  }
  func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
  func performDrop(info: DropInfo) -> Bool {
    dragging = nil
    return true
  }
}
