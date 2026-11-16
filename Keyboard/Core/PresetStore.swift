import Foundation

/// Store only the selected order in the extension's own sandbox.
struct PresetStore {
    private let defaults: UserDefaults
    private let key = "letterOrder"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var order: LetterOrder {
        get { LetterOrder(rawValue: defaults.string(forKey: key) ?? "") ?? .familiar }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
