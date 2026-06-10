import SwiftUI

@main
struct MusicUnderstandingExperimentsApp: App {
    @StateObject private var analysisStore = AnalysisSessionStore()
    @StateObject private var playbackStore = AudioPlaybackStore()
    @StateObject private var streamingStore = StreamingAnalysisStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(analysisStore)
                .environmentObject(playbackStore)
                .environmentObject(streamingStore)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Analyze Song...") {
                    NotificationCenter.default.post(name: .showSongImporter, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let showSongImporter = Notification.Name("MusicUnderstandingExperiments.showSongImporter")
}
