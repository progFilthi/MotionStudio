import SwiftUI

/// Left sidebar: imported media list with the import action.
struct MediaSidebarView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var library = environment.mediaLibrary

        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Media") {
                Button {
                    Task { await environment.importMedia() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Import media (⌘I)")
                .disabled(library.isImporting)
                .accessibilityLabel("Import media")
            }

            if library.items.isEmpty {
                WorkspacePlaceholder(
                    systemImage: "square.grid.2x2",
                    title: "No Media Yet",
                    message: "Import a video with the + button or ⌘I. Supported formats: \(MediaFormats.displaySummary)."
                )
            } else {
                List(selection: $library.selectedItemID) {
                    ForEach(library.items) { item in
                        MediaLibraryRow(item: item)
                            .tag(item.id)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(WorkspaceTheme.panelBackground)
            }
        }
        .frame(minWidth: 220, maxWidth: 380)
        .background(WorkspaceTheme.panelBackground)
    }
}

private struct MediaLibraryRow: View {
    let item: MediaLibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        let duration = PlaybackTimeFormatting.format(seconds: item.info.durationSeconds)
        let size = "\(Int(item.info.naturalSize.width))×\(Int(item.info.naturalSize.height))"
        let tracks: [String] = [
            item.info.videoTrackCount > 0 ? "\(item.info.videoTrackCount) video" : nil,
            item.info.audioTrackCount > 0 ? "\(item.info.audioTrackCount) audio" : nil,
        ].compactMap { $0 }
        return "\(duration) · \(size) · \(tracks.joined(separator: ", "))"
    }
}
