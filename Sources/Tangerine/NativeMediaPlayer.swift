import AVKit
import AppKit
import SwiftUI

/// Use AppKit directly instead of the SwiftUI AVKit bridge. This also gives
/// desktop users standard playback controls and avoids bridge metadata failures.
struct NativeMediaPlayer: NSViewRepresentable {
  let player: AVPlayer
  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.controlsStyle = .inline
    view.videoGravity = .resizeAspect
    view.player = player
    return view
  }
  func updateNSView(_ view: AVPlayerView, context: Context) {
    if view.player !== player { view.player = player }
  }
  static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
    view.player = nil
  }
}
