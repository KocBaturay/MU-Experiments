import Charts
import SwiftUI

struct MainLabView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore

    var body: some View {
        if let document = analysisStore.currentDocument {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LabHeaderView(document: document)
                    TransportPanel(document: document)
                    SampleStyleAnalysisTiles(document: document)
                    ArrangementTimelineView(document: document)
                    SectionMixerMapView(document: document)
                    AnalysisPanelGrid(document: document)
                }
                .padding()
                .frame(maxWidth: 1280, alignment: .topLeading)
            }
            .background(LabPalette.windowBackground)
        } else {
            EmptyPanelState(title: "No analysis loaded.")
                .background(LabPalette.windowBackground)
        }
    }
}

private struct SampleStyleAnalysisTiles: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 14)], spacing: 14) {
            SampleKeyTile(document: document)
            SampleRhythmTile(document: document)
            SampleStructureTile(document: document)
            SamplePaceTile(document: document)
            SampleInstrumentTile(document: document)
            SampleLoudnessTile(document: document)
        }
    }
}

private struct SampleKeyTile: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    private var currentKey: KeyRegion? {
        document.key.first { playbackStore.currentTime >= $0.range.start && playbackStore.currentTime < $0.range.end }
            ?? document.key.first
    }

    var body: some View {
        LabPanel("Key", systemImage: "key") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentKey?.displayName.components(separatedBy: " ").first ?? "-")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(currentKey?.mode.capitalized ?? "")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(height: 62)

            KeyTimelineLane(keys: document.key, duration: document.duration)
        }
    }
}

private struct SampleRhythmTile: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    private var beatsPerBar: Int {
        document.rhythm.inferredMeter ?? 4
    }

    private var currentBeat: Int {
        AnalysisDerived.beatNumber(
            at: playbackStore.currentTime,
            beats: document.rhythm.beats,
            bars: document.rhythm.bars
        ) ?? 1
    }

    var body: some View {
        LabPanel("Rhythm", systemImage: "metronome") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(document.rhythm.beatsPerMinute.map { String(format: "%.0f", $0) } ?? "-")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(height: 62)

            HStack(spacing: 8) {
                ForEach(1...max(2, beatsPerBar), id: \.self) { beat in
                    let isDownbeat = beat == 1
                    let isActive = playbackStore.isPlaying && beat == currentBeat

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(beatColor(isDownbeat: isDownbeat, isActive: isActive))
                        .frame(width: isDownbeat ? 42 : 34, height: 10)
                        .shadow(color: isActive ? LabPalette.accent.opacity(0.45) : .clear, radius: 5)
                        .animation(.easeOut(duration: 0.10), value: isActive)
                }

                Spacer()

                Text("Bar \(AnalysisDerived.barIndex(at: playbackStore.currentTime, bars: document.rhythm.bars).map { "\($0 + 1)" } ?? "-")")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            BeatBarTimelineLane(rhythm: document.rhythm, duration: document.duration)
        }
    }

    private func beatColor(isDownbeat: Bool, isActive: Bool) -> Color {
        if isActive {
            return isDownbeat ? LabPalette.accent : LabPalette.accent.opacity(0.62)
        }

        return isDownbeat ? Color.primary.opacity(0.22) : Color.primary.opacity(0.10)
    }
}

private struct SampleStructureTile: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Structure", systemImage: "square.stack.3d.down.right") {
            VStack(spacing: 8) {
                TimelineLane(title: "Sections", ranges: document.structure.sections, duration: document.duration, tint: LabPalette.blue, height: 18)
                TimelineLane(title: "Phrases", ranges: document.structure.phrases, duration: document.duration, tint: LabPalette.green, height: 14)
                TimelineLane(title: "Segments", ranges: document.structure.segments, duration: document.duration, tint: LabPalette.amber, height: 12)
            }

            HStack {
                Text("\(document.structure.sections.count) sections")
                Text("\(document.structure.phrases.count) phrases")
                Text("\(document.structure.segments.count) segments")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct SamplePaceTile: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Pace", systemImage: "speedometer") {
            ValueRangeLane(title: "Pace", ranges: document.pace.ranges, duration: document.duration, tint: LabPalette.coral, height: 58)
            HStack {
                Text("Average")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(document.averagePace.map { String(format: "%.2f events/s", $0) } ?? "-")
                    .font(.callout.monospacedDigit())
            }
        }
    }
}

