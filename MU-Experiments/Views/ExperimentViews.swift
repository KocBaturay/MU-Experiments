import Charts
import SwiftUI
import UniformTypeIdentifiers

struct BatchCompareView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BatchSnapshotPanel(documents: analysisStore.comparisonDocuments)

                LabPanel("Song Comparison", systemImage: "tablecells") {
                    if analysisStore.comparisonDocuments.isEmpty {
                        EmptyPanelState(title: "No analyzed songs.")
                    } else {
                        if isCompact {
                            VStack(spacing: 10) {
                                ForEach(analysisStore.comparisonDocuments) { document in
                                    CompactComparisonCard(document: document)
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                ComparisonHeader()
                                Divider()
                                ForEach(analysisStore.comparisonDocuments) { document in
                                    ComparisonRow(document: document)
                                    if document.id != analysisStore.comparisonDocuments.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }

                BatchCharts(documents: analysisStore.comparisonDocuments)
            }
            .padding()
            .frame(maxWidth: 1180, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
    }
}

private struct CompactComparisonCard: View {
    var document: MusicAnalysisDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(document.source.name)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                CompactMetric(label: "BPM", value: document.rhythm.beatsPerMinute.map { String(format: "%.1f", $0) } ?? "-")
                CompactMetric(label: "Key", value: document.primaryKeyDisplay)
                CompactMetric(label: "LUFS", value: document.loudness.integratedLUFS.map { String(format: "%.1f", $0) } ?? "-")
                CompactMetric(label: "Density", value: document.averagePace.map { String(format: "%.2f", $0) } ?? "-")
                CompactMetric(label: "Energy", value: String(format: "%.0f%%", document.energyScore * 100))
                CompactMetric(label: "Length", value: document.formattedDuration)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(LabPalette.panelStroke)
                }
        }
    }
}

