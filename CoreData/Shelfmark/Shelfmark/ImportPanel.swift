import CoreData
import SwiftUI

/// The screen that exercises the parts of Core Data a CRUD form never reaches.
struct ImportPanel: View {
    let persistence: PersistenceController

    @Environment(\.dismiss) private var dismiss

    @State private var bookCount = 0
    @State private var authorCount = 0
    @State private var isWorking = false
    @State private var lastDuration: Duration?
    @State private var errorMessage: String?

    private static let importSize = 5_000

    var body: some View {
        NavigationStack {
            Form {
                Section("In the store") {
                    LabeledContent("Books", value: bookCount.formatted())
                    LabeledContent("Authors", value: authorCount.formatted())
                    if let lastDuration {
                        LabeledContent(
                            "Last operation",
                            value: lastDuration.formatted(.units(allowed: [.seconds, .milliseconds]))
                        )
                    }
                }

                Section {
                    Button("Import \(Self.importSize.formatted()) books") {
                        run { try await LibraryImporter.importSampleLibrary(
                            bookCount: Self.importSize,
                            into: persistence.container
                        ) }
                    }

                    Button("Delete everything", role: .destructive) {
                        run { try await LibraryImporter.removeEverything(from: persistence.container) }
                    }
                } footer: {
                    Text("""
                        The import runs on a private-queue context and saves every \
                        \(LibraryImporter.Constants.batchSize) rows. The delete is an \
                        NSBatchDeleteRequest, which runs as SQL and reports back as object IDs.
                        """)
                }
                .disabled(isWorking)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isWorking {
                    ProgressView().controlSize(.large)
                }
            }
            .onAppear(perform: refreshCounts)
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil

        Task {
            let clock = ContinuousClock()
            do {
                lastDuration = try await clock.measure { try await work() }
            } catch {
                errorMessage = error.localizedDescription
            }
            refreshCounts()
            isWorking = false
        }
    }

    private func refreshCounts() {
        bookCount = persistence.count(ofEntityNamed: "Book")
        authorCount = persistence.count(ofEntityNamed: "Author")
    }
}
