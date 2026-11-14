import SwiftUI

/// Right region: context-sensitive properties for the selection
/// (roadmap Milestone 3).
///
/// Text clips get the full editing inspector; asset clips show
/// read-only metadata — their transform and opacity editing arrives
/// with the compositing milestone, when the render engine can apply it.
struct InspectorPanelView: View {
    let project: Project

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Inspector")
            content
        }
        .frame(minWidth: 260, maxWidth: 400)
        .background(WorkspaceTheme.panelBackground)
    }

    @ViewBuilder
    private var content: some View {
        let selection = project.clip(withID: environment.selectedClipID)?.clip
        if let clip = selection {
            ScrollView {
                if clip.isText {
                    TextClipInspector(clip: clip, frameTolerance: frameTolerance)
                } else {
                    AssetClipSummary(clip: clip)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        } else {
            WorkspacePlaceholder(
                systemImage: "slider.horizontal.3",
                title: "Inspector",
                message: "Select a clip in the timeline to inspect and edit its properties."
            )
        }
    }

    private var frameTolerance: MediaTime {
        project.composition.frameRate.halfFrameDuration
    }
}

// MARK: Asset clip (read-only in Milestone 3)

/// Read-only metadata for an asset clip.
///
/// Honest boundary: applying transforms to video content requires the
/// compositing render engine (roadmap Milestone 4), so video properties
/// display but do not edit yet.
private struct AssetClipSummary: View {
    let clip: Clip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(clip.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WorkspaceTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                summaryRow("Kind", clip.isPlayable ? "Media (AVFoundation)" : "Media")
                summaryRow("Timeline start", PlaybackTimeFormatting.shortFormat(seconds: clip.timelineStart.seconds))
                summaryRow("Duration", PlaybackTimeFormatting.shortFormat(seconds: clip.timelineDuration.seconds))
                summaryRow("Source in", PlaybackTimeFormatting.shortFormat(seconds: clip.sourceIn.seconds))
                summaryRow("Source out", PlaybackTimeFormatting.shortFormat(seconds: clip.sourceOut.seconds))
                summaryRow("Keyframes", clip.animations.isEmpty ? "None" : "\(clip.animations.count) animated properties")
            }

            Text("Transform and opacity editing for media arrives with compositing (Milestone 4); media currently plays full-frame in the preview.")
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
