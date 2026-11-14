import Foundation

/// The authoritative, versioned JSON manifest of a project package
/// (architecture §6.1, §6.3).
///
/// The envelope carries a stable format identifier and the schema
/// version; the project payload is the document itself. Serialization
/// choices are pinned so files stay byte-stable across app versions:
/// pretty-printed JSON with sorted keys, ISO-8601 dates, and explicit
/// property names for every type.
nonisolated struct ProjectManifest: Codable {
    var format: String
    var schemaVersion: Int
    var project: Project

    private enum CodingKeys: String, CodingKey {
        case format
        case schemaVersion
        case project
    }

    init(format: String, schemaVersion: Int, project: Project) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.project = project
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        project = try container.decode(Project.self, forKey: .project)
    }
}

/// Encodes and decodes project manifests, enforcing the version contract
/// and running explicit migrations (architecture §6.3).
///
/// - Encoding stamps the current schema version and keeps the project's
///   own `schemaVersion` in agreement.
/// - Decoding rejects foreign formats and unsupported future versions
///   safely, then applies migrations in order from the stored version up
///   to the current one.
nonisolated enum ProjectManifestCodec {
    /// Serializes a project to manifest JSON.
    static func encode(_ project: Project) throws -> Data {
        var stamped = project
        stamped.schemaVersion = PackageFormat.currentSchemaVersion

        var updated = stamped
        updated.updatedAt = Date()

        let manifest = ProjectManifest(
            format: PackageFormat.formatIdentifier,
            schemaVersion: PackageFormat.currentSchemaVersion,
            project: updated
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(manifest)
    }

    /// Parses manifest JSON back into a project, validating the format
    /// identifier and schema version and applying migrations.
    static func decode(_ data: Data, packageURL: URL) throws -> Project {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let manifest: ProjectManifest
        do {
            manifest = try decoder.decode(ProjectManifest.self, from: data)
        } catch {
            // Distinguish "wrong file" from "damaged file": valid JSON
            // without our format identifier is a different document.
            if let top = try? JSONSerialization.jsonObject(with: data),
               let dictionary = top as? [String: Any],
               dictionary["format"] == nil {
                throw ProjectFileError.notAProjectFile(packageURL)
            }
            throw ProjectFileError.corruptManifest(packageURL, String(describing: error))
        }

        guard manifest.format == PackageFormat.formatIdentifier else {
            throw ProjectFileError.notAProjectFile(packageURL)
        }

        guard manifest.schemaVersion <= PackageFormat.currentSchemaVersion else {
            throw ProjectFileError.unsupportedSchemaVersion(
                found: manifest.schemaVersion,
                maxSupported: PackageFormat.currentSchemaVersion,
                url: packageURL
            )
        }

        var migrated = manifest
        migrated.schemaVersion = try migrate(migrated, packageURL: packageURL)

        guard migrated.project.schemaVersion == migrated.schemaVersion else {
            throw ProjectFileError.inconsistentSchemaVersion(
                envelope: migrated.schemaVersion,
                project: migrated.project.schemaVersion,
                url: packageURL
            )
        }

        do {
            try migrated.project.composition.validate()
        } catch {
            throw ProjectFileError.invalidProject(packageURL, String(describing: error))
        }

        return migrated.project
    }

    /// Ordered migration steps. The key is the version a step migrates
    /// FROM; a manifest at version N runs steps N, N+1, … until the
    /// current version. Version 1 is the first format, so the registry
    /// is empty for now; the first schema change adds its step here.
    private static func migrate(
        _ manifest: ProjectManifest,
        packageURL: URL
    ) throws -> Int {
        var version = manifest.schemaVersion
        var project = manifest.project

        while version < PackageFormat.currentSchemaVersion {
            guard let step = migrationSteps[version] else {
                throw ProjectFileError.corruptManifest(
                    packageURL,
                    "No migration path from schema version \(version)."
                )
            }
            project = try step(project)
            version += 1
        }

        return version
    }

    private static var migrationSteps: [Int: (Project) throws -> Project] {
        [:]
    }
}
