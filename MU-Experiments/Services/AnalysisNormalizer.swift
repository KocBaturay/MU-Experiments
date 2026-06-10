import CoreMedia
import Foundation
import MusicUnderstanding

enum AnalysisNormalizer {
    static func document(
        from result: MusicUnderstandingSession.SessionResult,
        sourceURL: URL,
        duration: Double
    ) -> MusicAnalysisDocument {
        let rhythm = rhythmSummary(from: result.rhythm)

        return MusicAnalysisDocument(
            id: UUID(),
            schemaVersion: 1,
            source: AudioSourceSummary(
                name: sourceURL.deletingPathExtension().lastPathComponent,
                urlString: sourceURL.absoluteString,
                fileExtension: sourceURL.pathExtension
            ),
            analyzedAt: Date(),
            duration: AnalysisDerived.safeSeconds(duration),
            key: keyRegions(from: result.key),
            rhythm: rhythm,
            structure: structureSummary(from: result.structure),
            pace: paceSummary(from: result.pace),
            instrumentActivity: instrumentLanes(from: result.instrumentActivity),
            loudness: loudnessSummary(from: result.loudness)
        )
    }

    static func timeRange(_ range: CMTimeRange) -> TimeRangeSummary {
        TimeRangeSummary(
            start: safeSeconds(range.start),
            duration: safeSeconds(range.duration)
        )
    }

    static func timedMetric<Value: BinaryFloatingPoint>(
        time: CMTime,
        value: Value
    ) -> TimedMetric {
        TimedMetric(time: safeSeconds(time), value: Double(value))
    }

    private static func keyRegions(from key: KeyResult?) -> [KeyRegion] {
        key?.ranges.map { region in
            KeyRegion(
                range: timeRange(region.range),
                tonic: region.value.tonic.rawValue,
                mode: region.value.mode.rawValue
            )
        } ?? []
    }

    private static func rhythmSummary(from rhythm: RhythmResult?) -> RhythmSummary {
        guard let rhythm else { return .empty }
        let beats = rhythm.beats.map(safeSeconds)
        let bars = rhythm.bars.map(safeSeconds)

        return RhythmSummary(
            beats: beats,
            bars: bars,
            beatsPerMinute: rhythm.beatsPerMinute.map(Double.init),
            inferredMeter: AnalysisDerived.inferMeter(beats: beats, bars: bars)
        )
    }

    private static func structureSummary(from structure: StructureResult?) -> StructureSummary {
        guard let structure else { return .empty }

        return StructureSummary(
            sections: structure.sections.map(timeRange),
            phrases: structure.phrases.map(timeRange),
            segments: structure.segments.map(timeRange)
        )
    }

    private static func paceSummary(from pace: PaceResult?) -> PaceSummary {
        PaceSummary(
            ranges: pace?.ranges.map {
                RangedMetric(range: timeRange($0.range), value: $0.value)
            } ?? []
        )
    }

    private static func instrumentLanes(from result: InstrumentActivityResult?) -> [InstrumentLane] {
        let preferred: [InstrumentActivityResult.Instrument] = [.vocal, .drum, .bass, .other]
        var discovered = Set<InstrumentActivityResult.Instrument>()
        if let result {
            discovered.formUnion(result.ranges.keys)
            discovered.formUnion(result.activity.keys)
        }
        let ordered = preferred + discovered.filter { !preferred.contains($0) }.sorted { $0.rawValue < $1.rawValue }

        return ordered.map { instrument in
            InstrumentLane(
                instrument: instrument.rawValue,
                displayName: instrument.rawValue.capitalized,
                activeRanges: result?.ranges[instrument]?.map(timeRange) ?? [],
                activity: result?.activity[instrument]?.map {
                    timedMetric(time: $0.time, value: $0.value)
                } ?? []
            )
        }
    }

    private static func loudnessSummary(from loudness: LoudnessResult?) -> LoudnessSummary {
        guard let loudness else { return .empty }

        return LoudnessSummary(
            integratedLUFS: Double(loudness.integrated.value),
            integratedTime: safeSeconds(loudness.integrated.time),
            peak: timedMetric(time: loudness.peak.time, value: loudness.peak.value),
            momentary: loudness.momentary.map { timedMetric(time: $0.time, value: $0.value) },
            shortTerm: loudness.shortTerm.map { timedMetric(time: $0.time, value: $0.value) }
        )
    }

    private static func safeSeconds(_ time: CMTime) -> Double {
        guard time.isNumeric else { return 0 }
        return AnalysisDerived.safeSeconds(time.seconds)
    }
}
