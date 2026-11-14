import SwiftUI

/// Left sidebar: the project's registered media assets with import and
/// add-to-timeline actions.
struct MediaSidebarView: View {
    @Binding var project: Project
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var bindableEnvironment = environment

        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Media") {
                HStack(spacing: 12) {
                    Button {
                        environment.addSelectedAssetToTimeline()
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WorkspaceTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddToTimeline)
                    .help("Add selected media to the timeline")
                    .accessibilityLabel("Add selected media to the timeline")

                    Button {
                        Task { await environment.importMedia() }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WorkspaceTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(environment.isImporting)
                    .help("Import media (⌘I)")
                    .accessibilityLabel("Import media")
                }
            }

            if project.assets.isEmpty {
                WorkspacePlaceholder(
                    systemImage: "square.grid.2x2",
                    title: "No Media Yet",
                    message: "Import a video with the + button or ⌘I. Supported formats: \(MediaFormats.displaySummary)."
                )
            } else {
                List(selection: $bindableEnvironment.selectedAssetID) {
                    ForEach(project.assets) { asset in
                        MediaAssetRow(
                            asset: asset,
                            isMissing: environment.missingAssetIDs.contains(asset.id)
                        )
                        .tag(asset.id)
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

    private var canAddToTimeline: Bool {
        guard let id = environment.selectedAssetID,
              let asset = project.asset(withID: id),
              asset.isFilePresent else {
            return false
        }
        return true
    }
}

/// One asset row: kind icon, name, and inspected metadata.
private struct MediaAssetRow: View {
    let asset: MediaAsset
    let isMissing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: asset.kind == .video ? "film" : "music.note")
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textTertiary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WorkspaceTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(WorkspaceTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(WorkspaceTheme.accent)
                    .help("The file could not be found on disk")
            }
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        var parts: [String] = [
            PlaybackTimeFormatting.format(seconds: asset.duration.seconds),
            "\(asset.pixelWidth)×\(asset.pixelHeight)",
        ]
        if let frameRate = asset.frameRate {
            parts.append(String(format: "%.2f fps", frameRate.framesPerSecond))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
