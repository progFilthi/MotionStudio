# MotionStudio --- Product Roadmap

> **Purpose:** This document is the implementation plan for
> MotionStudio, a native macOS motion-graphics editor with an AI-native
> editing workflow.
>
> **Current priority:** Build a reliable local video and motion-graphics
> editor first. Do not implement payments, subscriptions, accounts,
> cloud infrastructure, or AI integrations until the core editing
> workflow works.

## 1. Product vision

MotionStudio is a native macOS application that lets users create
polished motion graphics and edit video through both direct manipulation
and natural-language instructions.

The user should be able to import footage, add text and graphic layers,
animate their properties with keyframes, preview changes interactively,
and export a finished video. Later, users will be able to connect their
own frontier, hosted, or local AI models and ask the application to
perform editing operations.

The product is not intended to replace every feature of Premiere Pro,
Final Cut Pro, DaVinci Resolve, or After Effects in its first release.
Its initial focus is a small set of motion-graphics workflows that are
fast, intuitive, and polished.

### Product principles

1.  **Native macOS first:** Swift, SwiftUI, and AppKit where needed. No
    Electron, webview-based application shell, or cross-platform UI
    framework.
2.  **Editing works without AI:** AI is an optional control layer, not a
    runtime dependency.
3.  **Local-first:** Projects, media, preview, and export work locally.
    No account or cloud service is required for the initial product.
4.  **Non-destructive editing:** Never modify imported source media.
    Store edits as project data.
5.  **Preview and export consistency:** The same timeline evaluation and
    animation semantics must be used for preview and final output.
6.  **Incremental delivery:** Each milestone must produce a working,
    testable application.
7.  **Reversible operations:** Editing actions should support undo/redo.
    A multi-step AI edit should eventually be one undoable transaction.
8.  **Performance is a feature:** Do not block the main thread with
    media decoding, rendering, file I/O, or network calls.
9.  **Keep scope disciplined:** Build the smallest complete editing
    workflow before adding advanced features.

## 2. Current decisions and non-goals

### Decisions

  -----------------------------------------------------------------------
  Area                                Current decision
  ----------------------------------- -----------------------------------
  Product                             Native macOS motion-graphics editor

  Language                            Swift

  UI                                  SwiftUI, with AppKit integration
                                      where necessary

  Initial deployment target           macOS 14, subject to API
                                      availability checks

  Build system                        Xcode and Swift Package Manager

  Concurrency                         Swift Concurrency; adopt strict
                                      checking incrementally

  Video playback                      AVFoundation / AVPlayer

  Media timing                        Core Media / CMTime at
                                      Apple-framework boundaries

  Graphics                            Start with the simplest reliable
                                      native renderer; introduce Metal as
                                      needed

  Typography                          Core Text / Core Graphics as
                                      appropriate

  Project format                      Versioned `.motionproject` document
                                      package

  Project data                        Codable, versioned JSON manifest

  App metadata                        SQLite only when justified; not the
                                      source of truth for a project

  AI                                  Later phase; provider-independent,
                                      bring-your-own-model

  Backend                             None for the initial app

  Payments                            Explicitly out of scope until the
                                      app itself is useful and stable

  Distribution                        Local development first; decide
                                      signing, notarization, and
                                      distribution before public release
  -----------------------------------------------------------------------

### Explicitly out of scope for the first working version

-   Payment processing, subscriptions, lifetime licensing, license
    activation, and account systems.
-   Dodo Payments integration.
-   Cloud sync, collaboration, cloud rendering, or mandatory backend
    services.
-   AI chat, model-provider integrations, autonomous agents, and API-key
    management.
-   Multicam editing.
-   Advanced professional color grading.
-   Rotoscoping, complex masking, and 3D compositing.
-   A plugin marketplace or third-party preset marketplace.
-   Full audio workstation functionality.

Do not add payment code or create payment-related abstractions
pre-emptively. Pricing is undecided and must not influence the initial
architecture.

## 3. Delivery strategy

Build in vertical slices. Do not attempt to implement every package or
feature in one large change.

For every milestone:

1.  Inspect the existing repository and current application state.
2.  Read `ARCHITECTURE.md` and this roadmap.
3.  Confirm the milestone's scope and acceptance criteria.
4.  Implement only that milestone and its necessary foundations.
5.  Build the app and run relevant tests.
6.  Fix regressions before moving forward.
7.  Update this roadmap with completed items and known limitations.
8.  Summarize files changed, decisions made, commands run, test results,
    and the next milestone.

Do not silently skip acceptance criteria. If a requirement cannot be
met, explain why and propose the smallest reasonable alternative before
expanding scope.

## 4. Milestone 0 --- Repository and native application foundation

**Goal:** A clean, launchable native macOS application with a stable
workspace shell.

**Scope**

