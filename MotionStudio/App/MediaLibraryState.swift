import Foundation

/// One entry in the media library.
struct MediaLibraryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let info: ImportedMediaInfo
}

/// Application state for the media library: imported items and selection.
///
/// Milestone 1 scope only; persistence, asset management, and stable asset
/// identity arrive with the project model (Milestone 2).
@MainActor
@Observable
final class MediaLibraryState {
    private(set) var items: [MediaLibraryItem] = []

    var selectedItemID: UUID?

    /// True while an import flow is in progress (panel open or inspecting).
    var isImporting = false

    func add(_ item: MediaLibraryItem) {
        items.append(item)
    }

    func item(withID id: UUID?) -> MediaLibraryItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }
}
