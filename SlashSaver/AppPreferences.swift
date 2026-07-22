import Foundation

final class AppPreferences {
    private enum Key {
        static let targetInputSourceID = "targetInputSourceID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var targetInputSourceID: String? {
        get { defaults.string(forKey: Key.targetInputSourceID) }
        set { defaults.set(newValue, forKey: Key.targetInputSourceID) }
    }
}
