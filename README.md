# MotionStudio

A native macOS motion-graphics editor written in Swift and SwiftUI.
Projects, media, preview, and export are local-first; editing must work
fully without AI. See `roadmap.md` for the delivery plan and
`architecture.md` for the technical architecture.

**Current status:** Milestone 3 — motion graphics and animation
foundation — is complete. The app builds and launches with a stable
workspace shell, imports MOV/MP4/M4V media with playback, saves and
reopens `.motionproject` packages (schema v2, with a tested v1→v2
migration), and adds typed text layers with typography, transform, and
keyframe animation of scale and opacity over video. Effects, export,
and AI are not implemented yet.

## Requirements

- macOS 14.0 or later
- Xcode 27 (or any Xcode with the macOS 27 SDK and Swift 6.4)
- Swift 6 language mode, deployment target macOS 14.0

## Build and run

### Xcode

1. Open `MotionStudio.xcodeproj`.
2. Select the `MotionStudio` scheme.
3. Press ⌘R.

### Command line

This machine's `xcode-select` may point at Command Line Tools instead of
Xcode. Prefix CLI commands with `DEVELOPER_DIR`, or fix it permanently
(requires administrator privileges):

```sh
sudo xcode-select -s /Applications/Xcode.app
```

Build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MotionStudio.xcodeproj -scheme MotionStudio \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build build
```

Run the test suite:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project MotionStudio.xcodeproj -scheme MotionStudio \
  -destination 'platform=macOS' -derivedDataPath .build
```

The app lands in `.build/Build/Products/Debug/MotionStudio.app`.
`.build/` is ignored by version control.

## Project layout

```
MotionStudio.xcodeproj/
MotionStudio/                     App target sources
├── App/                          Entry point, composition root, document glue
├── Domain/                       Pure domain models (no UI/media frameworks)
├── MediaEngine/                  Import, metadata, playback (AVFoundation only)
├── Persistence/                  Project package format and codec
├── Presentation/                 Workspace, toolbar, timeline, panels
└── Resources/                    Asset catalog
Support/Info.plist                App Info.plist incl. document type registration
Tests/MotionStudioTests/          Unit tests (hosted in the app)
roadmap.md                        Milestone plan and status
architecture.md                   Technical architecture
```

Swift packages (`Packages/Domain`, `Packages/MotionEngine`, …) are
introduced by later milestones as real code requires them; folders are
the current module boundary.

## What the app does right now

- Launches a resizable main window (minimum 1180×760, default 1400×880)
  with a restrained editing workspace that follows the system
  appearance: cohesive light and dark palettes are defined once in
  `WorkspaceTheme`.
- Top toolbar: project title, transport and undo/redo controls (shown
  disabled — those features do not exist yet), and working panel toggles.
- Left media browser, center preview canvas, bottom timeline, and right
  inspector regions, all with honest empty states and sensible minimum
  sizes.
- **Media import and playback (Milestone 1):** import MOV/MP4/M4V videos
  via File > Import Media… (⌘I) or the sidebar + button; inspected
  duration, dimensions, frame rate, and track counts appear in the media
  list; selecting media loads it into the preview through AVPlayer, with
  working transport, scrubber, and time readout in the toolbar. Space
  toggles play/pause.
- **Projects and timeline (Milestone 2):** the app is document-based —
  File > New, Open…, Save (⌘S), Duplicate, Rename, and Open Recent work
  through the native document system. Projects are `.motionproject`
  packages (a directory with a versioned `manifest.json`). Imported
  media registers as project assets referenced by stable UUID; the
  sidebar + button (or selecting media, then the timeline button) places
  a clip on the timeline. The timeline shows a ruler, playhead, track
  rows, and clip blocks; click or drag the ruler to scrub the preview to
  the corresponding time. Missing media files are reported clearly and
  clips are preserved.
- **Text layers and keyframes (Milestone 3):** the timeline header Text
  button (or File > Add Text Layer, ⌘T) places a five-second text clip
  at the playhead on a dedicated text track. The inspector edits the
  text content, font/size/weight/fill/alignment/tracking, transform
  (position, scale, rotation, anchor), and base opacity, and deletes the
  clip. Each property row (Scale X, Scale Y, Opacity) toggles keyframes
  at the playhead — new keyframes capture the current evaluated value —
  and lists keyframes with value, easing (Linear, Ease In/Out/In-Out),
  and delete controls. Timeline clip blocks draw one diamond per
  keyframe time, highlighting under the playhead; scrubbing the playhead
  updates the animated values in the preview live. Evaluation is
  deterministic pure Foundation code (`MotionEngine/`), independent of
  SwiftUI, and keyframes survive save/reopen through schema v2.
- Panels resize via the split views and collapse via the toolbar toggles;
  panel visibility persists across launches.
- Errors are reported through a structured path: technical detail goes to
  the unified log, user-facing wording appears in an alert.

## Diagnostics

Logs use the unified logging system with subsystem
`com.motionstudio.MotionStudio` and categories `app`, `workspace`, and
`media`. Filter in Console.app by that subsystem. Do not log secrets,
API keys, or private media contents.

## Project files

Projects are `.motionproject` **document packages** — directories with
an authoritative, versioned `manifest.json` (`MotionStudio/Persistence/`
owns the format). The manifest is pretty-printed JSON with sorted keys
and ISO-8601 dates so files stay reviewable and byte-stable; assets are
referenced by stable UUID, and future schema versions are rejected
safely while migrations run through an explicit, tested step registry.
Media is currently linked to its original location; copy-into-package
is a later milestone, but the format already distinguishes both
policies.

## Supported media formats

Import accepts MOV, MP4, and M4V containers (`MotionStudio/MediaEngine/
MediaFormats.swift` is the single source of truth); codecs are whatever
AVFoundation plays reliably on the target Mac, typically H.264 and
HEVC. The set is deliberately small and grows only with testing.

The app is currently **not sandboxed** (local development build with
hardened runtime), so user-selected files open directly and
security-scoped bookmarks are unnecessary. Sandboxing and bookmark
handling must be added before any public distribution.

## Documentation

- `roadmap.md` — milestone plan, current status, and known limitations.
- `architecture.md` — subsystems, dependency rules, domain model, and
  coding-agent operating rules.
