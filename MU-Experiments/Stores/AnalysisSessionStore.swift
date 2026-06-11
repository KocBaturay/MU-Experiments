@preconcurrency import AVFoundation
import Combine
import Foundation
import MusicUnderstanding
import UniformTypeIdentifiers

enum AnalysisRunState: Equatable {
    case idle
    case loadingAsset(String)
    case analyzing(String)
    case ready(String)
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Idle"
        case .loadingAsset(let name): "Loading \(name)"
        case .analyzing(let name): "Analyzing \(name)"
        case .ready(let name): "Ready \(name)"
        case .failed(let message): message
        }
    }

    var isPreparingAnalysis: Bool {
        switch self {
        case .loadingAsset, .analyzing:
            true
        case .idle, .ready, .failed:
            false
        }
    }

    var failedMessage: String? {
        if case .failed(let message) = self {
            return message
        }

        return nil
    }
}

@MainActor
final class AnalysisSessionStore: ObservableObject {
    @Published private(set) var currentDocument: MusicAnalysisDocument?
    @Published private(set) var selectedURL: URL?
    @Published private(set) var state: AnalysisRunState = .idle
    @Published private(set) var recentAnalyses: [RecentAnalysisRecord] = []
    @Published private(set) var pendingAnalyses: [PendingAnalysisRecord] = []
    @Published private(set) var datasetDocuments: [MusicAnalysisDocument] = []
    @Published private(set) var datasetProgress: DatasetProgress?
    @Published private(set) var exportBundle: AnalysisExportBundle?
    @Published private(set) var datasetExportURL: URL?
    @Published private(set) var unreadAnalysisIDs: Set<UUID> = []
    @Published var selectedRoute: LabRoute = .fileLab
    @Published var presentedAnalysisRecord: RecentAnalysisRecord?
    @Published var isPracticeSongPickerPresented = false
    @Published var isSongImporterPresented = false
    @Published var isFolderImporterPresented = false

    private var activeSession: MusicUnderstandingSession?
    private let recentStorageKey = "MusicUnderstandingExperiments.recentAnalyses"

    var unreadAnalysisCount: Int {
        unreadAnalysisIDs.count
    }

    init() {
        loadRecentAnalyses()
    }

    func analyzeFile(at url: URL, playback: AudioPlaybackStore? = nil) async {
        currentDocument = nil
        await analyzeURL(url, playback: playback, shouldPersistRecent: true, shouldSetCurrent: true)
    }

    func openRecent(_ record: RecentAnalysisRecord, playback: AudioPlaybackStore? = nil) {
        currentDocument = record.document
        selectedRoute = .fileLab
        state = .ready(record.document.source.name)
        exportBundle = nil
        markAnalysisViewed(record)

        loadPlayback(for: record, playback: playback)
    }

    func presentRecent(_ record: RecentAnalysisRecord, playback: AudioPlaybackStore? = nil) {
        exportBundle = nil
        presentedAnalysisRecord = record
        markAnalysisViewed(record)
        loadPlayback(for: record, playback: playback)
    }

    func selectPracticeSong(_ record: RecentAnalysisRecord, playback: AudioPlaybackStore? = nil) {
        currentDocument = record.document
        selectedRoute = .practice
        state = .ready(record.document.source.name)
        exportBundle = nil
        loadPlayback(for: record, playback: playback)
    }

    func isAnalysisUnread(_ record: RecentAnalysisRecord) -> Bool {
        unreadAnalysisIDs.contains(record.id)
    }

