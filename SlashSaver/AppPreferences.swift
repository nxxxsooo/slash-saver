import Foundation

final class AppPreferences {
    private enum Key {
        static let targetInputSourceID = "targetInputSourceID"
        static let switchOnEscape = "switchOnEscape"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var targetInputSourceID: String? {
        get { defaults.string(forKey: Key.targetInputSourceID) }
        set { defaults.set(newValue, forKey: Key.targetInputSourceID) }
    }

    var switchOnEscape: Bool {
        get { defaults.bool(forKey: Key.switchOnEscape) }
        set { defaults.set(newValue, forKey: Key.switchOnEscape) }
    }
}
