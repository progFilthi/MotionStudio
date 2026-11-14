import SwiftUI
import UniformTypeIdentifiers

/// The `.motionproject` document for SwiftUI's DocumentGroup.
///
/// A thin `FileDocument` wrapper: all format logic (identity, schema
/// versioning, migrations) lives in `ProjectManifestCodec`, and the
/// document value is a plain struct so SwiftUI bindings drive edits and
/// autosave. The package preserves any `assets/` folder across saves so
/// copied media (future milestone) is never dropped by a manifest-only
/// rewrite.
///
/// `FileDocument` is soft-deprecated in the macOS 27 SDK in favor of the
/// new `Document` protocol, which requires macOS 27; the deployment
/// target is macOS 14, so this wrapper is the compatible choice and is
/// warning-free there. Migrate when the baseline moves.
nonisolated struct ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [PackageFormat.projectType] }
    static var writableContentTypes: [UTType] { [PackageFormat.projectType] }

    var project: Project

    /// A fresh untitled project (DocumentGroup's new-document template).
    init() {
        self.project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
    }

    init(project: Project) {
        self.project = project
    }

    /// Reads a package and decodes its manifest.
    ///
    /// - Throws: typed `ProjectFileError` values for missing manifests,
    ///   foreign formats, unsupported schema versions, and corrupt data.
    init(configuration: ReadConfiguration) throws {
        let wrapper = configuration.file
        // The wrapper filename is the package display name; it is used
        // for error text because the read configuration has no URL.
        let displayName = wrapper.filename
            ?? "Untitled.\(PackageFormat.fileExtension)"
        let packageURL = URL(fileURLWithPath: displayName)

        guard let manifestWrapper = wrapper.fileWrappers?[PackageFormat.manifestFileName],
              let data = manifestWrapper.regularFileContents else {
            throw ProjectFileError.manifestMissing(packageURL)
        }

        do {
            project = try ProjectManifestCodec.decode(data, packageURL: packageURL)
        } catch let error as ProjectFileError {
            throw error
        } catch {
            throw ProjectFileError.corruptManifest(packageURL, String(describing: error))
        }
    }

    /// Builds the package wrapper: the manifest plus any preserved asset
    /// folder from the previously saved snapshot.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try ProjectManifestCodec.encode(project)

        let manifest = FileWrapper(regularFileWithContents: data)
        manifest.preferredFilename = PackageFormat.manifestFileName

        let package = FileWrapper(directoryWithFileWrappers: [:])
        package.addFileWrapper(manifest)

        if let assets = configuration.existingFile?.fileWrappers?[PackageFormat.assetsDirectory] {
            package.addFileWrapper(assets)
        }

        return package
    }
}
