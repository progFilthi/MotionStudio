# MotionStudio --- Technical Architecture

> **Status:** Initial architecture baseline.
>
> **Product:** Native macOS motion-graphics editor with a future
> AI-native editing layer.
>
> **Current implementation phase:** Milestone 0 --- native application
> foundation.
>
> **Important:** This document describes the intended architecture. It
> does not mean all described systems should be implemented immediately.
> Follow `roadmap.md` one milestone at a time.

## 1. Architectural overview

MotionStudio is a local-first, native macOS application written in
Swift.

It is a video and motion-graphics editor first. AI will eventually
provide a natural-language control surface over the same editing
operations exposed by the native UI.

The core architectural rule is:

**The project and editing engine own the document. The AI is an optional
client of a validated command interface.**

The editor must continue to function when no AI provider is configured,
when the network is unavailable, or when a model provider changes its
API.

### Major subsystems

1.  **Presentation:** SwiftUI workspace and AppKit desktop integration.
2.  **Application core:** Editor session, state, commands, transactions,
    undo/redo.
3.  **Domain:** Project, composition, tracks, clips, layers, assets,
    timing, animation, and effects.
4.  **Motion engine:** Animation evaluation, interpolation, easing,
    presets, scene graph, typography.
5.  **Media engine:** Import, metadata, playback, decoding, proxies,
    thumbnails, export.
6.  **Rendering engine:** Render graph, compositing, Metal resources,
    preview, cache.
7.  **Persistence:** Project package, serialization, autosave,
    migrations, application metadata.
8.  **Agent engine (later):** Providers, context construction, tool
    registry, validation, execution.

## 2. Technology baseline

  -----------------------------------------------------------------------------
  Concern                 Choice                  Notes
  ----------------------- ----------------------- -----------------------------
  Language                Swift                   Native implementation

  UI                      SwiftUI                 Main workspace and controls

  Desktop integration     AppKit                  Use when SwiftUI lacks
                                                  required
                                                  window/document/interaction
                                                  control

  Deployment target       macOS 14 initially      Verify API availability and
                                                  compatibility before using
                                                  newer APIs

  Build                   Xcode + Swift Package   Avoid unnecessary dependency
                          Manager                 managers

  Concurrency             Swift Concurrency       Actors, async/await,
                                                  structured tasks

  Video playback          AVFoundation / AVPlayer Initial playback
                                                  implementation

  Media timing            Core Media / CMTime     Convert at Apple API
                                                  boundaries

  Image processing        Core Image where useful Not mandatory for every
                                                  effect

  GPU                     Metal                   Introduce as renderer
                                                  requirements justify it

  Typography              Core Text / Core        Text measurement and glyph
                          Graphics                layout

  Encoding                AVFoundation /          Select supported export paths
                          VideoToolbox            based on testing
                          capabilities            

  Project serialization   Codable + versioned     Project manifest is
                          JSON                    authoritative

  App metadata            SQLite when needed      Not the project source of
                                                  truth

  Secrets                 macOS Keychain          Future provider credentials

  Testing                 XCTest                  Unit and integration tests
  -----------------------------------------------------------------------------

Do not assume a particular API is available merely because it exists in
the latest macOS SDK. Check its deployment availability and avoid
deprecated APIs.

## 3. Dependency rules

Use a modular monolith: one macOS application, with internal Swift
packages or clearly separated modules where useful.

Do not create microservices.

### Intended dependency direction

``` text
MotionStudioApp / Presentation
             |
             v
      ApplicationCore
             |
       +-----+--------------------+
       |           |              |
       v           v              v
  MotionEngine  MediaEngine   AgentEngine (later)
       |           |              |
       +-----------+--------------+
                   |
                   v
                 Domain

Persistence is integrated through application-level repository
interfaces and implementations. Domain models must not depend
on persistence implementations.
```

The diagram is conceptual. Avoid forcing every module into a separate
package before the codebase needs it.

### Dependency rules

