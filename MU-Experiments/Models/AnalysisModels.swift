import Foundation

struct AudioSourceSummary: Codable, Hashable, Identifiable {
    var id: String { urlString ?? name }
    var name: String
    var urlString: String?
    var fileExtension: String
}

struct TimeRangeSummary: Codable, Hashable, Identifiable {
    var id: String { "\(start)-\(duration)" }
    var start: Double
    var duration: Double

    var end: Double { start + duration }
}

struct TimedMetric: Codable, Hashable, Identifiable {
    var id: String { "\(time)-\(value)" }
    var time: Double
    var value: Double
}

struct RangedMetric: Codable, Hashable, Identifiable {
    var id: String { "\(range.id)-\(value)" }
    var range: TimeRangeSummary
    var value: Double
}

struct KeyRegion: Codable, Hashable, Identifiable {
    var id: String { "\(range.id)-\(tonic)-\(mode)" }
    var range: TimeRangeSummary
    var tonic: String
    var mode: String

    var displayName: String {
        AnalysisDerived.keyDisplayName(tonic: tonic, mode: mode)
    }
}

struct RhythmSummary: Codable, Hashable {
    var beats: [Double]
    var bars: [Double]
    var beatsPerMinute: Double?
    var inferredMeter: Int?

    static let empty = RhythmSummary(beats: [], bars: [], beatsPerMinute: nil, inferredMeter: nil)
}

struct StructureSummary: Codable, Hashable {
    var sections: [TimeRangeSummary]
    var phrases: [TimeRangeSummary]
    var segments: [TimeRangeSummary]

    static let empty = StructureSummary(sections: [], phrases: [], segments: [])
}

struct PaceSummary: Codable, Hashable {
    var ranges: [RangedMetric]

    static let empty = PaceSummary(ranges: [])
}

struct InstrumentLane: Codable, Hashable, Identifiable {
    var id: String { instrument }
    var instrument: String
    var displayName: String
    var activeRanges: [TimeRangeSummary]
    var activity: [TimedMetric]
}

struct LoudnessSummary: Codable, Hashable {
    var integratedLUFS: Double?
    var integratedTime: Double?
    var peak: TimedMetric?
    var momentary: [TimedMetric]
    var shortTerm: [TimedMetric]

    static let empty = LoudnessSummary(
        integratedLUFS: nil,
        integratedTime: nil,
        peak: nil,
        momentary: [],
        shortTerm: []
    )
}

struct MusicAnalysisDocument: Codable, Hashable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var source: AudioSourceSummary
    var analyzedAt: Date
    var duration: Double
    var key: [KeyRegion]
    var rhythm: RhythmSummary
    var structure: StructureSummary
    var pace: PaceSummary
    var instrumentActivity: [InstrumentLane]
    var loudness: LoudnessSummary

    var primaryKeyDisplay: String {
        key.first?.displayName ?? "No key"
    }

    var formattedDuration: String {
        AnalysisDerived.formatTime(duration)
    }

    var averagePace: Double? {
        AnalysisDerived.weightedAverage(pace.ranges)
    }

    var energyScore: Double {
        AnalysisDerived.energyScore(for: self)
    }
}

struct RecentAnalysisRecord: Codable, Hashable, Identifiable {
    var id: UUID
    var document: MusicAnalysisDocument
    var filePath: String?
    var bookmarkData: Data?

    var analyzedAt: Date { document.analyzedAt }
    var title: String { document.source.name }
}

struct PendingAnalysisRecord: Equatable, Identifiable {
    var id: UUID
    var title: String
    var status: String
    var filePath: String?
    var startedAt: Date
}

struct DatasetProgress: Equatable {
    var current: Int
    var total: Int
    var currentFileName: String
}

struct DJTransitionCandidate: Identifiable, Hashable {
    var id: String { "\(source.id)-\(target.id)" }
    var source: MusicAnalysisDocument
    var target: MusicAnalysisDocument
    var score: Double
    var bpmDelta: Double?
    var keyNote: String
    var energyDelta: Double
}

enum AnalysisDerived {
    static func safeSeconds(_ value: Double) -> Double {
        value.isFinite && value >= 0 ? value : 0
    }

