import SwiftUI

/// Top toolbar of the editing workspace.
///
/// Transport, scrubber, and time readout are live for imported media.
/// Undo/redo stay disabled until the command system exists (Milestone 5);
/// they must never appear enabled while they do nothing. Panel toggles are
/// fully functional.
struct WorkspaceToolbar: View {
    let layout: WorkspaceLayoutState
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        HStack(spacing: 16) {
            // Project identity. Editing a project is not implemented yet,
            // so this is a plain label rather than a fake control.
            Text("Untitled Project")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 12)

            PlaybackControlsView(playback: environment.playback)

            Spacer(minLength: 12)

            undoRedoControls
                .disabled(true)
                .foregroundStyle(WorkspaceTheme.textTertiary)
                .help("Undo and redo become available when editing operations are added")

            toolbarDivider

            panelToggles
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WorkspaceTheme.toolbarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
    }

    // MARK: Undo / redo (disabled until Milestone 5)

    private var undoRedoControls: some View {
        HStack(spacing: 14) {
            Button {
                // Intentionally unimplemented: editing operations and the
                // command system arrive in a later milestone.
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .accessibilityLabel("Undo")

            Button {
                // Intentionally unimplemented: editing operations and the
                // command system arrive in a later milestone.
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .accessibilityLabel("Redo")
        }
        .buttonStyle(.plain)
    }

    // MARK: Panel toggles (functional)

    private var panelToggles: some View {
        HStack(spacing: 14) {
            panelToggle(
                systemImage: "sidebar.left",
                isVisible: layout.isMediaBrowserVisible,
                label: "Toggle Media Browser"
            ) {
                layout.toggleMediaBrowser()
            }

            panelToggle(
                systemImage: "list.bullet.rectangle",
                isVisible: layout.isTimelineVisible,
                label: "Toggle Timeline"
            ) {
                layout.toggleTimeline()
            }

            panelToggle(
                systemImage: "sidebar.right",
                isVisible: layout.isInspectorVisible,
                label: "Toggle Inspector"
            ) {
                layout.toggleInspector()
            }
        }
        .buttonStyle(.plain)
    }

    private func panelToggle(
        systemImage: String,
        isVisible: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isVisible ? WorkspaceTheme.accent : WorkspaceTheme.textTertiary)
        }
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isVisible ? [.isSelected] : [])
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(WorkspaceTheme.hairline)
            .frame(width: 1, height: 20)
    }
}
