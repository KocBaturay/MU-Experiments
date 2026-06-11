import SwiftUI
import UniformTypeIdentifiers

enum LabRoute: String, CaseIterable, Identifiable {
    case fileLab
    case batch
    case dj
    case practice
    case streaming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileLab: "Analysis"
        case .batch: "Data Compare"
        case .dj: "DJ Finder"
        case .practice: "Practice"
        case .streaming: "Streaming"
        }
    }

    var systemImage: String {
        switch self {
        case .fileLab: "waveform"
        case .batch: "tablecells"
        case .dj: "slider.horizontal.3"
        case .practice: "repeat"
        case .streaming: "dot.radiowaves.left.and.right"
        }
    }

    var description: String {
        switch self {
        case .fileLab:
            "Analyze one song for key, tempo, structure, loudness, and playback timelines."
        case .batch:
            "Compare analyzed songs and share them as a dataset export."
        case .dj:
            "Find transition-friendly song pairs using tempo, key, and energy matching."
        case .practice:
            "Loop sections, jump to beats, and rehearse count-ins against the track."
        case .streaming:
            "Generate a PCM stream and inspect loudness metrics in real time."
        }
    }

    static let tabs: [LabRoute] = [.fileLab, .batch, .dj, .practice, .streaming]
}

struct ContentView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore

    var body: some View {
        TabView(selection: routeBinding) {
            ForEach(LabRoute.tabs) { route in
                NavigationStack {
                    screen(for: route)
                        .navigationTitle(route.title)
                }
                .tabItem {
                    Label(route.title, systemImage: route.systemImage)
                }
                .tag(route)
                .badge(route == .fileLab ? analysisStore.unreadAnalysisCount : 0)
            }
        }
        .tint(LabPalette.accent)
        .fileImporter(isPresented: songImporterBinding, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task {
                await analysisStore.analyzeFile(at: url, playback: playbackStore)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSongImporter)) { _ in
            analysisStore.isSongImporterPresented = true
        }
    }

    @ViewBuilder
    private func screen(for route: LabRoute) -> some View {
        switch route {
        case .fileLab:
            analysisScreen
        case .batch:
            BatchCompareView()
        case .dj:
            DJTransitionFinderView()
        case .practice:
            PracticeCompanionView()
        case .streaming:
            StreamingLabView()
        }
    }

    private var routeBinding: Binding<LabRoute> {
        Binding(
            get: { analysisStore.selectedRoute },
            set: { analysisStore.selectedRoute = $0 }
        )
    }

    @ViewBuilder
    private var analysisScreen: some View {
        if let message = analysisStore.state.failedMessage {
            AnalysisFailureView(message: message, isSongImporterPresented: songImporterBinding)
        } else {
            HomeView(isSongImporterPresented: songImporterBinding)
        }
    }

    private var songImporterBinding: Binding<Bool> {
        Binding(
            get: { analysisStore.isSongImporterPresented },
            set: { analysisStore.isSongImporterPresented = $0 }
        )
    }
}

struct HomeView: View {
    @EnvironmentObject private var analysisStore: AnalysisSessionStore
    @EnvironmentObject private var playbackStore: AudioPlaybackStore

    @Binding var isSongImporterPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabDescriptionView(description: LabRoute.fileLab.description)

                RecentAnalysisList { record in
                    analysisStore.presentRecent(record, playback: playbackStore)
                }
            }
            .padding([.horizontal, .top])
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .background(LabPalette.windowBackground)
        .safeAreaInset(edge: .bottom) {
            selectSongButton
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.bar)
        }
        .sheet(item: presentedRecordBinding) { record in
            AnalysisDocumentSheetView(record: record)
        }
    }

    private var presentedRecordBinding: Binding<RecentAnalysisRecord?> {
        Binding(
            get: { analysisStore.presentedAnalysisRecord },
            set: { analysisStore.presentedAnalysisRecord = $0 }
        )
    }

    private var selectSongButton: some View {
        Button {
            isSongImporterPresented = true
        } label: {
            Label("Select & Analyze Song", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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
