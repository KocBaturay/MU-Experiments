import SwiftUI

enum LabPalette {
    static let accent = Color(red: 0.09, green: 0.55, blue: 0.62)
    static let coral = Color(red: 0.86, green: 0.31, blue: 0.25)
    static let amber = Color(red: 0.92, green: 0.64, blue: 0.19)
    static let green = Color(red: 0.25, green: 0.62, blue: 0.36)
    static let blue = Color(red: 0.24, green: 0.42, blue: 0.82)
    static let violet = Color(red: 0.46, green: 0.35, blue: 0.76)
    static let panelStroke = Color.primary.opacity(0.10)
    static let panelFill = Color.primary.opacity(0.045)
    static let laneFill = Color.primary.opacity(0.07)
    #if os(macOS)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    #else
    static let windowBackground = Color(uiColor: .systemBackground)
    #endif
}

struct LabDescriptionView: View {
    var description: String

    var body: some View {
        Text(description)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LabPanel<Content: View>: View {
    var title: String
    var systemImage: String
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(
        _ title: String,
        systemImage: String,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                if let trailing {
                    trailing
                }
            }

            content
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LabPalette.panelFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(LabPalette.panelStroke)
                }
        }
    }
}

struct MetricChip: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 3)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EmptyPanelState: View {
    var title: String

    var body: some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

struct TimelineLane: View {
    var title: String
    var ranges: [TimeRangeSummary]
    var duration: Double
    var tint: Color
    var height: CGFloat = 20

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LabPalette.laneFill)

                    ForEach(Array(ranges.enumerated()), id: \.offset) { index, range in
                        let x = xOffset(for: range.start, width: proxy.size.width)
                        let width = rangeWidth(for: range, width: proxy.size.width)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(tint.opacity(index.isMultiple(of: 2) ? 0.80 : 0.55))
                            .frame(width: width, height: height)
                            .offset(x: x)
                    }
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
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

struct ValueRangeLane: View {
    var title: String
    var ranges: [RangedMetric]
    var duration: Double
    var tint: Color
    var height: CGFloat = 28

    private var maxValue: Double {
        max(ranges.map(\.value).max() ?? 1, 0.01)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LabPalette.laneFill)

                    ForEach(ranges) { metric in
                        let x = xOffset(for: metric.range.start, width: proxy.size.width)
                        let width = rangeWidth(for: metric.range, width: proxy.size.width)
                        let valueHeight = max(2, CGFloat(metric.value / maxValue) * height)
                        Rectangle()
                            .fill(tint.opacity(0.72))
                            .frame(width: width, height: valueHeight)
                            .offset(x: x)
                    }
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
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

struct TimedCurveLane: View {
    var title: String
    var points: [TimedMetric]
    var duration: Double
    var tint: Color
    var height: CGFloat = 38

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(LabPalette.laneFill))
                guard points.count >= 2, duration > 0 else { return }

                let values = points.map(\.value)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let span = max(maxValue - minValue, 0.001)

                var path = Path()
                for (index, point) in points.enumerated() {
                    let x = CGFloat(max(0, min(1, point.time / duration))) * size.width
                    let normalized = (point.value - minValue) / span
                    let y = size.height - CGFloat(normalized) * size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(path, with: .color(tint), lineWidth: 2)
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

struct PlaybackCursorOverlay: View {
    var currentTime: Double
    var duration: Double
    var labelWidth: CGFloat = 82

    var body: some View {
        GeometryReader { proxy in
            if duration > 0 {
                let usableWidth = max(0, proxy.size.width - labelWidth)
                let x = labelWidth + CGFloat(max(0, min(1, currentTime / duration))) * usableWidth
                Rectangle()
                    .fill(LabPalette.coral)
                    .frame(width: 2)
                    .offset(x: x)
            }
        }
        .allowsHitTesting(false)
    }
}

struct RecentAnalysisList: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var onOpen: (RecentAnalysisRecord) -> Void

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        LabPanel("Recent Analyses", systemImage: "clock") {
            if analysisStore.pendingAnalyses.isEmpty && analysisStore.recentAnalyses.isEmpty {
                EmptyPanelState(title: "Select a song to create the first analysis.")
            } else {
                VStack(spacing: 0) {
                    ForEach(analysisStore.pendingAnalyses) { record in
                        PendingAnalysisListRow(record: record)

                        if record.id != analysisStore.pendingAnalyses.last?.id || !analysisStore.recentAnalyses.isEmpty {
                            Divider()
                        }
                    }

                    ForEach(analysisStore.recentAnalyses) { record in
                        Button {
                            onOpen(record)
                        } label: {
                            RecentAnalysisRow(
                                record: record,
                                isCompact: isCompact,
                                isUnread: analysisStore.isAnalysisUnread(record)
                            )
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
}

private struct PendingAnalysisListRow: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    var record: PendingAnalysisRecord

    var body: some View {
        Button {
            analysisStore.selectedRoute = .fileLab
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(record.startedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(record.status)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(LabPalette.accent)
                }
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RecentAnalysisRow: View {
    var record: RecentAnalysisRecord
    var isCompact: Bool
    var isUnread: Bool

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(record.analyzedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isUnread {
                        RecentStatusPill("Ready")
                    }
                }

                HStack(spacing: 8) {
                    RecentMetricPill(record.document.primaryKeyDisplay)
                    RecentMetricPill(record.document.rhythm.beatsPerMinute.map { String(format: "%.0f BPM", $0) } ?? "No BPM")
                    RecentMetricPill(record.document.formattedDuration)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 9)
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(record.analyzedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isUnread {
                    RecentStatusPill("Ready")
                }

                Text(record.document.primaryKeyDisplay)
                    .font(.callout.weight(.medium))
                    .frame(width: 86, alignment: .trailing)

                Text(record.document.rhythm.beatsPerMinute.map { String(format: "%.0f BPM", $0) } ?? "No BPM")
                    .font(.callout.monospacedDigit())
                    .frame(width: 78, alignment: .trailing)

                Text(record.document.formattedDuration)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RecentStatusPill: View {
    var value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(LabPalette.accent)
            .background {
                Capsule()
                    .fill(LabPalette.accent.opacity(0.12))
            }
    }
}

private struct RecentMetricPill: View {
    var value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            }
    }
}

struct BatchSnapshotPanel: View {
    var documents: [MusicAnalysisDocument]

    var body: some View {
        LabPanel("Library Snapshot", systemImage: "chart.bar.xaxis") {
            let averageBPM = average(documents.compactMap(\.rhythm.beatsPerMinute))
            let averageLUFS = average(documents.compactMap(\.loudness.integratedLUFS))
            let averageEnergy = average(documents.map(\.energyScore))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                MetricChip(title: "Songs", value: "\(documents.count)", tint: LabPalette.blue)
                MetricChip(title: "Avg BPM", value: averageBPM.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.accent)
                MetricChip(title: "Avg LUFS", value: averageLUFS.map { String(format: "%.1f", $0) } ?? "-", tint: LabPalette.coral)
                MetricChip(title: "Avg Energy", value: averageEnergy.map { String(format: "%.0f%%", $0 * 100) } ?? "-", tint: LabPalette.green)
            }
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