-   [x] Inspect the repository before changing anything.
-   [x] Create or configure the Xcode macOS application project.
-   [x] Establish the macOS deployment target and Swift language
    settings.
-   [x] Set up Swift Package Manager modules only where they provide a
    useful boundary.
-   [x] Add the application entry point and app environment/dependency
    composition.
-   [x] Create a main window with a minimum sensible size and resizable
    layout.
-   [x] Build a dark, restrained editing workspace.
-   [x] Add the top toolbar, left media sidebar, center preview
    placeholder, bottom timeline placeholder, and right
    inspector/assistant placeholder.
-   [x] Make panels resize or collapse where practical.
-   [x] Add basic app logging and a clear error-reporting approach.
-   [x] Add a README with build and run instructions.
-   [x] Add a minimal test target and verify it runs.

**Do not build yet:** media playback, timeline editing, animation, AI,
database, payments, or complex rendering.

**Acceptance criteria**

-   [x] The application builds and launches from Xcode.
-   [x] The main window resizes without breaking the layout.
-   [x] The workspace regions are visible and have sensible minimum sizes.
-   [x] No placeholder controls falsely claim to perform functionality.
-   [x] The project builds cleanly and the initial tests pass.

**Status:** Completed 2026-11-14. Single app target plus a hosted
unit-test target; no separate Swift packages yet, because no module has
earned a boundary (architecture §13). Swift 6 language mode with
MainActor default isolation on the app target; deployment target macOS
14.0. Sources live under `MotionStudio/` (app) and `Tests/` in the repo
root so the synchronized Xcode groups stay clean of documents.
Transport, undo/redo, import, and export are absent or shown disabled;
no control pretends to work.

**Follow-up (2026-11-14):** all workspace chrome colors are now defined
as explicit light/dark pairs in `WorkspaceTheme` and the app follows the
system appearance instead of forcing dark, so both modes stay cohesive
as the design system grows.

**Known limitations after Milestone 0:**

-   Panel divider positions are not persisted; only per-panel visibility
    is remembered between launches.
-   Collapsing a panel loses its previous width when re-shown.
-   No app icon yet; only an accent color is defined.
-   No custom menu bar commands yet; default SwiftUI menus apply.
-   Interactive resize/collapse behavior is implemented but not covered
    by automated UI tests; unit tests cover the error-reporting and
    panel-visibility state logic.

## 5. Milestone 1 --- Media import and playback

**Goal:** Import a local video and play it in the native preview.

**Scope**

-   [ ] Add a native file-import flow using macOS file selection APIs.
-   [ ] Support a small, explicitly documented initial set of common
    video formats, starting with formats supported by AVFoundation on
    the target Mac.
-   [ ] Use AVURLAsset/AVFoundation APIs to inspect media metadata.
-   [ ] Display duration, dimensions, and available video/audio tracks.
-   [ ] Integrate AVPlayer for playback.
-   [ ] Add play, pause, and seek controls.
-   [ ] Add a time display and playback progress indicator.
-   [ ] Handle missing files, unsupported media, permission failures,
    and decode errors.
-   [ ] Keep media work off the main thread where appropriate.
-   [ ] Preserve access to user-selected files using appropriate
    security-scoped access handling when needed.

**Acceptance criteria**

-   A user can import a supported local video.
-   The video appears in the preview and plays.
-   Play, pause, and seeking work.
-   The UI remains responsive during playback and metadata loading.
-   Errors are understandable and do not crash the application.

## 6. Milestone 2 --- Project model, timeline foundation, and saving

**Goal:** Represent a simple edit as project data and persist it.

**Scope**

-   [ ] Implement versioned domain models for Project, Composition,
    Track, Clip, MediaAsset, and media time.
-   [ ] Use stable UUID identifiers for persistent entities.
-   [ ] Represent timeline time with rational values (value/timescale);
    convert to CMTime at AVFoundation boundaries.
-   [ ] Define explicit, stable Codable serialization for enums with
    associated values.
-   [ ] Create a `.motionproject` document package format.
-   [ ] Store the authoritative project manifest as versioned JSON.
-   [ ] Define how imported assets are referenced.
-   [ ] Offer a clear distinction between linking to original media and
    copying media into a project, if both are implemented.
-   [ ] Implement a basic timeline ruler, playhead, track rows, and clip
    blocks.
-   [ ] Place an imported video clip on a track.
-   [ ] Connect timeline seeking to preview playback.
-   [ ] Implement save, reopen, and basic missing-media handling.
-   [ ] Add project format migration/version validation foundations.

**Acceptance criteria**

-   A user can create a project and add an imported video as a timeline
    clip.
-   The timeline shows the clip at the correct start and duration.
-   Moving the playhead seeks the preview to the corresponding time.
-   Saving and reopening restores the project and its timeline.
-   Project data does not depend on transient SwiftUI view state.
-   A missing source file is reported clearly rather than silently
    discarded.

