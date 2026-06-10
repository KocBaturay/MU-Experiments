import SwiftUI
import UniformTypeIdentifiers

enum LabRoute: String, CaseIterable, Identifiable {
    case fileLab
    case batch
    case dj
    case practice
    case dataset
    case streaming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileLab: "Analysis"
        case .batch: "Batch Compare"
        case .dj: "DJ Finder"
        case .practice: "Practice"
        case .dataset: "Dataset"
        case .streaming: "Streaming"
        }
    }

    var systemImage: String {
        switch self {
        case .fileLab: "waveform"
        case .batch: "tablecells"
        case .dj: "slider.horizontal.3"
        case .practice: "repeat"
        case .dataset: "externaldrive"
        case .streaming: "dot.radiowaves.left.and.right"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore

    var body: some View {
        NavigationSplitView(
            columnVisibility: splitVisibilityBinding,
            preferredCompactColumn: compactColumnBinding
        ) {
            SidebarView(route: routeBinding, isSongImporterPresented: songImporterBinding)
                .navigationTitle("MU Experiments")
        } detail: {
            Group {
                switch analysisStore.selectedRoute {
                case .fileLab:
                    if analysisStore.state.isPreparingAnalysis {
                        AnalysisLoadingView()
                    } else if let message = analysisStore.state.failedMessage {
                        AnalysisFailureView(message: message, isSongImporterPresented: songImporterBinding)
                    } else if analysisStore.currentDocument != nil {
                        MainLabView()
                    } else {
                        HomeView(isSongImporterPresented: songImporterBinding)
                    }
                case .batch:
                    BatchCompareView()
                case .dj:
                    DJTransitionFinderView()
                case .practice:
                    PracticeCompanionView()
                case .dataset:
                    DatasetModeView()
                case .streaming:
                    StreamingLabView()
                }
            }
            .navigationTitle(analysisStore.selectedRoute.title)
        }
        .tint(LabPalette.accent)
        .fileImporter(isPresented: songImporterBinding, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            analysisStore.selectedRoute = .fileLab
            Task {
                await analysisStore.analyzeFile(at: url, playback: playbackStore)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSongImporter)) { _ in
            analysisStore.isSongImporterPresented = true
        }
    }

    private var routeBinding: Binding<LabRoute> {
        Binding(
            get: { analysisStore.selectedRoute },
            set: { analysisStore.selectedRoute = $0 }
        )
    }

    private var songImporterBinding: Binding<Bool> {
        Binding(
            get: { analysisStore.isSongImporterPresented },
            set: { analysisStore.isSongImporterPresented = $0 }
        )
    }

    private var splitVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { analysisStore.splitColumnVisibility },
            set: { analysisStore.splitColumnVisibility = $0 }
        )
    }

    private var compactColumnBinding: Binding<NavigationSplitViewColumn> {
        Binding(
            get: { analysisStore.preferredCompactColumn },
            set: { analysisStore.preferredCompactColumn = $0 }
        )
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore

    @Binding var route: LabRoute
    @Binding var isSongImporterPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    isSongImporterPresented = true
                } label: {
                    Label("Select Song", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

                SidebarSection("Analysis") {
                    SidebarRouteRow(route: .fileLab, selectedRoute: $route)
                }

                SidebarSection("Recent") {
                    if analysisStore.recentAnalyses.isEmpty {
                        Text("No analyses yet")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(analysisStore.recentAnalyses) { record in
                            Button {
                                analysisStore.openRecent(record, playback: playbackStore)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title)
                                        .lineLimit(1)
                                    Text("\(record.document.primaryKeyDisplay) | \(record.document.rhythm.beatsPerMinute.map { String(format: "%.0f BPM", $0) } ?? "No BPM")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.045))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SidebarSection("Labs") {
                    ForEach([LabRoute.batch, .dj, .practice, .dataset, .streaming]) { route in
                        SidebarRouteRow(route: route, selectedRoute: $route)
                    }
                }
            }
            .padding(12)
        }
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 10)

            content
        }
    }
}

private struct SidebarRouteRow: View {
    let route: LabRoute
    @Binding var selectedRoute: LabRoute

    var body: some View {
        Button {
            selectedRoute = route
        } label: {
            Label(route.title, systemImage: route.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedRoute == route ? LabPalette.accent.opacity(0.16) : Color.clear)
                }
                .foregroundStyle(selectedRoute == route ? LabPalette.accent : .primary)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HomeView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore

    @Binding var isSongImporterPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MusicUnderstandingExperiments")
                            .font(.title2.weight(.semibold))
                        Text(analysisStore.state.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isSongImporterPresented = true
                    } label: {
                        Label("Select Song", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                }

                RecentAnalysisList { record in
                    analysisStore.openRecent(record, playback: playbackStore)
                }

                BatchSnapshotPanel(documents: analysisStore.comparisonDocuments)
            }
            .padding()
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .background(LabPalette.windowBackground)
    }
}

private struct AnalysisLoadingView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 6) {
                Text(analysisStore.state.label)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Key, rhythm, structure, pace, instruments, and loudness")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LabPalette.windowBackground)
    }
}

private struct AnalysisFailureView: View {
    var message: String
    @Binding var isSongImporterPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(LabPalette.coral)

            Text("Analysis Failed")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button {
                isSongImporterPresented = true
            } label: {
                Label("Select Another Song", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LabPalette.windowBackground)
    }
}