-   `Domain` must not import SwiftUI, AppKit, AVFoundation, Metal,
    networking frameworks, or SQLite.
-   `Presentation` may import SwiftUI and AppKit.
-   `ApplicationCore` coordinates use cases and depends on domain types
    and abstractions.
-   `MotionEngine` evaluates domain animation and scene data. It should
    not depend on SwiftUI.
-   `MediaEngine` owns media import, playback, decoding, and export
    integrations.
-   `RenderingEngine` owns render graph and GPU composition details.
-   `Persistence` owns project serialization and storage implementation.
-   `AgentEngine` (later) must call application commands, never mutate
    project storage directly.
-   Avoid circular package dependencies.
-   Inject concrete services at the application composition root.

## 4. Application architecture

### Application composition root

The app entry point constructs shared services and injects them into the
workspace.

Keep dependency construction out of SwiftUI view bodies.

Conceptual structure:

``` text
MotionStudioApp
    |
    v
AppEnvironment / DependencyContainer
    |
    +-- ProjectRepository
    +-- MediaImporter
    +-- PlaybackService
    +-- EditorStore
    +-- CommandDispatcher
    +-- ExportCoordinator (later)
    +-- AgentRuntime (later)
    |
    v
WorkspaceView
```

Avoid a global service locator. Prefer explicit initialization and
dependencies that can be replaced in tests.

### Presentation state

Use an application-level `EditorStore`, isolated to `@MainActor`, for
state required by the UI.

Potential state:

-   Current project summary or immutable project snapshot.
-   Current selection.
-   Playback UI state.
-   Current playhead position.
-   Active inspector section.
-   Import/export progress.
-   Undo/redo availability.
-   Agent status when the agent exists.

Do not use SwiftUI `@State` as the authoritative project model. SwiftUI
state should primarily represent local presentation concerns.

Do not publish every decoded frame or high-frequency playback tick as a
broad project-state update. Keep playback/render timing efficient and
narrowly scoped.

## 5. Domain model

The domain model describes what the project means. It must not contain
AVPlayer, AVAsset, MTKView, SwiftUI View, NSView, or other UI/media
implementation objects.

### 5.1 Project hierarchy

``` text
Project
  ├── id
  ├── name
  ├── schemaVersion
  ├── createdAt
  ├── updatedAt
  ├── Composition
  │     ├── id
  │     ├── width
  │     ├── height
  │     ├── frameRate
  │     ├── duration
  │     ├── background
  │     └── Tracks[]
  │            └── Clips[]
  │                   ├── id
  │                   ├── source
  │                   ├── timeline start
  │                   ├── duration
  │                   ├── source in/out
  │                   ├── transform
  │                   ├── opacity
  │                   ├── animations[]
  │                   └── effects[]
  └── Assets[]
```

Start with one composition per project. Keep the model extensible enough
to add more compositions later, but do not implement multi-composition
UI now.

### 5.2 Identity

Use UUIDs for persistent project, composition, track, clip, layer,
asset, animation, keyframe, and command identifiers.

Never use array indices, display names, or timeline positions as
persistent identity. The AI tool system will need stable IDs later.

### 5.3 Time representation

Use rational time in the domain.

``` swift
struct MediaTime: Codable, Hashable, Sendable {
    var value: Int64
    var timescale: Int32

    var seconds: Double {
        guard timescale != 0 else { return 0 }
        return Double(value) / Double(timescale)
    }
}

struct FrameRate: Codable, Hashable, Sendable {
    var numerator: Int32
    var denominator: Int32
}
```

Requirements:

-   Validate that timescales are positive and nonzero.
-   Normalize or compare rational times safely.
-   Convert to `CMTime` at AVFoundation boundaries.
-   Preserve fractional frame rates such as 30000/1001.
-   Define explicit rounding and frame-snapping policies.
-   Avoid using floating-point seconds as the authoritative persisted
    timeline representation.
-   Do not assume all media starts at zero or has the same frame rate as
    the composition.