## 7. Milestone 3 --- Motion graphics and animation foundation

**Goal:** Add a text layer and animate it over video.

**Scope**

-   [ ] Add a typed text-layer model.
-   [ ] Add text creation, editing, selection, and deletion.
-   [ ] Add typography controls for text, font, size, weight, color,
    alignment, and tracking where supported.
-   [ ] Add a transform model for position, scale, rotation, anchor, and
    opacity.
-   [ ] Define a reusable animatable-property model.
-   [ ] Implement keyframes with rational timeline timestamps.
-   [ ] Implement deterministic animation evaluation at arbitrary
    timestamps.
-   [ ] Implement linear interpolation and cubic Bezier easing.
-   [ ] Add scale and opacity animation first.
-   [ ] Display keyframes in the timeline.
-   [ ] Allow the playhead to scrub animation accurately.
-   [ ] Keep the animation evaluator independent of SwiftUI.
-   [ ] Add unit tests for interpolation, easing, boundary conditions,
    and frame-time conversion.

**Acceptance criteria**

-   A user can add a text layer over video.
-   A user can change its typography and transform.
-   A user can create scale and opacity keyframes.
-   Scrubbing the playhead produces the correct animated values.
-   Evaluating the same project state at the same timestamp produces the
    same result.
-   The animation model can be saved and reopened without losing
    keyframes.

## 8. Milestone 4 --- Compositing, preview quality, and export

**Goal:** Render the project as a finished video.

**Scope**

-   [ ] Define a shared render/evaluation interface used by preview and
    export.
-   [ ] Composite source video and text graphics in the correct layer
    order.
-   [ ] Implement a reliable preview rendering path.
-   [ ] Introduce Metal for GPU-backed composition where it provides
    measurable value.
-   [ ] Avoid introducing a custom AVVideoCompositing implementation
    until the baseline render path and requirements are understood.
-   [ ] Implement an export pipeline using appropriate AVFoundation
    APIs.
-   [ ] Support a first export profile such as H.264 MP4 at the
    composition's configured resolution and frame rate.
-   [ ] Add export progress, completion, cancellation, and error states.
-   [ ] Verify that preview and exported output use the same animation
    evaluation rules.
-   [ ] Add a small set of render and export integration tests.

**Acceptance criteria**

-   The exported video contains the source footage and animated text.
-   Text placement, timing, easing, and opacity match the preview within
    expected rendering tolerances.
-   Export does not freeze the interface.
-   Export errors and cancellation are handled cleanly.
-   The output can be opened in a standard video player.

## 9. Milestone 5 --- Editing operations, undo/redo, and usability

**Goal:** Make the editor usable without AI.

**Scope**

-   [ ] Introduce an application-level editor state/store.
-   [ ] Define typed editor commands for supported operations.
-   [ ] Implement transactional command execution.
-   [ ] Implement undo and redo for supported editing operations.
-   [ ] Make multi-step operations undoable as a single transaction
    where appropriate.
-   [ ] Add clip selection and basic movement.
-   [ ] Add basic trim/split operations only after timing and playback
    behavior are reliable.
-   [ ] Add keyboard shortcuts for common actions.
-   [ ] Add autosave and recovery foundations.
-   [ ] Add useful empty states and validation messages.
-   [ ] Test undo/redo, command rollback, save/reopen, and timeline
    consistency.

**Acceptance criteria**

-   Core editing operations work through both the UI and application
    command layer.
-   Undo/redo restores the expected project state.
-   A failed multi-step transaction does not leave a partially modified
    project.
-   The app can recover a saved project after a normal restart.

## 10. Milestone 6 --- Animation preset library

**Goal:** Make polished motion graphics quick to create.

**Scope**

-   [ ] Define a versioned animation-preset format.
-   [ ] Create a small curated set of presets: fade up, slide in, spring
    pop, scale in, typewriter, and word-by-word reveal where supported.
-   [ ] Make presets parameterizable by duration, delay, direction, and
    intensity where applicable.
-   [ ] Apply presets through the same command system as manual edits.
-   [ ] Show preset previews or clear descriptions.
-   [ ] Allow users to adjust the generated keyframes afterward.
-   [ ] Test preset output at different frame rates and durations.

**Acceptance criteria**

-   Presets produce deterministic, editable keyframes.
-   Presets work at supported composition frame rates.
-   Users can manually modify preset-generated animation.
-   Applying a preset is undoable.

## 11. Milestone 7 --- AI agent integration

**Goal:** Let users edit supported project features through natural
language.

This milestone starts only after the underlying editing operations are
reliable.

**Scope**

-   [ ] Define a provider-independent AIProvider interface.
-   [ ] Implement one provider first, then add more only after the
    interface is proven.