private struct SampleInstrumentTile: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Instrument Activity", systemImage: "waveform.path.ecg") {
            VStack(spacing: 8) {
                ForEach(document.instrumentActivity) { lane in
                    TimelineLane(
                        title: lane.displayName,
                        ranges: lane.activeRanges,
                        duration: document.duration,
                        tint: color(for: lane.instrument),
                        height: 14
                    )
                }
            }
        }
    }

    private func color(for instrument: String) -> Color {
        switch instrument {
        case "vocal": LabPalette.coral
        case "drum": LabPalette.amber
        case "bass": LabPalette.green
        default: LabPalette.violet
        }
    }
}

private struct SampleLoudnessTile: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Loudness", systemImage: "waveform") {
            HStack(alignment: .firstTextBaseline) {
                Text(document.loudness.integratedLUFS.map { String(format: "%.1f", $0) } ?? "-")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("LUFS")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(document.loudness.peak.map { String(format: "Peak %.1f", $0.value) } ?? "Peak -")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            TimedCurveLane(
                title: "Curve",
                points: document.loudness.shortTerm.isEmpty ? document.loudness.momentary : document.loudness.shortTerm,
                duration: document.duration,
                tint: LabPalette.coral,
                height: 56
            )
        }
    }
}

private struct LabHeaderView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Current Song", systemImage: "music.note") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(document.source.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Text(analysisStore.state.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        analysisStore.prepareCurrentExport()
                    } label: {
                        Label("Prepare Export", systemImage: "doc.badge.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    if let bundle = analysisStore.exportBundle {
                        ShareLink(items: bundle.urls) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                MetricChip(title: "Duration", value: document.formattedDuration, tint: LabPalette.blue)
                MetricChip(title: "Key", value: document.primaryKeyDisplay, tint: LabPalette.violet)
                MetricChip(title: "Tempo", value: document.rhythm.beatsPerMinute.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.accent)
                MetricChip(title: "Meter", value: document.rhythm.inferredMeter.map { "\($0)/4" } ?? "-", tint: LabPalette.amber)
                MetricChip(title: "LUFS", value: document.loudness.integratedLUFS.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.coral)
                MetricChip(title: "Energy", value: String(format: "%.0f%%", document.energyScore * 100), tint: LabPalette.green)
            }
        }
    }
}

private struct TransportPanel: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Transport", systemImage: "playpause") {
            HStack(spacing: 12) {
                Button {
                    playbackStore.togglePlayback()
                } label: {
                    Image(systemName: playbackStore.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 22)
                }
                .help(playbackStore.isPlaying ? "Pause" : "Play")

                Button {
                    playbackStore.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 22)
                }
                .help("Stop")

                Text(playbackStore.formattedCurrentTime)
                    .font(.callout.monospacedDigit())
                    .frame(width: 58, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { playbackStore.currentTime },
                        set: { playbackStore.seek(to: $0) }
                    ),
                    in: 0...max(playbackStore.duration, document.duration, 1)
                )

                Text(playbackStore.formattedDuration == "0:00" ? document.formattedDuration : playbackStore.formattedDuration)
                    .font(.callout.monospacedDigit())
                    .frame(width: 58, alignment: .leading)

                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.secondary)
                Slider(value: $playbackStore.volume, in: 0...1)
                    .frame(maxWidth: 120)
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
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear loop")
                }
            }
        }
    }
}

private struct ArrangementTimelineView: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Timeline", systemImage: "timeline.selection") {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 8) {
                    KeyTimelineLane(keys: document.key, duration: document.duration)
                    TimelineLane(title: "Sections", ranges: document.structure.sections, duration: document.duration, tint: LabPalette.blue)
                    TimelineLane(title: "Phrases", ranges: document.structure.phrases, duration: document.duration, tint: LabPalette.green, height: 16)
                    TimelineLane(title: "Segments", ranges: document.structure.segments, duration: document.duration, tint: LabPalette.amber, height: 14)
                    BeatBarTimelineLane(rhythm: document.rhythm, duration: document.duration)
                    ValueRangeLane(title: "Pace", ranges: document.pace.ranges, duration: document.duration, tint: LabPalette.coral)
                }

                PlaybackCursorOverlay(currentTime: playbackStore.currentTime, duration: document.duration)
            }
        }
    }
}

private struct KeyTimelineLane: View {
    var keys: [KeyRegion]
    var duration: Double

