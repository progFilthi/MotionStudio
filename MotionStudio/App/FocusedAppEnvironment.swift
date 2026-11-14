import SwiftUI

/// Exposes the focused window's application environment to scene-level
/// commands (File > Import Media…).
///
/// Each document window owns its environment, so commands must resolve
/// through focus rather than a global instance.
nonisolated struct AppEnvironmentKey: FocusedValueKey {
    typealias Value = AppEnvironment
}

extension FocusedValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
