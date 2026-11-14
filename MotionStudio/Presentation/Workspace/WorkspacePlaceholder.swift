import SwiftUI

/// Standard header strip for workspace panels, with an optional trailing
/// slot for panel-level actions such as importing media.
struct WorkspacePanelHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(WorkspaceTheme.textSecondary)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(WorkspaceTheme.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
    }
}

/// Standard empty-region content for areas that do not have real
/// functionality yet.
///
/// Placeholders describe what will eventually live here and must never
/// imply that unavailable functionality already works (roadmap Milestone 0
/// acceptance criteria).
struct WorkspacePlaceholder: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(WorkspaceTheme.textTertiary)
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WorkspaceTheme.textSecondary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(WorkspaceTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
