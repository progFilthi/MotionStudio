import SwiftUI

/// Keyframe animation editing for one text clip (roadmap Milestone 3).
///
/// One row per animatable property (Scale X, Scale Y, Opacity). Each
/// row offers: toggle a keyframe at the playhead (diamond button),
/// remove the whole animation, and — when animated — the keyframe list
/// with per-keyframe value, interpolation, and delete controls.
///
/// Keyframe times are clip-local composition time (0 = the clip's
/// timeline start). New keyframes capture the property's evaluated
/// value at the playhead and default to Linear interpolation.
struct AnimationInspectorSection: View {
    let clip: Clip
    let frameTolerance: MediaTime

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Animation")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(WorkspaceTheme.textSecondary)
                Spacer(minLength: 8)
                Text("Keyframes override the base values at the playhead")
                    .font(.system(size: 10))
                    .foregroundStyle(WorkspaceTheme.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            ForEach(AnimatableProperty.allCases, id: \.self) { property in
                propertyRow(property)
            }

            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
    }

    // MARK: Property rows

    @ViewBuilder
    private func propertyRow(_ property: AnimatableProperty) -> some View {
        let animation = clip.animation(for: property)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    environment.toggleKeyframe(for: property)
                } label: {
                    Image(systemName: animation?.keyframe(near: localPlayheadTime, tolerance: frameTolerance) != nil
                        ? "diamond.fill" : "diamond")
                        .font(.system(size: 10))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(WorkspaceTheme.accent)
                .help("Toggle a keyframe at the playhead")

                Text(property.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WorkspaceTheme.textPrimary)

                Spacer(minLength: 8)

                if animation != nil {
                    Button {
                        environment.removeAnimation(for: property)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 10))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WorkspaceTheme.textSecondary)
                    .help("Remove the animation and all its keyframes")
                } else {
                    Text("not animated")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.textTertiary)
                }
            }

            if let animation {
                keyframeList(property, animation)
            }
        }
    }

    // MARK: Keyframe list

    private func keyframeList(_ property: AnimatableProperty, _ animation: Animation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if animation.keyframes.isEmpty {
                Text("No keyframes — the property holds its base value")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(WorkspaceTheme.textTertiary)
                    .padding(.leading, 24)
            }
            ForEach(animation.keyframes, id: \.time) { keyframe in
                keyframeRow(property, keyframe)
            }
        }
        .padding(.leading, 24)
        .padding(.bottom, 3)
    }

    @ViewBuilder
    private func keyframeRow(_ property: AnimatableProperty, _ keyframe: Keyframe) -> some View {
        let isAtPlayhead = clipHasPlayheadKeyframe(matching: keyframe)
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(isAtPlayhead ? WorkspaceTheme.accent : WorkspaceTheme.hairline)
                .frame(width: 3, height: 16)

            Text(PlaybackTimeFormatting.shortFormat(seconds: keyframe.time.seconds))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textSecondary)
                .frame(width: 44, alignment: .leading)

            if property == .opacity {
                Slider(value: keyframeValueBinding(property, keyframe), in: 0...1)
            } else {
                TextField("1", value: keyframeValueBinding(property, keyframe), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10))
                    .frame(width: 52)
            }

            Picker("Easing", selection: keyframeInterpolationBinding(property, keyframe)) {
                ForEach(Interpolation.allCases, id: \.self) { interpolation in
                    Text(interpolation.displayName).tag(interpolation)
                }
            }
            .labelsHidden()
            .frame(width: 104)

            Button {
                environment.removeKeyframe(for: property, at: keyframe.time)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(WorkspaceTheme.textTertiary)
            .help("Delete this keyframe")
        }
    }

    private func clipHasPlayheadKeyframe(matching keyframe: Keyframe) -> Bool {
        let localTime = environment.playheadTime - clip.timelineStart
        for animation in clip.animations {
            if let hit = animation.keyframe(near: localTime, tolerance: frameTolerance), hit.time == keyframe.time {
                return true
            }
        }
        return false
    }

    private var localPlayheadTime: MediaTime {
        environment.playheadTime - clip.timelineStart
    }

    // MARK: Keyframe bindings

    private func keyframeValueBinding(
        _ property: AnimatableProperty,
        _ keyframe: Keyframe
    ) -> Binding<Double> {
        Binding(
            get: { keyframe.value },
            set: { environment.updateKeyframe(for: property, at: keyframe.time, value: $0) }
        )
    }

    private func keyframeInterpolationBinding(
        _ property: AnimatableProperty,
        _ keyframe: Keyframe
    ) -> Binding<Interpolation> {
        Binding(
            get: { keyframe.interpolation },
            set: { environment.updateKeyframe(for: property, at: keyframe.time, interpolation: $0) }
        )
    }
}
