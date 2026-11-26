import CoreData
import SwiftUI

struct BookListView: View {
    let persistence: PersistenceController

    @Environment(\.managedObjectContext) private var viewContext

    /// Sections come from `authorName`, a derived attribute the store keeps in step with
    /// `author.name`. A sectioned fetch needs a real stored column to group on, and walking the
    /// relationship in Swift would mean faulting every author just to draw headers.
    @SectionedFetchRequest(
        sectionIdentifier: \Book.authorName,
        sortDescriptors: [
            SortDescriptor(\Book.authorName),
            SortDescriptor(\Book.title)
        ],
        animation: .default
    )
    private var sections: SectionedFetchResults<String?, Book>

    @State private var editing: BookEditorView.Target?
    @State private var showingImportPanel = false

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No books yet",
                        systemImage: "books.vertical",
                        description: Text("Add one, or import a sample library from the toolbar.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Shelfmark")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Library", systemImage: "tray.full") {
                        showingImportPanel = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        editing = .new
                    }
                }
            }
            .sheet(item: $editing) { target in
                BookEditorView(target: target)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingImportPanel) {
                ImportPanel(persistence: persistence)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section(section.id ?? "Unattributed") {
                    ForEach(section) { book in
                        Button {
                            editing = .existing(book.objectID)
                        } label: {
                            BookRow(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        delete(offsets, from: Array(section))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func delete(_ offsets: IndexSet, from books: [Book]) {
        for index in offsets {
            viewContext.delete(books[index])
        }
        save()
    }

    private func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            // A real app surfaces this. Validation failures arrive here as NSDetailedErrorsKey.
            viewContext.rollback()
        }
    }
}

struct BookRow: View {
    @ObservedObject var book: Book

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: book.isFinished ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(book.isFinished ? .green : .secondary)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title ?? "Untitled")
                    .font(.body)
                Text("\(book.pageCount) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