The `seconds` property is for display and calculations where a
floating-point value is appropriate, not for lossless serialization.

### 5.4 Composition

A composition contains:

-   Width and height.
-   Rational frame rate.
-   Duration.
-   Background color.
-   Ordered tracks.

Validate dimensions, frame rate, duration, and track contents before
rendering or exporting.

### 5.5 Tracks and clips

A track has:

-   Stable ID.
-   Name.
-   Track kind.
-   Visibility and lock state.
-   Ordered clips.

A clip has:

-   Stable ID.
-   Name.
-   Typed source reference.
-   Timeline start.
-   Timeline duration.
-   Source in/out.
-   Transform.
-   Opacity.
-   Animations.
-   Effects.

Keep source time and timeline time distinct. A clip may begin at a
nonzero source time and be placed at a different timeline time.

Avoid adding sophisticated speed ramps, nested sequences, and compound
clips until basic timeline semantics are proven.

### 5.6 Typed layer sources

Use a tagged Codable representation for associated-value enums. Do not
rely on an unstable synthesized JSON representation as the permanent
project file contract.

Conceptual cases:

-   Video asset reference.
-   Image asset reference.
-   Text content.
-   Shape content.

The serialized form should have an explicit discriminator, such as
`kind`, and a versioned payload. Write decoding tests for every case.

### 5.7 Transforms

A visual transform should include:

-   Position X/Y.
-   Scale X/Y.
-   Rotation.
-   Anchor X/Y.

Prefer normalized composition coordinates for position and anchor where
appropriate. Define the coordinate convention once and use it
consistently across UI, animation, preview, and export.

For example, normalized position `(0.5, 0.5)` represents the composition
center. Document whether the Y axis increases upward or downward and
convert at rendering boundaries if needed.

### 5.8 Text content

A text layer should eventually support:

-   Text string.
-   Font family/name.
-   Font size.
-   Weight/style.
-   Fill color.
-   Alignment.
-   Tracking.
-   Line spacing.
-   Optional background.
-   Optional stroke and shadow in later versions.

Use Core Text for accurate measurement and layout. Do not assume SwiftUI
text layout will exactly match exported text.

### 5.9 Animation

An animation has:

-   Stable ID.
-   Target property.
-   Enabled state.
-   Ordered keyframes.

A keyframe has:

-   Stable ID.
-   Rational composition time.
-   Typed or validated value.
-   Interpolation mode.

Initial animatable properties:

-   Position X/Y.
-   Scale X/Y.
-   Rotation.
-   Opacity.

Add blur and tracking only after the initial property system is stable.

Initial interpolation modes:

-   Linear.
-   Cubic Bezier.
-   Spring, only when its evaluation semantics are specified and
    deterministic.

Do not store arbitrary executable expressions in projects.

Use explicit Codable representations for interpolation cases. Validate
keyframe order, duplicate timestamps, finite numeric values, and
property-specific ranges.

### 5.10 Effects

Begin with a small typed effect catalog. Each effect should have a
stable type and validated parameters.

Avoid a generic unvalidated `[String: Double]` dictionary as the
permanent public schema. It can be used temporarily for a prototype, but
move to typed parameter models before the project format becomes
externally relied upon.

## 6. Project file and persistence

### 6.1 Document package

Use a macOS document package with a `.motionproject` extension.

Example:

``` text
Example.motionproject/
    manifest.json
    assets/
        ...
    previews/
        ...
    thumbnail.png
```

The manifest is the authoritative project state.

The package should not contain disposable render caches as required
project data. Cache files may be stored in an application-managed cache
location or a clearly disposable package directory.

### 6.2 Asset handling

Support a clear media policy:

1.  **Linked media:** Project references a user-selected file at its
    original location.
2.  **Copied media:** Application copies the selected asset into the
    project package.

Do not silently copy large media files.

When using user-selected files outside the app sandbox, manage
security-scoped access appropriately. Store bookmarks where required and
handle stale bookmarks.

