import SwiftUI
import AVFoundation

/// Full-screen overlay that plays a celebration video when a tool action completes.
/// Structured so each `ActionType` can map to its own video file in the future.
struct ToolActionAnimationView: View {
    @Binding var actionType: ChatMessage.ToolAction.ActionType?
    @State private var player: AVPlayer?

    var body: some View {
        if let type = actionType {
            ZStack {
                // Semi-transparent backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                // Video player
                if let player {
                    VideoPlayerView(player: player)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .onTapGesture {
                dismiss()
            }
            .onAppear {
                setupAndPlay(for: type)
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Video Mapping

    /// Maps each action type to a video filename (without extension).
    /// Change individual cases here when adding per-type videos.
    private func videoFilename(for type: ChatMessage.ToolAction.ActionType) -> String {
        switch type {
        case .reminderCreated: return "creating"
        case .noteCreated:     return "creating"
        case .habitCreated:    return "creating"
        }
    }

    // MARK: - Playback

    private func setupAndPlay(for type: ChatMessage.ToolAction.ActionType) {
        let name = videoFilename(for: type)
        guard let url = Bundle.main.url(forResource: name, withExtension: "mov")
                      ?? Bundle.main.url(forResource: name, withExtension: "MOV") else {
            // Video missing — just dismiss
            dismiss()
            return
        }

        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = true
        self.player = avPlayer

        // Auto-dismiss when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            dismiss()
        }

        avPlayer.play()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            actionType = nil
        }
        cleanup()
    }

    private func cleanup() {
        player?.pause()
        player = nil
    }
}
