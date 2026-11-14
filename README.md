# MotionStudio

A native macOS motion-graphics editor written in Swift and SwiftUI.
Projects, media, preview, and export are local-first; editing must work
fully without AI. See `roadmap.md` for the delivery plan and
`architecture.md` for the technical architecture.

**Current status:** Milestone 0 — native application foundation — is
complete. The app builds and launches with a stable workspace shell.
Media import, timeline editing, animation, saving, and AI are not
implemented yet.

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
├── App/                          Entry point, composition root, diagnostics
├── MediaEngine/                  Import, metadata, playback (AVFoundation only)
├── Presentation/                 Workspace, toolbar, panels
└── Resources/                    Asset catalog
Tests/MotionStudioTests/          Unit tests (hosted in the app)
roadmap.md                        Milestone plan and status
architecture.md                   Technical architecture
```

Swift packages (`Packages/Domain`, `Packages/MotionEngine`, …) are
introduced by later milestones as real code requires them; Milestone 0 is
a single app target plus a test target by design.

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
  duration, dimensions, and track counts appear in the media list;
  selecting media loads it into the preview through AVPlayer, with
  working transport, scrubber, and time readout in the toolbar.
- Panels resize via the split views and collapse via the toolbar toggles;
  panel visibility persists across launches.
- Errors are reported through a structured path: technical detail goes to
  the unified log, user-facing wording appears in an alert.

## Diagnostics

Logs use the unified logging system with subsystem
`com.motionstudio.MotionStudio` and categories `app`, `workspace`, and
`media`. Filter in Console.app by that subsystem. Do not log secrets,
API keys, or private media contents.

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
