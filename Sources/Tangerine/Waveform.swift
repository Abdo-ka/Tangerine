import AVFoundation
import SwiftUI

/// Bounded-memory PCM sampling. Files stay on disk; only 240 peak values are kept.
enum AudioAnalysis {
  static func peaks(_ url: URL) async throws -> [Double] {
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration).seconds
    guard duration.isFinite, duration > 0,
      let track = try await asset.loadTracks(withMediaType: .audio).first
    else { return [] }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true,
        AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false,
      ])
    reader.add(output)
    guard reader.startReading() else {
      throw reader.error ?? AppError("Cannot decode this recording.")
    }
    var bins = [Double](repeating: 0, count: 240)
    while let sample = output.copyNextSampleBuffer() {
      if Task.isCancelled {
        reader.cancelReading()
        throw CancellationError()
      }
      guard let buffer = CMSampleBufferGetDataBuffer(sample),
        let description = CMSampleBufferGetFormatDescription(sample),
        let format = CMAudioFormatDescriptionGetStreamBasicDescription(description)
      else { continue }
      let length = CMBlockBufferGetDataLength(buffer)
      var samples = [Float](repeating: 0, count: length / 4)
      let status = samples.withUnsafeMutableBytes {
        CMBlockBufferCopyDataBytes(
          buffer, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
      }
      guard status == kCMBlockBufferNoErr else { continue }
      let channels = max(1, Int(format.pointee.mChannelsPerFrame))
      let rate = format.pointee.mSampleRate
      let start = CMSampleBufferGetPresentationTimeStamp(sample).seconds
      for index in stride(from: 0, to: samples.count, by: channels) {
        let time = start + Double(index / channels) / rate
        let bin = min(bins.count - 1, max(0, Int(time / duration * Double(bins.count))))
        bins[bin] = max(bins[bin], Double(abs(samples[index])))
      }
    }
    if reader.status == .failed { throw reader.error ?? AppError("Audio decoding failed.") }
    let maxPeak = bins.max() ?? 1
    return bins.map { pow($0 / max(maxPeak, 0.001), 0.6) }
  }
}

struct WaveformEditor: View {
  let peaks: [Double]
  let duration: Double
  @Binding var start: Double
  @Binding var end: Double
  @Binding var playhead: Double
  var seek: () -> Void
  var editable = true
  private var effectiveEnd: Double { end > 0 ? min(end, duration) : duration }
  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      let left = width * start / max(duration, 0.001)
      let right = width * effectiveEnd / max(duration, 0.001)
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 9).fill(surface)
        Canvas { context, size in
          for (i, value) in peaks.enumerated() {
            let x: CGFloat = CGFloat(i) / CGFloat(max(1, peaks.count)) * size.width
            let barHeight: CGFloat = max(2, CGFloat(value) * (size.height - 20))
            let barWidth: CGFloat = max(1, size.width / CGFloat(max(1, peaks.count)) - 1)
            let rect = CGRect(
              x: x, y: (size.height - barHeight) / 2,
              width: barWidth, height: barHeight)
            context.fill(
              Path(roundedRect: rect, cornerRadius: 1),
              with: .color(x >= left && x <= right ? accent : Color.secondary.opacity(0.3)))
          }
        }.padding(.horizontal, 2)
        Rectangle().fill(accent.opacity(0.08)).frame(width: max(1, right - left), height: height)
          .offset(x: left)
        Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 1, height: height).offset(
          x: width * playhead / max(duration, 0.001)
        ).allowsHitTesting(false)
        if editable {
          handle("Start", x: left, height: height).gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("waveform")).onChanged {
              value in
              start = min(max(0, value.location.x / width * duration), max(0, effectiveEnd - 0.02))
              playhead = start
              seek()
            })
          handle("End", x: right, height: height).gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("waveform")).onChanged {
              value in
              end = max(min(duration, value.location.x / width * duration), start + 0.02)
              playhead = end
              seek()
            })
        }
      }.coordinateSpace(name: "waveform").clipShape(RoundedRectangle(cornerRadius: 9))
    }.frame(height: 95).accessibilityElement(children: .contain).accessibilityLabel(
      "Audio waveform. Adjust range with the start and end fields or drag the handles.")
  }
  private func handle(_ label: String, x: Double, height: Double) -> some View {
    ZStack {
      Rectangle().fill(.clear).frame(width: 24, height: height)
      Capsule().fill(accent).frame(width: 3, height: height - 12)
    }.contentShape(Rectangle()).offset(x: x - 12).accessibilityLabel(label + " handle")
  }
}
