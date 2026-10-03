#if ENABLE_BROWSERKIT_TRANSFER
import SwiftUI
import UIKit
import BrowserKit

@MainActor
final class ExportCoordinator: ObservableObject {
    @Published var statusText = "Ready to export."
    @Published var isExporting = false

    private var manager: BEBrowserDataExportManager?

    /// Kicks off a fresh export requested from this app's own UI (as opposed to
    /// responding to another browser's import request — see `handleIncomingExportRequest`).
    func startExport(store: BrowsingDataStore, scene: UIWindowScene?) async {
        guard let scene else {
            statusText = "No window scene available yet."
            return
        }
        isExporting = true
        defer { isExporting = false }

        let manager = BEBrowserDataExportManager(scene: scene)
        self.manager = manager

        do {
            let options = try await manager.requestExport(for: store.exportMetadata, token: nil)
            try await stream(options: options, store: store, manager: manager)
        } catch {
            statusText = "Export sheet was cancelled or failed: \(error.localizedDescription)"
        }
    }

    /// Responds to another browser relaunching this app to pull data it requested,
    /// per the `NSUserActivityTypes` continuation handshake documented for BrowserKit.
    func handleIncomingExportRequest(token: UUID, store: BrowsingDataStore, scene: UIWindowScene?) async {
        guard let scene else { return }
        let manager = BEBrowserDataExportManager(scene: scene)
        self.manager = manager
        do {
            let options = try await manager.requestExport(for: store.exportMetadata, token: token)
            try await stream(options: options, store: store, manager: manager)
        } catch {
            statusText = "Incoming export request failed: \(error.localizedDescription)"
        }
    }

    private func stream(options: BEExportOptions, store: BrowsingDataStore, manager: BEBrowserDataExportManager) async throws {
        if options.exportToFiles {
            // The person chose "export to a file" instead of another app.
            // A real browser would write its own file format here; this demo just
            // reports what would have been written.
            statusText = "Would export \(store.bookmarks.count) bookmarks, \(store.historyVisits.count) history entries, \(store.readingListItems.count) reading-list items, and \(store.extensions.count) extensions to a file."
            return
        }

        statusText = "Streaming selected data types…"
        let dataTypes = options.dataTypes

        try await manager.exportBrowserData(AsyncStream<BEBrowserData> { continuation in
            Task {
                if dataTypes.contains(.bookmarks) {
                    for bookmark in store.bookmarks {
                        continuation.yield(BEBrowserDataBookmark(
                            isFolder: bookmark.isFolder,
                            title: bookmark.title,
                            identifier: bookmark.id,
                            url: bookmark.url,
                            parentIdentifier: bookmark.parentIdentifier
                        ))
                    }
                }
                if dataTypes.contains(.history) {
                    for visit in store.historyVisits {
                        continuation.yield(BEBrowserDataHistoryVisit(
                            url: visit.url,
                            dateOfLastVisit: visit.dateOfLastVisit,
                            title: visit.title,
                            loadedSuccessfully: true,
                            httpGet: true,
                            redirectSourceURL: nil,
                            redirectSourceDateOfVisit: nil,
                            redirectDestinationURL: nil,
                            redirectDestinationDateOfVisit: nil,
                            visitCount: visit.visitCount
                        ))
                    }
                }
                if dataTypes.contains(.readingList) {
                    for item in store.readingListItems {
                        continuation.yield(BEBrowserDataReadingListItem(
                            title: item.title,
                            url: item.url,
                            dateOfLastVisit: item.dateOfLastVisit
                        ))
                    }
                }
                if dataTypes.contains(.extensions) {
                    for ext in store.extensions {
                        continuation.yield(BEBrowserDataExtension(
                            displayName: ext.displayName,
                            developerName: ext.developerName,
                            identifier: ext.id,
                            storeIdentifier: ext.storeIdentifier
                        ))
                    }
                }
                continuation.finish()
            }
        })

        statusText = "Export finished."
    }
}

struct ExportView: View {
    @EnvironmentObject var store: BrowsingDataStore
    @EnvironmentObject var coordinator: ExportCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Browsing Data")
                .font(.title2.bold())

            Text("Sends this app's bookmarks, history, reading list, and extensions to another browser (or a file) through BrowserKit's system-provided sheet.")
                .foregroundStyle(.secondary)

            Button {
                Task {
                    let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    await coordinator.startExport(store: store, scene: scene)
                }
            } label: {
                if coordinator.isExporting {
                    ProgressView()
                } else {
                    Text("Start Export")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.isExporting)

            Text(coordinator.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}
#endif
