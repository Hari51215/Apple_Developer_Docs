import CoreData
import SwiftUI

struct BookEditorView: View {
    /// Existing books travel as an `NSManagedObjectID` rather than as the object. The ID is the
    /// stable, queue-agnostic handle; the object is only valid on its own context's queue.
    enum Target: Identifiable, Hashable {
        case new
        case existing(NSManagedObjectID)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let objectID): objectID.uriRepresentation().absoluteString
            }
        }
    }

    let target: Target

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var authorName = ""
    @State private var pageCount = 200
    @State private var isFinished = false
    @State private var errorMessage: String?

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $authorName)
                        .textInputAutocapitalization(.words)
                }

                Section("Details") {
                    Stepper("\(pageCount) pages", value: $pageCount, in: 1...5000, step: 10)
                    Toggle("Finished", isOn: $isFinished)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(isNew ? "New Book" : "Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewContext.rollback()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard case .existing(let objectID) = target,
              let book = try? viewContext.existingObject(with: objectID) as? Book else { return }

        title = book.title ?? ""
        authorName = book.author?.name ?? ""
        pageCount = Int(book.pageCount)
        isFinished = book.isFinished
    }

    private func save() {
        do {
            let book: Book
            switch target {
            case .new:
                book = Book(context: viewContext)
                book.addedAt = Date()
            case .existing(let objectID):
                guard let existing = try viewContext.existingObject(with: objectID) as? Book else {
                    dismiss()
                    return
                }
                book = existing
            }

            book.title = title.trimmingCharacters(in: .whitespaces)
            book.pageCount = Int32(pageCount)
            book.isFinished = isFinished

            let trimmedAuthor = authorName.trimmingCharacters(in: .whitespaces)
            book.author = trimmedAuthor.isEmpty
                ? nil
                : try LibraryImporter.author(named: trimmedAuthor, in: viewContext)

            try viewContext.save()
            dismiss()
        } catch {
            // Validation errors arrive as one NSError wrapping many under NSDetailedErrorsKey.
            let nested = (error as NSError).userInfo[NSDetailedErrorsKey] as? [NSError]
            errorMessage = (nested?.first ?? error as NSError).localizedDescription
        }
    }
}
