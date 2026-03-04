import SwiftUI
import AVFoundation

struct PlayingVisualizerView: View {
    var body: some View {
        ZStack {
            // This container defines the shape and bounds
            LoopingVideoPlayer(videoName: "playing-visualizer-3")
                .grayscale(1.0)
                .scaleEffect(1.2) // Enlarged to fill container
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    func makeUIView(context: Context) -> UIView {
        return LoopingVideoPlayerUIView(videoName: videoName)
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class LoopingVideoPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    init(videoName: String) {
        super.init(frame: .zero)
        let bundle: Bundle = {
#if SWIFT_PACKAGE
            return Bundle.module
#else
            return Bundle.main
#endif
        }()
        guard let fileURL = bundle.url(forResource: videoName, withExtension: "mov") ??
                bundle.url(forResource: videoName, withExtension: "mov", subdirectory: "Resources") ??
                bundle.url(forResource: videoName, withExtension: "mp4") ??
                bundle.url(forResource: videoName, withExtension: "mp4", subdirectory: "Resources") else {
            return
        }
        let asset = AVAsset(url: fileURL)
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        self.queuePlayer = player
        self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        player.play()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