private struct CompactMetric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ComparisonHeader: View {
    var body: some View {
        HStack {
            Text("Song").frame(maxWidth: .infinity, alignment: .leading)
            Text("BPM").frame(width: 72, alignment: .trailing)
            Text("Key").frame(width: 96, alignment: .trailing)
            Text("LUFS").frame(width: 72, alignment: .trailing)
            Text("Density").frame(width: 88, alignment: .trailing)
            Text("Energy").frame(width: 78, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }
}

private struct ComparisonRow: View {
    var document: MusicAnalysisDocument

    var body: some View {
        HStack {
            Text(document.source.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(document.rhythm.beatsPerMinute.map { String(format: "%.1f", $0) } ?? "-")
                .font(.callout.monospacedDigit())
                .frame(width: 72, alignment: .trailing)
            Text(document.primaryKeyDisplay)
                .frame(width: 96, alignment: .trailing)
            Text(document.loudness.integratedLUFS.map { String(format: "%.1f", $0) } ?? "-")
                .font(.callout.monospacedDigit())
                .frame(width: 72, alignment: .trailing)
            Text(document.averagePace.map { String(format: "%.2f", $0) } ?? "-")
                .font(.callout.monospacedDigit())
                .frame(width: 88, alignment: .trailing)
            Text(String(format: "%.0f%%", document.energyScore * 100))
                .font(.callout.monospacedDigit())
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

private struct BatchCharts: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var documents: [MusicAnalysisDocument]

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        LabPanel("Distributions", systemImage: "chart.xyaxis.line") {
            if documents.isEmpty {
                EmptyPanelState(title: "No comparison data.")
            } else {
                Chart(documents) { document in
                    PointMark(
                        x: .value("BPM", document.rhythm.beatsPerMinute ?? 0),
                        y: .value("Energy", document.energyScore * 100)
                    )
                    .foregroundStyle(LabPalette.accent)
                    .annotation(position: .top, alignment: .center) {
                        if !isCompact {
                            Text(document.source.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(maxWidth: 90)
                        }
                    }
                }
                .chartXAxisLabel(isCompact ? "" : "BPM")
                .chartYAxisLabel(isCompact ? "" : "Energy")
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: isCompact ? 220 : 260)
            }
        }
    }
}

struct DJTransitionFinderView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore

    private var candidates: [DJTransitionCandidate] {
        Array(AnalysisDerived.transitionCandidates(from: analysisStore.comparisonDocuments).prefix(16))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LabPanel("Transition Candidates", systemImage: "slider.horizontal.3") {
                    if candidates.isEmpty {
                        EmptyPanelState(title: "Analyze at least two songs.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(candidates) { candidate in
                                TransitionCandidateRow(candidate: candidate)
                                if candidate.id != candidates.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
    }
}

private struct TransitionCandidateRow: View {
    var candidate: DJTransitionCandidate

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.source.source.name)
                    .lineLimit(1)
                Text(candidate.source.primaryKeyDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .foregroundStyle(LabPalette.accent)

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.target.source.name)
                    .lineLimit(1)
                Text(candidate.target.primaryKeyDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                Text(String(format: "%.0f%%", candidate.score * 100))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text(candidate.bpmDelta.map { String(format: "%.1f%% BPM", $0) } ?? "BPM unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(candidate.keyNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

struct PracticeCompanionView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let document = analysisStore.currentDocument {
                    LabPanel("Beat And Bar Looping", systemImage: "repeat") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            MetricChip(title: "Current Time", value: playbackStore.formattedCurrentTime, tint: LabPalette.blue)
                            MetricChip(
                                title: "Current Bar",
                                value: AnalysisDerived.barIndex(at: playbackStore.currentTime, bars: document.rhythm.bars).map { "\($0 + 1)" } ?? "-",
                                tint: LabPalette.accent
                            )
                            MetricChip(
                                title: "Current Beat",
                                value: AnalysisDerived.beatNumber(at: playbackStore.currentTime, beats: document.rhythm.beats, bars: document.rhythm.bars).map { "\($0)" } ?? "-",
                                tint: LabPalette.amber
                            )
                        }

                        SectionLoopGrid(document: document)
                    }

                    CountInMarkersView(document: document)
                } else {
                    LabPanel("Practice", systemImage: "repeat") {
                        EmptyPanelState(title: "Load an analysis to set loops.")
                    }
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
    }
}

private struct SectionLoopGrid: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    var document: MusicAnalysisDocument

    var body: some View {
        if document.structure.sections.isEmpty {
            EmptyPanelState(title: "No sections available.")
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(Array(document.structure.sections.enumerated()), id: \.offset) { index, section in
                    Button {
                        playbackStore.setLoop(section)
                        playbackStore.play()
                    } label: {
                        HStack {
                            Text("S\(index + 1)")
                                .font(.headline.monospacedDigit())
                            Spacer()
                            Text(AnalysisDerived.formatTime(section.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct CountInMarkersView: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    var document: MusicAnalysisDocument

    private var upcomingBeats: [Double] {
        Array(document.rhythm.beats.filter { $0 >= playbackStore.currentTime }.prefix(4))
    }

    var body: some View {
        LabPanel("Count-In Markers", systemImage: "123.rectangle") {
            if upcomingBeats.isEmpty {
                EmptyPanelState(title: "No upcoming beats.")
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(upcomingBeats.enumerated()), id: \.offset) { index, beat in
                        Button {
                            playbackStore.seek(to: beat)
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.title3.weight(.semibold).monospacedDigit())
                                Text(AnalysisDerived.formatTime(beat))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

struct DatasetModeView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LabPanel("Dataset Mode", systemImage: "externaldrive") {
                    HStack {
                        Button {
                            analysisStore.isFolderImporterPresented = true
                        } label: {
                            Label("Select Folder", systemImage: "folder")
                        }
                        .buttonStyle(.borderedProminent)

                        if let progress = analysisStore.datasetProgress {
                            ProgressView(value: Double(progress.current), total: Double(max(progress.total, 1))) {
                                Text(progress.currentFileName)
                            }
                            .frame(maxWidth: 360)
                        }

                        Spacer()

                        if let url = analysisStore.datasetExportURL {
                            ShareLink(item: url) {
                                Label("Share Dataset", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                BatchSnapshotPanel(documents: analysisStore.datasetDocuments)

                LabPanel("Dataset Results", systemImage: "list.bullet.rectangle") {
                    if analysisStore.datasetDocuments.isEmpty {
                        EmptyPanelState(title: "No dataset rows.")
                    } else {
                        if isCompact {
                            VStack(spacing: 10) {
                                ForEach(analysisStore.datasetDocuments) { document in
                                    CompactComparisonCard(document: document)
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                ComparisonHeader()
                                Divider()
                                ForEach(analysisStore.datasetDocuments) { document in
                                    ComparisonRow(document: document)
                                    if document.id != analysisStore.datasetDocuments.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
        .fileImporter(isPresented: folderImporterBinding, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task {
                await analysisStore.runDataset(folderURL: url)
            }
        }
    }

    private var folderImporterBinding: Binding<Bool> {
        Binding(
            get: { analysisStore.isFolderImporterPresented },
            set: { analysisStore.isFolderImporterPresented = $0 }
        )
    }
}

struct StreamingLabView: View {
    @EnvironmentObject private var streamingStore: StreamingAnalysisStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LabPanel("PCM Stream", systemImage: "dot.radiowaves.left.and.right") {
                    VStack(spacing: 12) {
                        HStack {
                            Button {
                                streamingStore.isRunning ? streamingStore.stop() : streamingStore.start()
                            } label: {
                                Label(streamingStore.isRunning ? "Stop" : "Start", systemImage: streamingStore.isRunning ? "stop.fill" : "play.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            Text(streamingStore.status)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        LabeledContent("Frequency") {
                            Slider(value: $streamingStore.frequency, in: 80...880)
                                .frame(maxWidth: 320)
                            Text("\(Int(streamingStore.frequency)) Hz")
                                .font(.callout.monospacedDigit())
                                .frame(width: 72, alignment: .trailing)
                        }

                        LabeledContent("Amplitude") {
                            Slider(value: $streamingStore.amplitude, in: 0.05...0.95)
                                .frame(maxWidth: 320)
                            Text(String(format: "%.2f", streamingStore.amplitude))
                                .font(.callout.monospacedDigit())
                                .frame(width: 72, alignment: .trailing)
                        }

                        LabeledContent("Duration") {
                            Slider(value: $streamingStore.duration, in: 6...60)
                                .frame(maxWidth: 320)
                            Text("\(Int(streamingStore.duration)) s")
                                .font(.callout.monospacedDigit())
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                }

                LabPanel("Live Loudness", systemImage: "waveform") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        MetricChip(title: "Integrated", value: streamingStore.integratedLUFS.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.coral)
                        MetricChip(title: "Peak", value: streamingStore.peak.map { String(format: "%.1f", $0.value) } ?? "-", tint: LabPalette.amber)
                        MetricChip(title: "Momentary", value: "\(streamingStore.momentary.count)", tint: LabPalette.blue)
                    }

                    let points = streamingStore.shortTerm.isEmpty ? streamingStore.momentary : streamingStore.shortTerm
                    if points.isEmpty {
                        EmptyPanelState(title: "No live loudness samples.")
                    } else {
                        Chart(points) { point in
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("LUFS", point.value)
                            )
                            .foregroundStyle(LabPalette.coral)
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 280)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
    }
}
