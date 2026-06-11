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
                LabDescriptionView(description: LabRoute.batch.description)
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
                DataCompareExportPanel()
            }
            .padding()
            .frame(maxWidth: 1180, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
    }
}

private struct DataCompareExportPanel: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore

    var body: some View {
        LabPanel("Dataset Export", systemImage: "square.and.arrow.up") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    exportSummary
                    shareDatasetButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    exportSummary
                    shareDatasetButton
                }
            }
        }
    }

    private var exportSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(analysisStore.comparisonDocuments.count) analyzed songs")
                .font(.headline)
            Text("Exports the songs listed below as a dataset.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareDatasetButton: some View {
        Group {
            if let url = analysisStore.datasetExportURL {
                ShareLink(item: url) {
                    Label("Share Dataset", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    analysisStore.prepareComparisonDatasetExport()
                } label: {
                    Label("Prepare Dataset", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(analysisStore.comparisonDocuments.isEmpty)
            }
        }
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
                LabDescriptionView(description: LabRoute.dj.description)
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
                LabDescriptionView(description: LabRoute.practice.description)
                if let document = analysisStore.currentDocument {
                    LabPanel("Practice Song", systemImage: "music.note") {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 12) {
                                practiceSongSummary(document: document)
                                Spacer(minLength: 12)
                                changeSongButton
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                practiceSongSummary(document: document)
                                changeSongButton
                            }
                        }
                    }

                    LabPanel("Beat And Bar Looping", systemImage: "repeat") {
                        PracticeTransportBar(document: document)

                        Divider()

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
                        if analysisStore.state.isPreparingAnalysis {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text(analysisStore.state.label)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            VStack(spacing: 12) {
                                EmptyPanelState(title: analysisStore.recentAnalyses.isEmpty ? "Analyze a song first, then choose it here." : "Choose an analyzed song to set beat and section loops.")
                                selectSongButton
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .topLeading)
        }
        .background(LabPalette.windowBackground)
        .sheet(isPresented: practicePickerBinding) {
            PracticeSongPickerView()
        }
    }

    private var practicePickerBinding: Binding<Bool> {
        Binding(
            get: { analysisStore.isPracticeSongPickerPresented },
            set: { analysisStore.isPracticeSongPickerPresented = $0 }
        )
    }

    private func practiceSongSummary(document: MusicAnalysisDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.source.name)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text("\(document.primaryKeyDisplay) • \(document.rhythm.beatsPerMinute.map { String(format: "%.0f BPM", $0) } ?? "No BPM") • \(document.formattedDuration)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectSongButton: some View {
        Button {
            analysisStore.selectedRoute = .practice
            analysisStore.isPracticeSongPickerPresented = true
        } label: {
            Label("Choose Analyzed Song", systemImage: "music.note.list")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(analysisStore.recentAnalyses.isEmpty)
    }

    private var changeSongButton: some View {
        Button {
            analysisStore.selectedRoute = .practice
            analysisStore.isPracticeSongPickerPresented = true
        } label: {
            Label("Change Song", systemImage: "folder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct PracticeSongPickerView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if analysisStore.recentAnalyses.isEmpty {
                        LabPanel("Analyzed Songs", systemImage: "music.note.list") {
                            EmptyPanelState(title: "No analyzed songs yet.")
                        }
                    } else {
                        LabPanel("Analyzed Songs", systemImage: "music.note.list") {
                            VStack(spacing: 0) {
                                ForEach(analysisStore.recentAnalyses) { record in
                                    Button {
                                        analysisStore.selectPracticeSong(record, playback: playbackStore)
                                        dismiss()
                                    } label: {
                                        PracticeSongPickerRow(record: record)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if record.id != analysisStore.recentAnalyses.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(LabPalette.windowBackground)
            .navigationTitle("Choose Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PracticeSongPickerRow: View {
    var record: RecentAnalysisRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(record.analyzedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(record.document.rhythm.beatsPerMinute.map { String(format: "%.0f BPM", $0) } ?? "No BPM")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct PracticeTransportBar: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    var document: MusicAnalysisDocument

    var body: some View {
        let playbackDuration = max(playbackStore.duration, document.duration, 1)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    playbackStore.isPlaying ? playbackStore.stop() : playbackStore.play()
                } label: {
                    Label(playbackStore.isPlaying ? "Stop" : "Play", systemImage: playbackStore.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Text(playbackStore.formattedCurrentTime)
                    .font(.callout.monospacedDigit())
                    .frame(width: 58, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { playbackStore.currentTime },
                        set: { playbackStore.seek(to: $0) }
                    ),
                    in: 0...playbackDuration
                )

                Text(playbackStore.formattedDuration == "0:00" ? document.formattedDuration : playbackStore.formattedDuration)
                    .font(.callout.monospacedDigit())
                    .frame(width: 58, alignment: .leading)
            }

            if let loop = playbackStore.loopRange {
                HStack(spacing: 8) {
                    Label(
                        "\(AnalysisDerived.formatTime(loop.start)) - \(AnalysisDerived.formatTime(loop.end))",
                        systemImage: "repeat"
                    )
                    .font(.callout)
                    .foregroundStyle(LabPalette.accent)

                    Button {
                        playbackStore.setLoop(nil)
                    } label: {
                        Label("Clear Loop", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
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

struct StreamingLabView: View {
    @EnvironmentObject private var streamingStore: StreamingAnalysisStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LabDescriptionView(description: LabRoute.streaming.description)
                LabPanel("PCM Stream", systemImage: "dot.radiowaves.left.and.right") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Button {
                                streamingStore.isRunning ? streamingStore.stop() : streamingStore.start()
                            } label: {
                                Label(streamingStore.isRunning ? "Stop" : "Start", systemImage: streamingStore.isRunning ? "stop.fill" : "play.fill")
                                    .frame(minWidth: 92)
                            }
                            .buttonStyle(.borderedProminent)

                            Text(streamingStore.status)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)

                            Spacer(minLength: 0)
                        }

                        StreamControlRow(title: "Frequency", value: $streamingStore.frequency, bounds: 80...880, formattedValue: "\(Int(streamingStore.frequency)) Hz")
                        StreamControlRow(title: "Amplitude", value: $streamingStore.amplitude, bounds: 0.05...0.95, formattedValue: String(format: "%.2f", streamingStore.amplitude))
                        StreamControlRow(title: "Duration", value: $streamingStore.duration, bounds: 6...60, formattedValue: "\(Int(streamingStore.duration)) s")
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

private struct StreamControlRow: View {
    var title: String
    @Binding var value: Double
    var bounds: ClosedRange<Double>
    var formattedValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(formattedValue)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: bounds)
        }
    }
}