If a linked asset goes missing, preserve the clip and report the missing
source. Never silently delete project data.

### 6.3 Serialization

-   Use Codable with explicit schema versioning.
-   Keep a stable, documented tagged format for polymorphic types.
-   Make migrations explicit and testable.
-   Reject unsupported future schema versions safely.
-   Use atomic writes or document APIs that provide safe coordinated
    saving.
-   Do not rewrite the project manifest for every playback tick.

### 6.4 NSDocument and SwiftUI

Evaluate `NSDocument` or SwiftUI `DocumentGroup` for native document
lifecycle. Prefer the option that gives adequate control over package
reading/writing, autosave, recovery, and file coordination.

Do not create a custom document framework without a demonstrated need.

### 6.5 SQLite

SQLite is optional for app-level data such as:

-   Recent projects.
-   Search indexes.
-   Asset metadata cache.
-   User preferences that outgrow simple settings storage.

It must not become a second competing source of truth for the project
document.

## 7. Media engine

### 7.1 Import

Responsibilities:

-   File selection.
-   Media validation.
-   Metadata extraction.
-   Asset registration.
-   Security-scoped file access.
-   Error reporting.

Use AVFoundation APIs to inspect assets and tracks. Handle asynchronous
loading and cancellation.

### 7.2 Playback

Start with AVPlayer and an appropriate native video presentation
surface.

Responsibilities:

-   Play/pause.
-   Seek.
-   Current playback time.
-   Duration.
-   Playback state.
-   Error reporting.

Keep the playback service separate from SwiftUI controls.

### 7.3 Timeline playback

Initially, a single source clip can use a straightforward AVPlayer
workflow.

As the timeline becomes multi-clip and composited, introduce a
composition/playback adapter that evaluates the project timeline and
drives the appropriate AVFoundation or custom preview pipeline.

Do not prematurely build a full custom player before the first imported
video can play.

### 7.4 Proxies and thumbnails

Add proxy generation and thumbnail caching only after import/playback
works and profiling or usability demonstrates the need.

Proxies are derived assets. The original media remains untouched.

### 7.5 Export

Export should be an application service, not a view responsibility.

It should support:

-   Export configuration.
-   Progress.
-   Cancellation.
-   Completion.
-   Error reporting.
-   Output validation.

Start with one reliable MP4/H.264 profile. Add more codecs and profiles
after the baseline works.

## 8. Motion and rendering engine

### 8.1 Pure animation evaluation

The animation evaluator should be deterministic and independent of
SwiftUI.

Conceptual interface:

``` swift
protocol AnimationEvaluating: Sendable {
    func evaluate(
        animation: Animation,
        at time: MediaTime
    ) throws -> AnimatableValue
}
```

The exact interface may be adjusted to the implemented value types.

Given the same immutable animation and timestamp, evaluation must
produce the same result.

Responsibilities:

-   Find surrounding keyframes.
-   Handle before-first and after-last-keyframe behavior.
-   Interpolate values.
-   Apply easing.
-   Respect disabled animations.
-   Validate supported property/value combinations.

Define boundary behavior explicitly. Do not leave it to accidental
implementation details.

### 8.2 Presets

Presets are reusable data/templates that generate ordinary editable
animation/keyframe data.

A preset must not be an opaque animation that users cannot inspect or
modify.

Initial candidates:

-   Fade up.
-   Slide in.
-   Spring pop.
-   Scale in.
-   Typewriter.
-   Word-by-word reveal.

Keep preset definitions versioned and validate their parameters.

### 8.3 Scene graph

Begin with ordered flat layers. Introduce parent-child groups only when
the editor needs them.

The scene graph should describe renderable content and ordering, not
contain UI views.

### 8.4 Preview and export consistency

Preview and export must share:

-   Timeline evaluation.
-   Animation evaluation.
-   Transform semantics.
-   Layer order.
-   Text layout rules.
-   Effect semantics.

