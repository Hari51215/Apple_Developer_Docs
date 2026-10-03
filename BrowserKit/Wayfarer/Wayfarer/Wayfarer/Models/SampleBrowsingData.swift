import Combine
import Foundation
import BrowserKit

struct SampleBookmark: Identifiable {
    let id = UUID()
    var isFolder: Bool
    var title: String
    var url: URL?
    var parentIdentifier: UUID?
}

struct SampleHistoryVisit: Identifiable {
    let id = UUID()
    var url: URL
    var title: String
    var dateOfLastVisit: Date
    var visitCount: Int
}

struct SampleReadingListItem: Identifiable {
    let id = UUID()
    var title: String
    var url: URL
    var dateOfLastVisit: Date
}

struct SampleExtension: Identifiable {
    let id = UUID()
    var displayName: String
    var developerName: String
    var storeIdentifier: String?
}

/// Stand-in data for a browser data store this from-scratch project doesn't have.
/// A real browser would back this with its own bookmarks/history/reading-list/extension databases.
final class BrowsingDataStore: ObservableObject {
    @Published var bookmarks: [SampleBookmark]
    @Published var historyVisits: [SampleHistoryVisit]
    @Published var readingListItems: [SampleReadingListItem]
    @Published var extensions: [SampleExtension]

    init() {
        let workFolder = UUID()
        bookmarks = [
            SampleBookmark(isFolder: true, title: "Work", url: nil, parentIdentifier: nil),
            SampleBookmark(isFolder: false, title: "Apple Developer Docs", url: URL(string: "https://developer.apple.com"), parentIdentifier: workFolder),
            SampleBookmark(isFolder: false, title: "Swift Forums", url: URL(string: "https://forums.swift.org"), parentIdentifier: workFolder),
        ]
        historyVisits = [
            SampleHistoryVisit(url: URL(string: "https://developer.apple.com/documentation/browserkit")!, title: "BrowserKit", dateOfLastVisit: .now, visitCount: 4),
            SampleHistoryVisit(url: URL(string: "https://developer.apple.com/documentation/browserenginekit")!, title: "BrowserEngineKit", dateOfLastVisit: .now.addingTimeInterval(-3600), visitCount: 2),
        ]
        readingListItems = [
            SampleReadingListItem(title: "Preparing your app to be the default browser", url: URL(string: "https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser")!, dateOfLastVisit: .now.addingTimeInterval(-86_400)),
        ]
        extensions = [
            SampleExtension(displayName: "Reader Mode Plus", developerName: "Wayfarer Labs", storeIdentifier: "id0000000000"),
        ]
    }

    #if ENABLE_BROWSERKIT_TRANSFER
    var exportMetadata: BEExportMetadata {
        BEExportMetadata(
            supportingExportToFiles: true,
            bookmarksCount: bookmarks.count,
            readingListCount: readingListItems.count,
            historyCount: historyVisits.count,
            extensionsCount: extensions.count
        )
    }
    #endif
}