    static func formatTime(_ seconds: Double) -> String {
        let safeSeconds = Int(max(0, seconds).rounded())
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let seconds = safeSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    static func keyDisplayName(tonic: String, mode: String) -> String {
        "\(tonicDisplayName(tonic)) \(modeDisplayName(mode))"
    }

    static func tonicDisplayName(_ rawValue: String) -> String {
        switch rawValue {
        case "aFlat": "Ab"
        case "aSharp": "A#"
        case "a": "A"
        case "bFlat": "Bb"
        case "b": "B"
        case "c": "C"
        case "cSharp": "C#"
        case "d": "D"
        case "dFlat": "Db"
        case "dSharp": "D#"
        case "eFlat": "Eb"
        case "e": "E"
        case "f": "F"
        case "fSharp": "F#"
        case "g": "G"
        case "gFlat": "Gb"
        case "gSharp": "G#"
        default: rawValue
            .replacingOccurrences(of: "Sharp", with: "#")
            .replacingOccurrences(of: "Flat", with: "b")
            .capitalized
        }
    }

    static func modeDisplayName(_ rawValue: String) -> String {
        rawValue.capitalized
    }

    static func inferMeter(beats: [Double], bars: [Double]) -> Int? {
        guard bars.count >= 2, beats.count >= 2 else { return nil }

        let counts = zip(bars, bars.dropFirst()).map { start, end in
            beats.filter { $0 >= start && $0 < end }.count
        }
        let usableCounts = counts.filter { $0 > 0 }.sorted()
        guard let median = usableCounts[safe: usableCounts.count / 2] else { return nil }

        return (2...12).contains(median) ? median : nil
    }

    static func barIndex(at time: Double, bars: [Double]) -> Int? {
        bars.lastIndex(where: { $0 <= time })
    }

    static func beatNumber(at time: Double, beats: [Double], bars: [Double]) -> Int? {
        guard let barIndex = barIndex(at: time, bars: bars) else { return nil }
        let barStart = bars[barIndex]
        let nextBar = bars[safe: barIndex + 1] ?? .greatestFiniteMagnitude
        let beatsInBar = beats.filter { $0 >= barStart && $0 < nextBar }
        guard !beatsInBar.isEmpty else { return nil }

        let elapsedBeats = beatsInBar.filter { $0 <= time }.count
        return max(1, elapsedBeats)
    }

    static func sectionDurations(_ sections: [TimeRangeSummary]) -> [Double] {
        sections.map(\.duration)
    }

    static func weightedAverage(_ ranges: [RangedMetric]) -> Double? {
        let totalDuration = ranges.reduce(0) { $0 + max(0, $1.range.duration) }
        guard totalDuration > 0 else { return nil }

        return ranges.reduce(0) { partial, metric in
            partial + metric.value * max(0, metric.range.duration)
        } / totalDuration
    }

    static func activeShare(for lane: InstrumentLane, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        let activeDuration = lane.activeRanges.reduce(0) { $0 + max(0, $1.duration) }
        return min(1, max(0, activeDuration / duration))
    }

    static func energyScore(for document: MusicAnalysisDocument) -> Double {
        let pace = min(1, (document.averagePace ?? 0) / 12)
        let loudness = document.loudness.integratedLUFS.map { min(1, max(0, ($0 + 36) / 28)) } ?? 0.45
        let instrument = document.instrumentActivity.isEmpty ? 0 : document.instrumentActivity.reduce(0) {
            $0 + activeShare(for: $1, duration: document.duration)
        } / Double(document.instrumentActivity.count)

        return (pace * 0.35) + (loudness * 0.35) + (instrument * 0.30)
    }

    static func transitionCandidates(from documents: [MusicAnalysisDocument]) -> [DJTransitionCandidate] {
        guard documents.count >= 2 else { return [] }

        var candidates: [DJTransitionCandidate] = []

        for source in documents {
            for target in documents where source.id != target.id {
                let bpmDelta = bpmDeltaPercent(source.rhythm.beatsPerMinute, target.rhythm.beatsPerMinute)
                let bpmScore = bpmDelta.map { max(0, 1 - ($0 / 8)) } ?? 0.35
                let key = keyCompatibility(source: source, target: target)
                let energyDelta = abs(source.energyScore - target.energyScore)
                let energyScore = max(0, 1 - (energyDelta / 0.35))
                let score = (bpmScore * 0.40) + (key.score * 0.35) + (energyScore * 0.25)

                candidates.append(DJTransitionCandidate(
                    source: source,
                    target: target,
                    score: score,
                    bpmDelta: bpmDelta,
                    keyNote: key.note,
                    energyDelta: energyDelta
                ))
            }
        }

        return candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.source.source.name < rhs.source.source.name
            }
            return lhs.score > rhs.score
        }
    }

    private static func bpmDeltaPercent(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs, lhs > 0, rhs > 0 else { return nil }
        return abs(lhs - rhs) / min(lhs, rhs) * 100
    }

    private static func keyCompatibility(
        source: MusicAnalysisDocument,
        target: MusicAnalysisDocument
    ) -> (score: Double, note: String) {
        guard let sourceKey = source.key.first, let targetKey = target.key.first else {
            return (0.35, "missing key")
        }

        if sourceKey.tonic == targetKey.tonic && sourceKey.mode == targetKey.mode {
            return (1, "same key")
        }

        if sourceKey.tonic == targetKey.tonic {
            return (0.78, "parallel key")
        }

        if sourceKey.mode == targetKey.mode {
            return (0.58, "same mode")
        }

        return (0.25, "distant key")
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
