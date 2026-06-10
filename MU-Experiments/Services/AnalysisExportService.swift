import Foundation

struct AnalysisExportBundle: Identifiable, Hashable {
    var id = UUID()
    var jsonURL: URL
    var summaryURL: URL

    var urls: [URL] { [jsonURL, summaryURL] }
}

enum AnalysisExportService {
    static func writeExports(for document: MusicAnalysisDocument) throws -> AnalysisExportBundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicUnderstandingExperiments")
            .appendingPathComponent(document.id.uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let baseName = safeFileName(document.source.name)
        let jsonURL = directory.appendingPathComponent("\(baseName)-analysis.json")
        let summaryURL = directory.appendingPathComponent("\(baseName)-summary.txt")

        try jsonData(for: document).write(to: jsonURL, options: .atomic)
        try summary(for: document).write(to: summaryURL, atomically: true, encoding: .utf8)

        return AnalysisExportBundle(jsonURL: jsonURL, summaryURL: summaryURL)
    }

    static func writeDatasetExport(for documents: [MusicAnalysisDocument]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MusicUnderstandingExperiments")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("dataset-analysis.json")
        try jsonData(for: documents).write(to: url, options: .atomic)
        return url
    }

    static func jsonData<T: Encodable>(for value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try encoder.encode(value)
    }

    static func summary(for document: MusicAnalysisDocument) -> String {
        let bpm = document.rhythm.beatsPerMinute.map { String(format: "%.1f BPM", $0) } ?? "No BPM"
        let meter = document.rhythm.inferredMeter.map { "\($0)/4 inferred" } ?? "meter unknown"
        let integrated = document.loudness.integratedLUFS.map { String(format: "%.1f LUFS", $0) } ?? "LUFS unknown"
        let peak = document.loudness.peak.map { String(format: "%.1f peak", $0.value) } ?? "peak unknown"
        let averagePace = document.averagePace.map { String(format: "%.2f events/s", $0) } ?? "pace unknown"
        let energy = String(format: "%.0f%%", document.energyScore * 100)

        let keyChanges = document.key.isEmpty
            ? "No key regions detected."
            : document.key.map {
                "\(AnalysisDerived.formatTime($0.range.start)) - \(AnalysisDerived.formatTime($0.range.end)): \($0.displayName)"
            }.joined(separator: "\n")

        let sections = document.structure.sections.enumerated().map { index, section in
            "Section \(index + 1): \(AnalysisDerived.formatTime(section.start)) - \(AnalysisDerived.formatTime(section.end)) (\(AnalysisDerived.formatTime(section.duration)))"
        }.joined(separator: "\n")

        let instruments = document.instrumentActivity.map { lane in
            let share = AnalysisDerived.activeShare(for: lane, duration: document.duration) * 100
            return "\(lane.displayName): \(String(format: "%.0f%%", share)) active, \(lane.activity.count) samples"
        }.joined(separator: "\n")

        return """
        MusicUnderstandingExperiments Analysis
        Source: \(document.source.name)
        Analyzed: \(document.analyzedAt.formatted(date: .abbreviated, time: .shortened))
        Duration: \(document.formattedDuration)

        Overview
        Key: \(document.primaryKeyDisplay)
        Rhythm: \(bpm), \(meter), \(document.rhythm.beats.count) beats, \(document.rhythm.bars.count) bars
        Structure: \(document.structure.sections.count) sections, \(document.structure.phrases.count) phrases, \(document.structure.segments.count) segments
        Pace: \(averagePace)
        Loudness: \(integrated), \(peak)
        Energy score: \(energy)

        Key Timeline
        \(keyChanges)

        Sections
        \(sections.isEmpty ? "No sections detected." : sections)

        Instrument Activity
        \(instruments.isEmpty ? "No instrument activity detected." : instruments)
        """
    }

    private static func safeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(scalars).replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-")).isEmpty ? "analysis" : collapsed
    }
}
