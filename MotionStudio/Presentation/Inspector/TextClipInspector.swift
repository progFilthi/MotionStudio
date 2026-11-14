import SwiftUI

/// Editing inspector for a selected text clip (roadmap Milestone 3).
///
/// Every control routes through `AppEnvironment.updateSelectedTextClip`,
/// which validates on write, so invalid values are rejected and the
/// control snaps back to the last valid state. Keyframe animation
/// editing lives in `AnimationInspectorSection`.
struct TextClipInspector: View {
    let clip: Clip
    let frameTolerance: MediaTime

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .text(let source) = clip.source {
                contentSection(source)
                typographySection(source.typography)
                transformSection
                AnimationInspectorSection(clip: clip, frameTolerance: frameTolerance)
                clipSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Content

    private func contentSection(_ source: TextSource) -> some View {
        section("Content") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Name")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    TextField("Name", text: nameBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .font(.system(size: 11))
                }
                Text("Text")
                    .font(.system(size: 11))
                    .foregroundStyle(WorkspaceTheme.textSecondary)
                TextEditor(text: textBinding)
                    .font(.system(size: 12))
                    .frame(minHeight: 56)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(WorkspaceTheme.toolbarBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(WorkspaceTheme.hairline, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: Typography

    private func typographySection(_ typography: Typography) -> some View {
        section("Typography") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    TextField("System", text: fontNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .font(.system(size: 11))
                        .help("Font family name; 'System' uses the system font")
                }

                HStack {
                    Text("Size")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    TextField("96", value: fontSizeBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .font(.system(size: 11))
                    Stepper("", value: fontSizeBinding, in: 1...2000, step: 2)
                        .labelsHidden()
                }

                HStack {
                    Text("Weight")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    Picker("Weight", selection: weightBinding) {
                        ForEach(FontWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                HStack {
                    Text("Tracking")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    Slider(value: trackingBinding, in: -20...100)
                        .frame(width: 150)
                    TextField("0", value: trackingBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .font(.system(size: 11))
                }

                HStack {
                    Text("Alignment")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    Picker("Alignment", selection: alignmentBinding) {
                        ForEach(MotionStudio.TextAlignment.allCases, id: \.self) { alignment in
                            Text(alignment.displayName).tag(alignment)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                HStack {
                    Text("Fill")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkspaceTheme.textSecondary)
                    Spacer()
                    ColorPicker("Fill", selection: fillColorBinding, supportsOpacity: true)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: Transform

    private var transformSection: some View {
        section("Transform") {
            VStack(alignment: .leading, spacing: 8) {
                positionRow("Position X", \.transform.positionX)
                positionRow("Position Y", \.transform.positionY)
                positionRow("Anchor X", \.transform.anchorX)
                positionRow("Anchor Y", \.transform.anchorY)
                rotationRow
                scaleRow("Scale X", \.transform.scaleX)
                scaleRow("Scale Y", \.transform.scaleY)
                opacityRow
                Text("Anchor pivots scale and rotation relative to the text bounds; position places the text center. (Preview approximation — canvas-true anchors arrive with the render engine.)")
                    .font(.system(size: 10))
                    .foregroundStyle(WorkspaceTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func positionRow(_ label: String, _ path: WritableKeyPath<Clip, Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textSecondary)
            Spacer()
            Slider(value: doubleBinding(keyPath: path, in: 0...1), in: 0...1)
                .frame(width: 150)
            Text("\(clip[keyPath: path], format: .number.precision(.fractionLength(2)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var rotationRow: some View {
        HStack {
            Text("Rotation")
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textSecondary)
            Spacer()
            Slider(value: doubleBinding(keyPath: \.transform.rotationDegrees, in: -180...180), in: -180...180)
                .frame(width: 150)
            Text("\(clip.transform.rotationDegrees, format: .number.precision(.fractionLength(1)))°")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func scaleRow(_ label: String, _ path: WritableKeyPath<Clip, Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textSecondary)
            Spacer()
            Slider(value: doubleBinding(keyPath: path, in: 0...8), in: 0...8)
                .frame(width: 150)
            Text("\(clip[keyPath: path], format: .number.precision(.fractionLength(2)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var opacityRow: some View {
        HStack {
            Text("Base opacity")
                .font(.system(size: 11))
                .foregroundStyle(WorkspaceTheme.textSecondary)
            Spacer()
            Slider(value: doubleBinding(keyPath: \.opacity, in: 0...1), in: 0...1)
                .frame(width: 150)
            Text("\(clip.opacity, format: .number.precision(.fractionLength(2)))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    // MARK: Clip actions

    private var clipSection: some View {
        section("Clip") {
            VStack(alignment: .leading, spacing: 8) {
                Button(role: .destructive) {
                    environment.deleteSelectedClip()
                } label: {
                    Label("Delete Text Clip", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .help("Remove this clip from the timeline")
            }
        }
    }

    // MARK: Bindings (validated writes through the environment)

    private var nameBinding: Binding<String> {
        Binding(
            get: { clip.name },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.name = newValue } }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.text }
                return ""
            },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.updateText { $0.text = newValue } } }
        )
    }

    private var fontNameBinding: Binding<String> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.typography.fontName }
                return "System"
            },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.updateText { $0.typography.fontName = newValue } } }
        )
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.typography.fontSize }
                return 96
            },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.updateText { $0.typography.fontSize = newValue } } }
        )
    }

    private var trackingBinding: Binding<Double> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.typography.tracking }
                return 0
            },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.updateText { $0.typography.tracking = newValue } } }
        )
    }

    private var weightBinding: Binding<FontWeight> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.typography.weight }
                return .regular
            },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.updateText { $0.typography.weight = newValue } } }
        )
    }

    private var alignmentBinding: Binding<MotionStudio.TextAlignment> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.typography.alignment }
                return .center
            },
            set: { newValue in environment.updateSelectedTextClip { clip in clip.updateText { $0.typography.alignment = newValue } } }
        )
    }

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: {
                if case .text(let source) = clip.source { return source.typography.fillColor.swiftUIColor }
                return .white
            },
            set: { newValue in
                let domain = RGBAColor(newValue)
                environment.updateSelectedTextClip { $0.updateText { $0.typography.fillColor = domain } }
            }
        )
    }

    private func doubleBinding(
        keyPath: WritableKeyPath<Clip, Double>,
        in range: ClosedRange<Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                min(max(clip[keyPath: keyPath], range.lowerBound), range.upperBound)
            },
            set: { newValue in
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                environment.updateSelectedTextClip { $0[keyPath: keyPath] = clamped }
            }
        )
    }

    // MARK: Section scaffold

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(WorkspaceTheme.textSecondary)
            content()
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
    }
}