Preview may use lower resolution, caching, or reduced quality while
interactive. Export uses configured output resolution and quality.

Do not create separate animation implementations for preview and export.

### 8.5 Metal strategy

Do not make the first milestone a Metal renderer.

Start with the smallest reliable preview and export path. Introduce
Metal when the composition requirements and profiling justify it.

When Metal is introduced:

-   Keep GPU resource ownership explicit.
-   Avoid blocking the main thread.
-   Reuse pipelines and textures.
-   Handle device/resource lifecycle.
-   Avoid unnecessary CPU/GPU readbacks.
-   Profile memory and frame time.
-   Keep rendering APIs separate from SwiftUI.

A custom `AVVideoCompositing` implementation may be appropriate for a
later AVFoundation-integrated compositor, but should not be introduced
before the baseline render path is understood.

## 9. Application commands, transactions, and undo/redo

All project mutations should eventually pass through a typed application
command system.

The native UI and future AI agent must use the same application
operations.

Conceptual command examples:

-   Create text layer.
-   Create shape layer.
-   Set transform.
-   Add keyframe.
-   Apply animation preset.
-   Delete layer.
-   Move clip.
-   Trim clip.

### Command execution

A command should:

1.  Validate the target and payload.
2.  Check operation constraints.
3.  Capture the state required for reversal.
4.  Apply the mutation.
5.  Persist or schedule persistence.
6.  Invalidate affected render data.
7.  Return a structured result.

### Transactions

A user-level operation may contain multiple commands.

For example, an animated title may require creating a text layer,
setting its transform, and adding several keyframes. These should form
one transaction and one undo entry.

If any required step fails, roll back the transaction.

### Undo/redo

Use reversible domain operations or stored before/after state for
supported mutations.

Do not implement undo by reloading the entire project for every action.

Keep history bounded and consider periodic snapshots for recovery and
long sessions.

## 10. Concurrency and performance

### 10.1 Thread ownership

  -----------------------------------------------------------------------
  Component                           Suggested isolation
  ----------------------------------- -----------------------------------
  EditorStore                         `@MainActor`

  SwiftUI presentation state          Main actor

  Project repository                  Actor or document-coordinated
                                      service

  Media import                        Actor/service with cancellable
                                      async operations

  Thumbnail generation                Background actor/service

  Agent runtime (later)               Actor

  Export coordinator                  Actor or dedicated service

  Render resources                    Explicit GPU/resource ownership;
                                      avoid unsynchronized shared mutable
                                      state
  -----------------------------------------------------------------------

Use `Sendable` appropriately. Do not silence concurrency warnings with
unchecked annotations without documenting and proving the safety
invariant.

Adopt Swift 6 strict concurrency in stages if needed. Fix ownership and
isolation problems rather than scattering `@unchecked Sendable`.

### 10.2 Performance rules

-   Never perform media decoding or export synchronously on the main
    thread.
-   Do not make network requests from SwiftUI view bodies.
-   Do not send every playback tick through broad project state.
-   Avoid rebuilding the full render graph for unrelated property
    changes.
-   Cache thumbnails and expensive derived results when justified.
-   Use proxies for demanding media after the basic workflow is proven.
-   Keep AI inference and network waiting independent from playback.
-   Cancel obsolete preview work when the playhead moves.
-   Profile before optimizing.

Initial engineering targets are goals, not guarantees:

-   Keep common UI interactions responsive.
-   Aim for 60 FPS UI interactions where practical.
-   Aim for real-time 30 FPS preview on supported, reasonable workloads.
-   Apply local commands without perceptible delay.
-   Ensure export does not block editing UI.

Benchmark on real media and document test hardware, codecs, resolution,
effects, and frame rate.

## 11. Future AI agent architecture

This section is a design target for a later roadmap milestone. Do not
implement it during Milestones 0--6.

### 11.1 Core rule

The model does not edit pixels directly and does not mutate the project
database.

