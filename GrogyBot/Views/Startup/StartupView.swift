import SwiftUI
import AVFoundation

// MARK: - Startup Screen

struct StartupView: View {
    @Environment(LanguageManager.self) var lang
    @Binding var showStartup: Bool
    @Binding var selectedTab: Int

    @State private var player: AVPlayer?
    @State private var buttonsVisible = false
    @State private var textVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // ── Video ──────────────────────────────────────
                if let player {
                    VideoPlayerView(player: player)
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }

                // ── Greeting text ──────────────────────────────
                Text(lang.startupGreeting)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : 12)

                Spacer().frame(height: 8)

                // ── Two eye-buttons ────────────────────────────
                HStack(spacing: 48) {
                    StartupButton(
                        title: lang.startupAskNow,
                        systemImage: "bubble.left.fill"
                    ) {
                        navigateTo(tab: 4)
                    }

                    StartupButton(
                        title: lang.startupDashboard,
                        systemImage: "house.fill"
                    ) {
                        navigateTo(tab: 0)
                    }
                }
                .opacity(buttonsVisible ? 1 : 0)
                .offset(y: buttonsVisible ? 0 : 20)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                textVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                buttonsVisible = true
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Helpers

    private func setupPlayer() {
        // Try uppercase (original filename) then lowercase extension
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "MP4")
                     ?? Bundle.main.url(forResource: "Intro", withExtension: "mp4") else {
            showStartup = false          // skip if video missing
            return
        }
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = true
        self.player = avPlayer
        avPlayer.play()
    }

    private func navigateTo(tab: Int) {
        selectedTab = tab
        withAnimation(.easeInOut(duration: 0.4)) {
            showStartup = false
        }
    }
}

// MARK: - Eye-styled Button

private struct StartupButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Theme.cyan.opacity(0.15))
                        .frame(width: 80, height: 80)

                    // Inner solid eye
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.cyan, Theme.cyan.opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.cyan.opacity(0.6), radius: 12)

                    // Icon (pupil)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.black)
                }

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.cyan)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Zero-chrome video player (AVPlayerLayer)

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
