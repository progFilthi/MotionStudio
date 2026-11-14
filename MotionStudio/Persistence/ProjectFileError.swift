import Foundation

/// Errors raised while reading or validating a project package.
///
/// Every failure is typed and user-explainable; the reader never
/// silently discards project data (architecture §6.2, §15).
nonisolated enum ProjectFileError: Error, LocalizedError {
    /// The manifest file is absent from the package.
    case manifestMissing(URL)

    /// The manifest exists but is not decodable JSON.
    case corruptManifest(URL, String)

    /// The manifest is valid JSON but is not a MotionStudio manifest.
    case notAProjectFile(URL)

    /// The manifest was written by a newer, unsupported schema version.
    case unsupportedSchemaVersion(found: Int, maxSupported: Int, url: URL)

    /// The stored project schemaVersion disagrees with the envelope.
    case inconsistentSchemaVersion(envelope: Int, project: Int, url: URL)

    /// The project data inside a valid manifest failed validation.
    case invalidProject(URL, String)

    var errorDescription: String? {
        switch self {
        case .manifestMissing: "The project file is incomplete"
        case .corruptManifest: "The project file is damaged"
        case .notAProjectFile: "This is not a MotionStudio project file"
        case .unsupportedSchemaVersion: "This project needs a newer version of MotionStudio"
        case .inconsistentSchemaVersion: "The project file is inconsistent"
        case .invalidProject: "The project file contains invalid data"
        }
    }

    var failureReason: String? {
        switch self {
        case .manifestMissing(let url):
            return "'\(url.lastPathComponent)' does not contain a '\(PackageFormat.manifestFileName)' manifest."
        case .corruptManifest(let url, let detail):
            return "The '\(PackageFormat.manifestFileName)' in '\(url.lastPathComponent)' could not be read: \(detail)"
        case .notAProjectFile(let url):
            return "'\(url.lastPathComponent)' is not a MotionStudio project package."
        case .unsupportedSchemaVersion(let found, let maxSupported, let url):
            return "'\(url.lastPathComponent)' uses project format \(found); this version of MotionStudio supports up to \(maxSupported)."
        case .inconsistentSchemaVersion(let envelope, let project, _):
            return "The manifest declares format \(envelope) while the project data declares \(project)."
        case .invalidProject(let url, let detail):
            return "The project data in '\(url.lastPathComponent)' failed validation: \(detail)"
        }
    }
}
