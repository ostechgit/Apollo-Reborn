import UIKit
import AsyncDisplayKit
import AVFoundation

// CommentVideoNode - an animated picture embedded in a comment body.
//
// Reddit exposes the same media twice: a still (`s.u`) and an MP4 (`s.mp4`).
// The still is kept as the poster while the MP4 loops in place, which is what
// the original does for a comment giphy rather than drawing a static frame.
// The layer is muted and loops without controls; tapping still opens the
// viewer, so the node never swallows the row's own gestures.
final class CommentVideoNode: ASDisplayNode {

    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper
    private let playerLayer = AVPlayerLayer()

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        self.player = queue
        self.looper = AVPlayerLooper(player: queue, templateItem: item)
        super.init()

        self.backgroundColor = .secondarySystemBackground
        self.cornerRadius = 10
        self.clipsToBounds = true
        self.isUserInteractionEnabled = true

        self.player.isMuted = true
        self.player.actionAtItemEnd = .none
        // Keeps inline animations from ducking other audio; the original's
        // inline giphys are silent too.
        self.player.volume = 0
        self.playerLayer.player = self.player
        self.playerLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(self.playerLayer)
    }

    deinit {
        self.player.pause()
    }

    override func didEnterVisibleState() {
        super.didEnterVisibleState()
        self.player.play()
    }

    override func didExitVisibleState() {
        super.didExitVisibleState()
        // Off-screen comments must not keep decoding frames.
        self.player.pause()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.playerLayer.frame = self.bounds
        CATransaction.commit()
    }
}
