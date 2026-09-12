import Foundation

struct Recording: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let date: Date

    init(url: URL, date: Date) {
        self.id = UUID()
        self.url = url
        self.date = date
    }

    var displayName: String {
        date.formatted(date: .abbreviated, time: .standard)
    }
}