    var body: some View {
        HStack(spacing: 10) {
            Text("Key")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LabPalette.laneFill)

                    ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                        let x = xOffset(for: key.range.start, width: proxy.size.width)
                        let width = rangeWidth(for: key.range, width: proxy.size.width)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill((index.isMultiple(of: 2) ? LabPalette.violet : LabPalette.accent).opacity(0.72))
                            .frame(width: width)
                            .overlay(alignment: .leading) {
                                if width > 56 {
                                    Text(key.displayName)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .lineLimit(1)
                                }
                            }
                            .offset(x: x)
                    }
                }
            }
            .frame(height: 22)
        }
        .frame(height: 22)
    }

    private func xOffset(for time: Double, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(max(0, min(1, time / duration))) * width
    }

    private func rangeWidth(for range: TimeRangeSummary, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return max(2, CGFloat(max(0, range.duration / duration)) * width - 1)
    }
}

private struct BeatBarTimelineLane: View {
    var rhythm: RhythmSummary
    var duration: Double

    var body: some View {
        HStack(spacing: 10) {
            Text("Bars")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(LabPalette.laneFill))
                guard duration > 0 else { return }

                for beat in rhythm.beats {
                    let x = CGFloat(max(0, min(1, beat / duration))) * size.width
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height * 0.38))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
                }

                for bar in rhythm.bars {
                    let x = CGFloat(max(0, min(1, bar / duration))) * size.width
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(LabPalette.accent), lineWidth: 1.5)
                }
            }
            .frame(height: 24)
        }
        .frame(height: 24)
    }
}

private struct SectionMixerMapView: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Section Mixer Map", systemImage: "rectangle.3.group") {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 8) {
                    TimelineLane(title: "Sections", ranges: document.structure.sections, duration: document.duration, tint: LabPalette.blue, height: 24)
                    ValueRangeLane(title: "Density", ranges: document.pace.ranges, duration: document.duration, tint: LabPalette.amber, height: 32)
                    TimedCurveLane(title: "LUFS", points: document.loudness.shortTerm.isEmpty ? document.loudness.momentary : document.loudness.shortTerm, duration: document.duration, tint: LabPalette.coral)

                    ForEach(document.instrumentActivity) { lane in
                        TimelineLane(
                            title: lane.displayName,
                            ranges: lane.activeRanges,
                            duration: document.duration,
                            tint: color(for: lane.instrument),
                            height: 16
                        )
                    }
                }

                PlaybackCursorOverlay(currentTime: playbackStore.currentTime, duration: document.duration)
            }
        }
    }

    private func color(for instrument: String) -> Color {
        switch instrument {
        case "vocal": LabPalette.coral
        case "drum": LabPalette.amber
        case "bass": LabPalette.green
        default: LabPalette.violet
        }
    }
}

private struct AnalysisPanelGrid: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14)], alignment: .leading, spacing: 14) {
            KeyPanel(document: document)
            RhythmPanel(document: document)
            StructurePanel(document: document)
            PacePanel(document: document)
            InstrumentActivityPanel(document: document)
            LoudnessPanel(document: document)
        }
    }
}

