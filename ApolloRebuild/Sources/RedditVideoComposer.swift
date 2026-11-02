import AVFoundation
import AVKit
import Foundation
import UIKit

// RedditVideoComposer - plays a v.redd.it video with its audio.
//
// Reddit serves hosted video as separate DASH renditions: the fallback MP4 is
// video-only, and the sound lives in a sibling `DASH_AUDIO_128.mp4` (older posts
// spell it `DASH_Audio_128.mp4`). Apollo merges the two, which is why its videos
// have sound while a plain AVPlayer on the fallback URL is silent. This builds the
// same composition with AVMutableComposition, falling back to the silent video if
// the audio rendition is missing.
enum RedditVideoComposer {

    /// Candidate audio renditions for a fallback URL, newest spelling first.
    static func audioURLs(for videoURL: URL) -> [URL] {
        let directory = videoURL.deletingLastPathComponent()
        return ["DASH_AUDIO_128.mp4", "DASH_Audio_128.mp4"].compactMap { name in
            URL(string: name, relativeTo: directory)?.absoluteURL
        }
    }

    /// Builds a playable item. Calls back on the main queue.
    static func makeItem(videoURL: URL, completion: @escaping (AVPlayerItem) -> Void) {
        let videoAsset = AVURLAsset(url: videoURL)
        let candidates = audioURLs(for: videoURL)

        Task {
            // Nothing to merge if the video itself has an audio track.
            if let tracks = try? await videoAsset.loadTracks(withMediaType: .audio), !tracks.isEmpty {
                await MainActor.run { completion(AVPlayerItem(asset: videoAsset)) }
                return
            }

            for audioURL in candidates {
                let audioAsset = AVURLAsset(url: audioURL)
                guard let audioTracks = try? await audioAsset.loadTracks(withMediaType: .audio),
                      let audioTrack = audioTracks.first,
                      let videoTracks = try? await videoAsset.loadTracks(withMediaType: .video),
                      let videoTrack = videoTracks.first else { continue }

                let composition = AVMutableComposition()
                guard let compositionVideo = composition.addMutableTrack(
                        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let compositionAudio = composition.addMutableTrack(
                        withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }

                let videoDuration = try? await videoAsset.load(.duration)
                let audioDuration = try? await audioAsset.load(.duration)
                let range = CMTimeRange(start: .zero,
                                        duration: CMTimeMinimum(videoDuration ?? .zero, audioDuration ?? .zero))

                do {
                    try compositionVideo.insertTimeRange(
                        CMTimeRange(start: .zero, duration: videoDuration ?? .zero),
                        of: videoTrack, at: .zero)
                    // Reddit's audio rendition can run a hair longer than the
                    // video; clamp so the composition stays valid.
                    try compositionAudio.insertTimeRange(range, of: audioTrack, at: .zero)
                    let item = AVPlayerItem(asset: composition)
                    await MainActor.run { completion(item) }
                    return
                } catch {
                    continue
                }
            }

            // No usable audio rendition: play the silent fallback rather than
            // failing the tap.
            await MainActor.run { completion(AVPlayerItem(asset: videoAsset)) }
        }
    }

    /// Convenience for the two screens that present a video.
    static func present(from viewController: UIViewController, link: RDKLink,
                        fallbackURL: URL) {
        let player = AVPlayerViewController()
        viewController.present(player, animated: true) {
            player.player?.play()
        }
        Task {
            let item = await withCheckedContinuation { (continuation: CheckedContinuation<AVPlayerItem, Never>) in
                makeItem(videoURL: fallbackURL) { continuation.resume(returning: $0) }
            }
            await MainActor.run {
                player.player = AVPlayer(playerItem: item)
                player.player?.play()
            }
        }
    }
}
