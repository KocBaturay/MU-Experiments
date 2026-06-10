@preconcurrency import AVFoundation
import Combine
import Foundation
import MusicUnderstanding
import SwiftUI
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
    @Published private(set) var datasetDocuments: [MusicAnalysisDocument] = []
    @Published private(set) var datasetProgress: DatasetProgress?
    @Published private(set) var exportBundle: AnalysisExportBundle?
    @Published private(set) var datasetExportURL: URL?
    @Published var selectedRoute: LabRoute = .fileLab {
        didSet { showDetailColumn() }
    }
    @Published var isSongImporterPresented = false
    @Published var isFolderImporterPresented = false
    @Published var splitColumnVisibility: NavigationSplitViewVisibility = .automatic
    @Published var preferredCompactColumn: NavigationSplitViewColumn = .sidebar

    private var activeSession: MusicUnderstandingSession?
    private let recentStorageKey = "MusicUnderstandingExperiments.recentAnalyses"

    init() {
        loadRecentAnalyses()
    }

    func analyzeFile(at url: URL, playback: AudioPlaybackStore? = nil) async {
        selectedRoute = .fileLab
        showDetailColumn()
        currentDocument = nil
        await analyzeURL(url, playback: playback, shouldPersistRecent: true, shouldSetCurrent: true)
    }

    func openRecent(_ record: RecentAnalysisRecord, playback: AudioPlaybackStore? = nil) {
        currentDocument = record.document
        selectedRoute = .fileLab
        showDetailColumn()
        state = .ready(record.document.source.name)
        exportBundle = nil

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
        state = .idle
    }

    func showDetailColumn() {
        preferredCompactColumn = .detail
        splitColumnVisibility = .automatic
    }

    func showSidebarColumn() {
        preferredCompactColumn = .sidebar
        splitColumnVisibility = .automatic
    }

    func prepareCurrentExport() {
        guard let currentDocument else { return }

        do {
            exportBundle = try AnalysisExportService.writeExports(for: currentDocument)
        } catch {
            state = .failed("Export failed: \(error.localizedDescription)")
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
        for document in datasetDocuments where !documents.contains(where: { $0.id == document.id }) {
            documents.append(document)
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
        if shouldSetCurrent {
            selectedURL = url
            exportBundle = nil
            state = .loadingAsset(name)
        }

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

            return document
        } catch is CancellationError {
            state = .idle
            return nil
        } catch {
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

        recentAnalyses.removeAll { $0.filePath == record.filePath || $0.document.source.urlString == document.source.urlString }
        recentAnalyses.insert(record, at: 0)
        recentAnalyses = Array(recentAnalyses.prefix(20))
        saveRecentAnalyses()
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