private struct KeyPanel: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    private var currentKey: KeyRegion? {
        document.key.first { playbackStore.currentTime >= $0.range.start && playbackStore.currentTime < $0.range.end }
            ?? document.key.first
    }

    var body: some View {
        LabPanel("Key Timeline", systemImage: "key") {
            MetricChip(title: "Current", value: currentKey?.displayName ?? "-", tint: LabPalette.violet)

            if document.key.isEmpty {
                EmptyPanelState(title: "No key regions.")
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(document.key.prefix(8)) { key in
                        HStack {
                            Text(key.displayName)
                                .font(.callout.weight(.medium))
                                .frame(width: 88, alignment: .leading)
                            Text("\(AnalysisDerived.formatTime(key.range.start)) - \(AnalysisDerived.formatTime(key.range.end))")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

private struct RhythmPanel: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Rhythm", systemImage: "metronome") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                MetricChip(title: "BPM", value: document.rhythm.beatsPerMinute.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.accent)
                MetricChip(title: "Beats", value: "\(document.rhythm.beats.count)", tint: LabPalette.blue)
                MetricChip(title: "Bars", value: "\(document.rhythm.bars.count)", tint: LabPalette.green)
                MetricChip(title: "Meter", value: document.rhythm.inferredMeter.map { "\($0)/4" } ?? "-", tint: LabPalette.amber)
            }

            HStack(spacing: 8) {
                let bar = AnalysisDerived.barIndex(at: playbackStore.currentTime, bars: document.rhythm.bars).map { $0 + 1 }
                let beat = AnalysisDerived.beatNumber(at: playbackStore.currentTime, beats: document.rhythm.beats, bars: document.rhythm.bars)
                Label("Bar \(bar.map(String.init) ?? "-")", systemImage: "music.quarternote.3")
                Label("Beat \(beat.map(String.init) ?? "-")", systemImage: "circle.grid.cross")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

private struct StructurePanel: View {
    @EnvironmentObject private var playbackStore: AudioPlaybackStore
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Structure", systemImage: "square.stack.3d.down.right") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                MetricChip(title: "Sections", value: "\(document.structure.sections.count)", tint: LabPalette.blue)
                MetricChip(title: "Phrases", value: "\(document.structure.phrases.count)", tint: LabPalette.green)
                MetricChip(title: "Segments", value: "\(document.structure.segments.count)", tint: LabPalette.amber)
            }

            if document.structure.sections.isEmpty {
                EmptyPanelState(title: "No sections.")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(document.structure.sections.prefix(10).enumerated()), id: \.offset) { index, section in
                        Button {
                            playbackStore.setLoop(section)
                        } label: {
                            HStack {
                                Text("S\(index + 1)")
                                    .font(.callout.weight(.semibold))
                                    .frame(width: 36, alignment: .leading)
                                Text("\(AnalysisDerived.formatTime(section.start)) - \(AnalysisDerived.formatTime(section.end))")
                                    .font(.callout.monospacedDigit())
                                Spacer()
                                Text(AnalysisDerived.formatTime(section.duration))
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct PacePanel: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Pace", systemImage: "speedometer") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                MetricChip(title: "Average", value: document.averagePace.map { String(format: "%.2f", $0) } ?? "-", tint: LabPalette.amber)
                MetricChip(title: "Ranges", value: "\(document.pace.ranges.count)", tint: LabPalette.coral)
            }

            if document.pace.ranges.isEmpty {
                EmptyPanelState(title: "No pace data.")
            } else {
                Chart(document.pace.ranges) { metric in
                    BarMark(
                        xStart: .value("Start", metric.range.start),
                        xEnd: .value("End", metric.range.end),
                        y: .value("Pace", metric.value)
                    )
                    .foregroundStyle(LabPalette.amber)
                }
                .chartXAxisLabel("Time")
                .chartYAxisLabel("Density")
                .frame(height: 170)
            }
        }
    }
}

private struct InstrumentActivityPanel: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Instrument Activity", systemImage: "waveform.path.ecg") {
            VStack(spacing: 10) {
                ForEach(document.instrumentActivity) { lane in
                    let share = AnalysisDerived.activeShare(for: lane, duration: document.duration)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(lane.displayName)
                                .font(.callout.weight(.medium))
                            Spacer()
                            Text(String(format: "%.0f%%", share * 100))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: share)
                            .tint(color(for: lane.instrument))
                    }
                }
            }
        }
    }

    private func color(for instrument: String) -> Color {
        switch instrument {
        case "vocal": LabPalette.coral
        case "drum": LabPalette.amber
        case "bass": LabPalette.green
        default: LabPalette.violet
        }
    }
}

private struct LoudnessPanel: View {
    let document: MusicAnalysisDocument

    var body: some View {
        LabPanel("Loudness", systemImage: "waveform") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                MetricChip(title: "Integrated", value: document.loudness.integratedLUFS.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.coral)
                MetricChip(title: "Peak", value: document.loudness.peak.map { String(format: "%.1f", $0.value) } ?? "-", tint: LabPalette.amber)
                MetricChip(title: "Momentary", value: "\(document.loudness.momentary.count)", tint: LabPalette.blue)
            }

            let points = document.loudness.shortTerm.isEmpty ? document.loudness.momentary : document.loudness.shortTerm
            if points.isEmpty {
                EmptyPanelState(title: "No loudness curve.")
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("LUFS", point.value)
                    )
                    .foregroundStyle(LabPalette.coral)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxisLabel("Time")
                .chartYAxisLabel("LUFS")
                .frame(height: 170)
            }
        }
    }
}