-   [ ] Add secure API-key storage using macOS Keychain.
-   [ ] Add provider/model configuration.
-   [ ] Build a compact project-context snapshot containing only
    relevant project, selection, timeline, and supported-feature
    information.
-   [ ] Define a typed tool registry.
-   [ ] Expose read-only inspection tools first.
-   [ ] Add editing tools for text creation, transforms, keyframes, and
    animation presets.
-   [ ] Validate every tool call before execution.
-   [ ] Execute edits through the existing command/transaction system.
-   [ ] Group one user request's related edits into one undoable
    transaction.
-   [ ] Display agent progress and explain what changed.
-   [ ] Handle provider errors, timeouts, malformed tool arguments, and
    unsupported model capabilities.
-   [ ] Never give the model unrestricted shell, filesystem, database,
    or code execution access.
-   [ ] Require confirmation for destructive operations and export
    actions.
-   [ ] Make cloud visual analysis opt-in; do not upload project media
    by default.

**Acceptance criteria**

-   A user can connect a supported model.
-   A natural-language request can create or animate a text layer using
    registered tools.
-   The result appears in the timeline and preview.
-   The user can inspect and manually adjust the generated result.
-   One AI request can be undone as one action.
-   Invalid or unsupported model tool calls are rejected safely.
-   Editing still works when no model is configured or the network is
    unavailable.

## 12. Milestone 8 --- Performance and product polish

**Goal:** Prepare a reliable private beta.

**Scope**

-   [ ] Profile UI responsiveness, playback, memory, and export.
-   [ ] Add thumbnail and frame caching where profiling justifies it.
-   [ ] Add proxy generation for appropriate media workloads.
-   [ ] Add targeted render invalidation rather than rebuilding
    unrelated content.
-   [ ] Improve timeline interaction and keyboard navigation.
-   [ ] Add project recovery and robust autosave.
-   [ ] Test long projects and repeated import/export cycles.
-   [ ] Improve onboarding and model setup if AI is included in the
    beta.
-   [ ] Add accessibility labels and sensible keyboard focus behavior.
-   [ ] Document supported codecs, resolutions, frame rates, and known
    limitations.

**Acceptance criteria**

-   No known data-loss issue in normal save/reopen workflows.
-   Playback, editing, and export do not block the main UI.
-   The application handles unsupported or missing media gracefully.
-   A new user can complete the main workflow without developer
    assistance.

## 13. Later productization --- deliberately deferred

Only after the editor has real users and a stable core should the team
evaluate:

-   Developer ID signing and notarization.
-   Automatic updates.
-   Public website and download flow.
-   Crash reporting and opt-in diagnostics.
-   Licensing and payment processing.
-   Lifetime purchase versus annual subscription pricing.
-   Dodo Payments suitability and integration.
-   License recovery and customer support.
-   Additional AI providers and local model integrations.
-   Advanced effects, masking, audio, and more sophisticated editing.

No pricing decision is final. The possible one-time lifetime price
discussed so far (\$15--\$20) and a possible annual subscription are
hypotheses, not implementation requirements. Revisit pricing only after
product scope, ongoing maintenance costs, and customer demand are better
understood.

## 14. Definition of a successful first public release

The first public release should allow a user to:

1.  Install and launch the native macOS app.
2.  Create and save a project.
3.  Import a local video.
4.  Play, pause, and scrub the footage.
5.  Add and edit a text layer.
6.  Animate text using keyframes and easing.
7.  Apply at least a few polished motion presets.
8.  Preview the composition.
9.  Export a working MP4.
10. Reopen the project and continue editing.

AI integration is a major differentiator, but it must not compromise the
reliability of the underlying editor. If AI is included in the first
public release, it must use the same validated editing command system
and remain optional.

## 15. Instructions to the coding agent

Treat this roadmap as an incremental execution plan, not a request to
implement every milestone in one pass.

For the first task, implement **Milestone 0 only**.

Before editing:

-   Inspect the repository and report whether it is empty or already
    contains code.
-   Identify the available Xcode and Swift versions.
-   Check the current project structure.
-   Read `ARCHITECTURE.md`.
-   State the exact files and targets you intend to create or modify.

During implementation:

-   Keep the diff focused.
-   Prefer simple, testable code over speculative abstractions.
-   Do not add dependencies without a concrete need.
-   Do not implement future milestones early.
-   Do not add payments, authentication, a backend, AI, or cloud
    services.
-   Do not claim a feature works unless it has been built and tested.

Before finishing:

-   Build the application.
-   Run the tests that exist.
-   Fix all errors introduced by the change.
-   Update this roadmap's checkboxes only for work actually completed.
-   Report the build and test results, remaining limitations, and the
    next recommended milestone.

**Stop after Milestone 0. Wait for review and explicit instruction
before starting Milestone 1.**
