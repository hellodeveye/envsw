import SwiftUI
import iEnvsCore

struct FocusedProfileKey: FocusedValueKey {
    typealias Value = ProfileRef?
}

extension FocusedValues {
    var selectedProfile: ProfileRef? {
        get { self[FocusedProfileKey.self] ?? nil }
        set { self[FocusedProfileKey.self] = newValue }
    }
}

struct FocusedGroupKey: FocusedValueKey {
    typealias Value = String?
}

extension FocusedValues {
    var selectedGroup: String? {
        get { self[FocusedGroupKey.self] ?? nil }
        set { self[FocusedGroupKey.self] = newValue }
    }
}

struct FocusedAppStateKey: FocusedValueKey {
    typealias Value = AppState?
}

extension FocusedValues {
    var appState: AppState? {
        get { self[FocusedAppStateKey.self] ?? nil }
        set { self[FocusedAppStateKey.self] = newValue }
    }
}
