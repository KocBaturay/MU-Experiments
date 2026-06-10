@preconcurrency import AVFoundation
import Combine
import CoreMedia
import Foundation

@MainActor
final class AudioPlaybackStore: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var volume: Float = 1 {
        didSet { player.volume = volume }
    }
    @Published var loopRange: TimeRangeSummary?

    private var sampleRate: CMTimeScale = 44_100
    private var timeObserver: Any?
    private var endOfPlaybackTask: Task<Void, Never>?

    init() {
        installTimeObserver()
    }

    deinit {
        endOfPlaybackTask?.cancel()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    func load(asset: AVURLAsset, preservePlayback: Bool = false) async {
        let item = AVPlayerItem(asset: asset)
        let wasPlaying = isPlaying
        let previousTime = player.currentTime()

        player.replaceCurrentItem(with: item)
        observeEndOfPlayback(for: item)

        async let durationLoad = item.asset.load(.duration)
        async let tracksLoad = item.asset.loadTracks(withMediaType: .audio)

        if let assetDuration = try? await durationLoad, assetDuration.isNumeric {
            duration = max(0, assetDuration.seconds)
        }

        if let audioTrack = try? await tracksLoad.first,
           let formatDescription = try? await audioTrack.load(.formatDescriptions).first,
           let audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
            sampleRate = CMTimeScale(audioDescription.pointee.mSampleRate)
        }

        if preservePlayback {
            await player.seek(to: previousTime, toleranceBefore: .zero, toleranceAfter: .zero)
            if wasPlaying { play() }
        } else {
            currentTime = 0
            loopRange = nil
        }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func stop() {
        pause()
        seek(to: 0)
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: sampleRate)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = max(0, seconds)
    }

    func setLoop(_ range: TimeRangeSummary?) {
        loopRange = range
        if let range {
            seek(to: range.start)
        }
    }

    var formattedCurrentTime: String {
        AnalysisDerived.formatTime(currentTime)
    }

    var formattedDuration: String {
        AnalysisDerived.formatTime(duration)
    }

    private func observeEndOfPlayback(for item: AVPlayerItem) {
        endOfPlaybackTask?.cancel()
        endOfPlaybackTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: AVPlayerItem.didPlayToEndTimeNotification,
                object: item
            ) {
                self?.stop()
            }
        }
    }

    private func installTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: sampleRate)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self, seconds] in
                guard let self else { return }
                guard seconds.isFinite else { return }

                if let loopRange = self.loopRange, seconds >= loopRange.end {
                    self.seek(to: loopRange.start)
                    if self.isPlaying { self.play() }
                    return
                }

                self.currentTime = max(0, seconds)
                self.isPlaying = self.player.rate != 0
            }
        }
    }
}