It proposes structured operations using a limited tool registry. The
application validates and executes those operations through the same
command/transaction system used by the UI.

### 11.2 Agent flow

``` text
User prompt
    |
    v
Context builder
    |
    v
Selected AI provider
    |
    v
Structured tool call(s)
    |
    v
Tool and command validation
    |
    v
Application command dispatcher
    |
    v
Transactional project mutation
    |
    +----> Undo history
    |
    +----> Persistence
    |
    +----> Preview invalidation/update
    |
    v
Agent reports what changed
```

### 11.3 Provider abstraction

Define a provider-independent interface for:

-   Provider identity and model selection.
-   Sending messages.
-   Supplying tool definitions.
-   Receiving text and tool calls.
-   Handling cancellation, errors, and streaming if supported.

Implement one provider first. Add additional providers only after the
abstraction is validated.

Do not assume all models support tool calling, structured output, or
image input. Model capabilities must be explicit.

### 11.4 Agent context

Send only relevant context, not the full project on every request.

Possible context:

-   Composition resolution and frame rate.
-   Current playhead time.
-   Selected layer and its properties.
-   Relevant timeline clips.
-   Available presets.
-   Supported operations.
-   Relevant validation constraints.

Visual frame analysis should be optional. Do not upload video or preview
frames to a cloud model without explicit user consent.

### 11.5 Tool registry

Initial future tools may include:

-   `get_project`
-   `get_timeline`
-   `get_selection`
-   `create_text`
-   `create_shape`
-   `set_transform`
-   `animate_property`
-   `apply_preset`
-   `add_keyframe`
-   `remove_keyframe`

Only expose operations that already work reliably through the native
application.

### 11.6 Security

-   Store provider API keys in macOS Keychain.
-   Never send provider keys to a MotionStudio backend.
-   Do not provide unrestricted shell execution.
-   Do not provide arbitrary Swift execution.
-   Do not provide arbitrary filesystem or database write access.
-   Validate every tool argument and target ID.
-   Bound tool-call count, operation count, and payload sizes.
-   Reject non-finite values and out-of-range parameters.
-   Require confirmation for destructive operations and export.
-   Treat model output and external content as untrusted input.

## 12. UI architecture

The workspace should feel like a professional desktop editor, not a chat
interface.

### Main regions

1.  **Toolbar:** Project name, undo/redo, playback controls, export.
2.  **Left sidebar:** Media browser and animation presets.
3.  **Center canvas:** Video preview and selection overlays.
4.  **Bottom timeline:** Ruler, tracks, clips, playhead, keyframes.
5.  **Right inspector:** Context-sensitive properties and, later, the AI
    assistant.

The assistant panel should be collapsible so users can prioritize the
canvas and timeline.

### Interaction principles

-   Drag media into the timeline.
-   Select a layer to inspect it.
-   Edit text directly or through an inspector.
-   Scrub the playhead.
-   Manipulate keyframes.
-   Use standard macOS keyboard shortcuts.
-   Provide contextual menus.
-   Keep AI-generated keyframes visible and manually editable.

The UI should expose real functionality only. Avoid decorative controls
that do nothing.

## 13. Proposed repository organization

Start with a small structure and grow it as milestones require. Do not
create dozens of empty packages and files on day one.

A target organization:

``` text
MotionStudio/
├── MotionStudio.xcodeproj/
├── Package.swift                  # Only if a package manifest is useful
├── README.md
├── roadmap.md
├── architecture.md
│
├── App/
│   ├── MotionStudioApp.swift
│   ├── AppEnvironment.swift
│   └── DependencyContainer.swift
│
├── Packages/
│   ├── Domain/
│   ├── ApplicationCore/
│   ├── MotionEngine/
│   ├── MediaEngine/
│   ├── RenderingEngine/
│   ├── Persistence/
│   ├── DesignSystem/
│   └── AgentEngine/              # Add in the AI milestone, not now
│
├── Presentation/
│   ├── Workspace/
│   ├── Toolbar/
│   ├── MediaBrowser/
│   ├── Preview/
│   ├── Timeline/
│   ├── Inspector/
│   └── Assistant/                # Add later
│
├── Resources/
│   ├── Assets.xcassets/
│   ├── Presets/
│   └── Shaders/
│
└── Tests/
    ├── DomainTests/
    ├── ApplicationCoreTests/
    ├── MotionEngineTests/
    ├── MediaEngineTests/
    ├── PersistenceTests/
    ├── RenderingTests/
    └── IntegrationTests/
```

