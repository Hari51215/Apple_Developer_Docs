#if ENABLE_BROWSERKIT_TRANSFER
import SwiftUI
import UIKit
import BrowserKit

@MainActor
final class ImportCoordinator: ObservableObject {
    @Published var statusText = "Ready to import."
    @Published var isImporting = false

    private var manager: BEBrowserDataImportManager?

    /// Kicks off an import requested from this app's own UI.
    func startImport(store: BrowsingDataStore, scene: UIWindowScene?) async {
        isImporting = true
        defer { isImporting = false }

        let manager = scene.map(BEBrowserDataImportManager.init(scene:)) ?? BEBrowserDataImportManager()
        self.manager = manager

        do {
            let metadata = BEImportMetadata(supportForImportFromFiles: true)
            let options = try await manager.requestImport(for: metadata)

            if options.importFromFiles {
                statusText = "Person chose to import from a file — present your own file picker here."
            } else {
                statusText = "System is relaunching the source browser to begin the transfer…"
                // The actual data arrives later, when the system relaunches this app
                // with a BEBrowserDataImportManager user activity carrying a token —
                // see `handleIncomingImport(token:)`, wired in WayfarerApp.
            }
        } catch {
            statusText = "Import sheet was cancelled or failed: \(error.localizedDescription)"
        }
    }

    /// Consumes the data stream once the system hands this app a transfer token,
    /// via the `onContinueUserActivity` handler for `BEBrowserDataImportManager.userActivityType`.
    func receiveImport(token: UUID, store: BrowsingDataStore) async {
        guard let manager else {
            statusText = "Received an import token with no active import manager."
            return
        }
        statusText = "Receiving data…"
        var imported = (bookmarks: 0, history: 0, readingList: 0, extensions: 0)
        do {
            for try await item in manager.importBrowserData(token: token) {
                switch item {
                case let bookmark as BEBrowserDataBookmark:
                    store.bookmarks.append(SampleBookmark(
                        isFolder: bookmark.isFolder,
                        title: bookmark.title,
                        url: bookmark.url,
                        parentIdentifier: bookmark.parentIdentifier
                    ))
                    imported.bookmarks += 1
                case let visit as BEBrowserDataHistoryVisit:
                    store.historyVisits.append(SampleHistoryVisit(
                        url: visit.url,
                        title: visit.title,
                        dateOfLastVisit: visit.dateOfLastVisit,
                        visitCount: visit.visitCount
                    ))
                    imported.history += 1
                case let item as BEBrowserDataReadingListItem:
                    store.readingListItems.append(SampleReadingListItem(
                        title: item.title,
                        url: item.url,
                        dateOfLastVisit: item.dateOfLastVisit
                    ))
                    imported.readingList += 1
                case let ext as BEBrowserDataExtension:
                    store.extensions.append(SampleExtension(
                        displayName: ext.displayName,
                        developerName: ext.developerName,
                        storeIdentifier: ext.storeIdentifier
                    ))
                    imported.extensions += 1
                default:
                    break
                }
            }
            statusText = "Imported \(imported.bookmarks) bookmarks, \(imported.history) history entries, \(imported.readingList) reading-list items, \(imported.extensions) extensions."
        } catch {
            statusText = "Import stream failed: \(error.localizedDescription)"
        }
    }
}

struct ImportView: View {
    @EnvironmentObject var store: BrowsingDataStore
    @EnvironmentObject var coordinator: ImportCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Browsing Data")
                .font(.title2.bold())

            Text("Pulls bookmarks, history, reading list, and extensions in from another browser (or a file) through BrowserKit's system-provided sheet.")
                .foregroundStyle(.secondary)

            Button {
                Task {
                    let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    await coordinator.startImport(store: store, scene: scene)
                }
            } label: {
                if coordinator.isImporting {
                    ProgressView()
                } else {
                    Text("Start Import")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.isImporting)

            Text(coordinator.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Text("Currently in store: \(store.bookmarks.count) bookmarks, \(store.historyVisits.count) history entries, \(store.readingListItems.count) reading-list items, \(store.extensions.count) extensions.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}
#endif
