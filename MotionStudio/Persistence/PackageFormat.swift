import Foundation
import UniformTypeIdentifiers

/// Constants of the `.motionproject` document package format
/// (architecture §6.1).
///
/// The package is a directory whose authoritative state is a versioned
/// JSON manifest. Render caches and other disposable data never become
/// required project data.
nonisolated enum PackageFormat {
    /// File extension of document packages.
    static let fileExtension = "motionproject"

    /// Name of the manifest file inside the package.
    static let manifestFileName = "manifest.json"

    /// Directory used for media copied into the package.
    static let assetsDirectory = "assets"

    /// Stable identifier embedded in the manifest so unrelated JSON
    /// files are rejected with a clear error.
    static let formatIdentifier = "com.motionstudio.project"

    /// Current project schema version. Bump when the schema changes and
    /// add an explicit, tested migration step (architecture §6.3).
    ///
    /// Version 2 (Milestone 3) added typed text clip sources
    /// (`ClipSource.text`) and per-clip keyframe animations
    /// (`Clip.animations`).
    static let currentSchemaVersion = 2

    /// The uniform type registered for project packages. The identifier
    /// is declared in the application's Info.plist as an exported type.
    static let projectType = UTType(
        exportedAs: "com.motionstudio.project",
        conformingTo: .package
    )

    /// The manifest URL inside a package directory.
    static func manifestURL(inPackage packageURL: URL) -> URL {
        packageURL.appendingPathComponent(manifestFileName)
    }

    /// Creates a new empty package directory (without a manifest).
    static func createPackageDirectory(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent(assetsDirectory),
            withIntermediateDirectories: true
        )
    }
}