This is a target, not a demand to create every directory immediately.
Create a module when there is real code and a clear responsibility to
put in it.

## 14. Testing architecture

### Domain tests

-   Rational time comparison and conversion.
-   Frame-rate handling.
-   Serialization and decoding.
-   Validation.
-   Stable tagged enum encoding.
-   Project schema version behavior.

### Motion tests

-   Linear interpolation.
-   Bezier interpolation.
-   Animation boundary behavior.
-   Keyframe ordering.
-   Repeated deterministic evaluation.
-   Preset parameter validation.

### Application tests

-   Command validation.
-   Transaction success and rollback.
-   Undo/redo.
-   Selection behavior.
-   Project mutation invariants.

### Persistence tests

-   Save and reopen.
-   Missing media.
-   Corrupt manifest.
-   Unsupported schema version.
-   Migration behavior.
-   Atomic write/recovery behavior.

### Media and rendering tests

-   Supported media import.
-   Metadata extraction.
-   Seeking.
-   Preview output.
-   Export success and failure.
-   Preview/export consistency.
-   Audio/video synchronization where audio is supported.

Prefer small deterministic fixtures. Do not make every unit test depend
on a large external video file.

## 15. Error handling and diagnostics

Use structured errors at subsystem boundaries.

Errors should communicate:

-   What operation failed.
-   Which asset/project/layer was involved where safe.
-   Whether the user can retry.
-   Whether data was preserved.
-   A useful user-facing explanation.

Keep technical diagnostic details in logs, not in every user-facing
message.

Never silently discard failed imports, project data, or export output.

Do not log API keys, private media contents, or sensitive user data.

## 16. Decisions intentionally left open

These choices should be settled only when a milestone requires them:

-   Exact final minimum macOS version.
-   Whether to use `NSDocument` directly or SwiftUI `DocumentGroup`.
-   Exact custom compositor architecture.
-   Whether a custom `AVVideoCompositing` implementation is necessary.
-   Metal rendering scope and shader organization.
-   SQLite schema, if application metadata needs it.
-   Specific AI providers and models.
-   Automatic update mechanism.
-   Signing and notarization workflow.
-   Lifetime purchase versus subscription pricing.
-   Payment provider and licensing design.

Do not prematurely implement solutions for unresolved decisions.

## 17. Coding-agent operating rules

1.  Read `roadmap.md` and this file before each implementation task.
2.  Work on only the explicitly authorized milestone.
3.  Inspect the repository and existing code before editing.
4.  Preserve existing working behavior.
5.  Do not rewrite the project structure without a concrete reason.
6.  Do not add dependencies merely for convenience.
7.  Do not create empty abstractions for speculative future features.
8.  Do not add payment, account, backend, cloud, or AI code before the
    roadmap calls for it.
9.  Build and test after each meaningful change.
10. Fix regressions introduced by the current task.
11. Update roadmap checkboxes only when work is actually complete.
12. Document deviations from this architecture and explain their
    trade-offs.
13. Do not claim success without build/test evidence.
14. Stop at the end of the authorized milestone and report the next
    recommended step.

### First authorized task

Implement **Milestone 0 only** from `roadmap.md`.

Before changing files, inspect the repository, Xcode version, Swift
version, and existing project structure. Then report the intended
changes.

After implementation, build the app, run tests, update the roadmap,
summarize the result, and stop. Do not begin Milestone 1 without
explicit approval.
