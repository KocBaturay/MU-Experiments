@preconcurrency import AVFoundation
import Combine
import Foundation
import MusicUnderstanding

@MainActor
final class StreamingAnalysisStore: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Idle"
    @Published private(set) var momentary: [TimedMetric] = []
    @Published private(set) var shortTerm: [TimedMetric] = []
    @Published private(set) var integratedLUFS: Double?
    @Published private(set) var peak: TimedMetric?

    @Published var frequency: Double = 220
    @Published var amplitude: Double = 0.45
    @Published var duration: Double = 24

    private var session: MusicUnderstandingSession?
    private var listenerTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    func start() {
        stop()

        momentary = []
        shortTerm = []
        integratedLUFS = nil
        peak = nil
        isRunning = true
        status = "Streaming generated PCM"

        let provider = GeneratedPCMProvider(
            frequency: frequency,
            amplitude: amplitude,
            duration: duration
        )
        let session = MusicUnderstandingSession(audioProvider: provider)
        self.session = session

        listenerTask = Task { [weak self] in
            do {
                for try await loudness in session.loudnessResults {
                    await MainActor.run {
                        self?.append(loudness)
                    }
                }
            } catch is CancellationError {
                await MainActor.run { self?.status = "Stopped" }
            } catch {
                await MainActor.run {
                    self?.status = "Stream failed: \(error.localizedDescription)"
                    self?.isRunning = false
                }
            }
        }

        analysisTask = Task { [weak self] in
            do {
                _ = try await session.analyze(for: [.loudness])
                await MainActor.run {
                    self?.isRunning = false
                    self?.status = "Streaming complete"
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isRunning = false
                    self?.status = "Stopped"
                }
            } catch {
                await MainActor.run {
                    self?.isRunning = false
                    self?.status = "Stream failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func stop() {
        listenerTask?.cancel()
        analysisTask?.cancel()
        listenerTask = nil
        analysisTask = nil

        let activeSession = session
        session = nil
        Task {
            await activeSession?.cancel()
        }

        isRunning = false
        status = "Idle"
    }

    private func append(_ loudness: LoudnessResult) {
        integratedLUFS = Double(loudness.integrated.value)
        peak = AnalysisNormalizer.timedMetric(time: loudness.peak.time, value: loudness.peak.value)
        momentary.append(contentsOf: loudness.momentary.map {
            AnalysisNormalizer.timedMetric(time: $0.time, value: $0.value)
        })
        shortTerm.append(contentsOf: loudness.shortTerm.map {
            AnalysisNormalizer.timedMetric(time: $0.time, value: $0.value)
        })
        momentary = Array(momentary.suffix(240))
        shortTerm = Array(shortTerm.suffix(240))
    }
}

struct GeneratedPCMProvider: AsyncSequence, Sendable {
    typealias Element = AVReadOnlyAudioPCMBuffer

    var sampleRate: Double = 44_100
    var frameCount: Int = 2_048
    var frequency: Double
    var amplitude: Double
    var duration: Double

    func makeAsyncIterator() -> Iterator {
        Iterator(
            sampleRate: sampleRate,
            frameCount: frameCount,
            frequency: frequency,
            amplitude: amplitude,
            totalFrames: Int(sampleRate * duration)
        )
    }

    struct Iterator: AsyncIteratorProtocol {
        var sampleRate: Double
        var frameCount: Int
        var frequency: Double
        var amplitude: Double
        var totalFrames: Int
        var emittedFrames = 0

        mutating func next() async -> AVReadOnlyAudioPCMBuffer? {
            guard emittedFrames < totalFrames else { return nil }

            let framesToEmit = Swift.min(frameCount, totalFrames - emittedFrames)
            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 1
            ),
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(framesToEmit)
                )
            else {
                return nil
            }

            buffer.frameLength = AVAudioFrameCount(framesToEmit)
            if let channel = buffer.floatChannelData?[0] {
                for frame in 0..<framesToEmit {
                    let absoluteFrame = emittedFrames + frame
                    let time = Double(absoluteFrame) / sampleRate
                    let modulator = 0.65 + 0.35 * sin(2 * Double.pi * 0.35 * time)
                    channel[frame] = Float(sin(2 * Double.pi * frequency * time) * amplitude * modulator)
                }
            }

            emittedFrames += framesToEmit
            let nanos = UInt64((Double(framesToEmit) / sampleRate) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            return AVReadOnlyAudioPCMBuffer(copying: buffer)
        }
    }
}