    func loadPlayback(for record: RecentAnalysisRecord, playback: AudioPlaybackStore? = nil) {
        guard let url = resolveURL(from: record) else { return }

        Task { @MainActor in
            let access = SecurityScopedAccess(url: url)
            defer { access.stop() }

            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ])
            await playback?.load(asset: asset)
        }
    }

    func cancelAnalysis() {
        let session = activeSession
        activeSession = nil
        Task {
            await session?.cancel()
        }
        pendingAnalyses.removeAll()
        state = .idle
    }

    func prepareCurrentExport() {
        guard let currentDocument else { return }
        prepareExport(for: currentDocument)
    }

    func prepareExport(for document: MusicAnalysisDocument) {
        do {
            exportBundle = try AnalysisExportService.writeExports(for: document)
        } catch {
            state = .failed("Export failed: \(error.localizedDescription)")
        }
    }

    func prepareComparisonDatasetExport() {
        let documents = comparisonDocuments
        guard !documents.isEmpty else { return }

        do {
            datasetExportURL = try AnalysisExportService.writeDatasetExport(for: documents)
        } catch {
            state = .failed("Dataset export failed: \(error.localizedDescription)")
        }
    }

    func runDataset(folderURL: URL) async {
        let access = SecurityScopedAccess(url: folderURL)
        defer { access.stop() }

        do {
            let files = try audioFiles(in: folderURL)
            datasetDocuments = []
            datasetExportURL = nil
            datasetProgress = DatasetProgress(current: 0, total: files.count, currentFileName: "")

            for (index, file) in files.enumerated() {
                datasetProgress = DatasetProgress(
                    current: index + 1,
                    total: files.count,
                    currentFileName: file.lastPathComponent
                )

                if let document = await analyzeURL(
                    file,
                    playback: nil,
                    shouldPersistRecent: false,
                    shouldSetCurrent: false
                ) {
                    datasetDocuments.append(document)
                }
            }

            datasetProgress = nil
            datasetExportURL = try AnalysisExportService.writeDatasetExport(for: datasetDocuments)
            state = .ready("Dataset: \(datasetDocuments.count) songs")
        } catch {
            datasetProgress = nil
            state = .failed("Dataset failed: \(error.localizedDescription)")
        }
    }

    var comparisonDocuments: [MusicAnalysisDocument] {
        var documents = recentAnalyses.map(\.document)
        if let currentDocument, !documents.contains(where: { $0.id == currentDocument.id }) {
            documents.insert(currentDocument, at: 0)
        }
        return documents
    }

    @discardableResult
    private func analyzeURL(
        _ url: URL,
        playback: AudioPlaybackStore?,
        shouldPersistRecent: Bool,
        shouldSetCurrent: Bool
    ) async -> MusicAnalysisDocument? {
        let access = SecurityScopedAccess(url: url)
        defer { access.stop() }

        let name = url.deletingPathExtension().lastPathComponent
        let pendingID = shouldPersistRecent ? beginPendingAnalysis(title: name, filePath: url.path) : nil

        if shouldSetCurrent {
            selectedURL = url
            exportBundle = nil
            state = .loadingAsset(name)
        }
        updatePendingAnalysis(id: pendingID, status: "Loading")

        do {
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ])

            let isProtected = try await asset.load(.hasProtectedContent)
            guard !isProtected else { throw AnalysisError.protectedContent }

            if shouldSetCurrent {
                await playback?.load(asset: asset)
                state = .analyzing(name)
            }
            updatePendingAnalysis(id: pendingID, status: "Analyzing")

            let duration = try await asset.load(.duration).seconds
            let session = try await MusicUnderstandingSession(asset: asset)
            activeSession = session
            let result = try await session.analyze(for: Self.allAnalysisTypes)
            activeSession = nil

            let document = AnalysisNormalizer.document(from: result, sourceURL: url, duration: duration)

            if shouldSetCurrent {
                currentDocument = document
                state = .ready(name)
            }

            if shouldPersistRecent {
                addRecent(document: document, sourceURL: url)
            }
            finishPendingAnalysis(id: pendingID)

            return document
        } catch is CancellationError {
            activeSession = nil
            finishPendingAnalysis(id: pendingID)
            if shouldSetCurrent {
                state = .idle
            }
            return nil
        } catch {
            activeSession = nil
            finishPendingAnalysis(id: pendingID)
            if shouldSetCurrent {
                state = .failed(error.localizedDescription)
            }
            return nil
        }
    }

    private static var allAnalysisTypes: Set<AnalysisType> {
        [.key, .rhythm, .structure, .pace, .instrumentActivity, .loudness]
    }

    private func addRecent(document: MusicAnalysisDocument, sourceURL: URL) {
        let record = RecentAnalysisRecord(
            id: UUID(),
            document: document,
            filePath: sourceURL.path,
            bookmarkData: bookmarkData(for: sourceURL)
        )

        let replacedIDs = Set(recentAnalyses
            .filter { $0.filePath == record.filePath || $0.document.source.urlString == document.source.urlString }
            .map(\.id))
        recentAnalyses.removeAll { $0.filePath == record.filePath || $0.document.source.urlString == document.source.urlString }
        recentAnalyses.insert(record, at: 0)
        recentAnalyses = Array(recentAnalyses.prefix(20))
        var unreadIDs = unreadAnalysisIDs.subtracting(replacedIDs)
        unreadIDs.insert(record.id)
        unreadAnalysisIDs = unreadIDs
        datasetExportURL = nil
        saveRecentAnalyses()
    }

    private func markAnalysisViewed(_ record: RecentAnalysisRecord) {
        guard unreadAnalysisIDs.contains(record.id) else { return }
        var unreadIDs = unreadAnalysisIDs
        unreadIDs.remove(record.id)
        unreadAnalysisIDs = unreadIDs
    }

    private func beginPendingAnalysis(title: String, filePath: String?) -> UUID {
        let record = PendingAnalysisRecord(
            id: UUID(),
            title: title,
            status: "Loading",
            filePath: filePath,
            startedAt: Date()
        )

        pendingAnalyses.removeAll {
            if let filePath, $0.filePath == filePath {
                return true
            }

            return $0.title == title
        }
        pendingAnalyses.insert(record, at: 0)
        return record.id
    }

    private func updatePendingAnalysis(id: UUID?, status: String) {
        guard let id, let index = pendingAnalyses.firstIndex(where: { $0.id == id }) else { return }
        pendingAnalyses[index].status = status
    }

    private func finishPendingAnalysis(id: UUID?) {
        guard let id else { return }
        pendingAnalyses.removeAll { $0.id == id }
    }

    private func loadRecentAnalyses() {
        guard let data = UserDefaults.standard.data(forKey: recentStorageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        recentAnalyses = (try? decoder.decode([RecentAnalysisRecord].self, from: data)) ?? []
    }

    private func saveRecentAnalyses() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(recentAnalyses) {
            UserDefaults.standard.set(data, forKey: recentStorageKey)
        }
    }

    private func audioFiles(in folderURL: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey]
        let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        return enumerator?.compactMap { item -> URL? in
            guard let url = item as? URL else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { return nil }
            if values?.contentType?.conforms(to: .audio) == true { return url }
            return nil
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending } ?? []
    }

    private func bookmarkData(for url: URL) -> Data? {
        #if os(macOS)
        try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        nil
        #endif
    }

    private func resolveURL(from record: RecentAnalysisRecord) -> URL? {
        #if os(macOS)
        if let bookmarkData = record.bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }
        #endif

        if let filePath = record.filePath {
            return URL(fileURLWithPath: filePath)
        }

        return nil
    }

    enum AnalysisError: LocalizedError {
        case protectedContent

        var errorDescription: String? {
            switch self {
            case .protectedContent:
                "The selected song is protected or unsupported. Choose a decodable audio file."
            }
        }
    }
}

private final class SecurityScopedAccess {
    private let url: URL
    private let didStart: Bool

    init(url: URL) {
        self.url = url
        didStart = url.startAccessingSecurityScopedResource()
    }

    func stop() {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
