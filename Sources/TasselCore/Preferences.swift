import Foundation

/// Everything the app remembers between launches.
public final class Preferences {
    public static let shared = Preferences(defaults: .standard)

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private enum Key {
        static let charmGlyph = "charmGlyph"
        static let isVisible = "isVisible"
        static let cordLength = "cordLength"
        static let charmSize = "charmSize"
        static let catchesPointer = "catchesPointer"
        static let showsOrnaments = "showsOrnaments"
        static let ritualDates = "ritualDates"
        static let ritualStages = "ritualStages"
        static let placementKind = "placementKind"
        static let placementX = "placementX"
    }

    /// Whether the charm can be grabbed with the pointer. With this off it is
    /// purely decorative and never takes a click.
    public var catchesPointer: Bool {
        get { defaults.object(forKey: Key.catchesPointer) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.catchesPointer) }
    }

    /// Whether beads and a smaller charm are threaded on the rope.
    public var showsOrnaments: Bool {
        get { defaults.object(forKey: Key.showsOrnaments) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showsOrnaments) }
    }

    /// When each charm last had its ritual performed.
    ///
    /// Kept per charm rather than one date for the app, so tending one charm
    /// does not quietly refresh every other one you might switch to.
    public func lastRitual(forCharm glyph: String) -> Date? {
        let stored = defaults.dictionary(forKey: Key.ritualDates) as? [String: Double]
        guard let seconds = stored?[glyph] else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    public func recordRitual(forCharm glyph: String, at date: Date = Date()) {
        var stored = defaults.dictionary(forKey: Key.ritualDates) as? [String: Double] ?? [:]
        stored[glyph] = date.timeIntervalSince1970
        defaults.set(stored, forKey: Key.ritualDates)
    }

    /// How far a staged ritual has got, per charm. 0 for a charm never tended,
    /// which for a daruma means blank — the way one is bought.
    public func ritualStage(forCharm glyph: String) -> Int {
        let stored = defaults.dictionary(forKey: Key.ritualStages) as? [String: Int]
        return max(0, stored?[glyph] ?? 0)
    }

    public func setRitualStage(_ stage: Int, forCharm glyph: String) {
        var stored = defaults.dictionary(forKey: Key.ritualStages) as? [String: Int] ?? [:]
        stored[glyph] = max(0, stage)
        defaults.set(stored, forKey: Key.ritualStages)
    }

    /// Where the charm hangs. Stored as a kind plus two fractions rather than a
    /// point, so it survives a resolution change.
    public var placement: Placement {
        get {
            guard defaults.string(forKey: Key.placementKind) == "fixed" else {
                return .followStatusItem
            }
            return .fixed(x: (defaults.object(forKey: Key.placementX) as? Double ?? 0.5).clamped(to: 0...1))
        }
        set {
            switch newValue {
            case .followStatusItem:
                defaults.set("statusItem", forKey: Key.placementKind)
            case let .fixed(x):
                defaults.set("fixed", forKey: Key.placementKind)
                defaults.set(x.clamped(to: 0...1), forKey: Key.placementX)
            }
        }
    }

    public var charm: Charm {
        get {
            guard let glyph = defaults.string(forKey: Key.charmGlyph) else { return .fallback }
            // A custom glyph the user typed is just as valid as a built-in one.
            return Charm.builtIn.first { $0.glyph == glyph } ?? Charm(glyph: glyph, name: "Custom")
        }
        set { defaults.set(newValue.glyph, forKey: Key.charmGlyph) }
    }

    public var isVisible: Bool {
        get { defaults.object(forKey: Key.isVisible) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.isVisible) }
    }

    public var cordLength: Double {
        get { (defaults.object(forKey: Key.cordLength) as? Double ?? 150).clamped(to: 32...400) }
        set { defaults.set(newValue.clamped(to: 32...400), forKey: Key.cordLength) }
    }

    public var charmSize: Double {
        get { (defaults.object(forKey: Key.charmSize) as? Double ?? 44).clamped(to: 12...96) }
        set { defaults.set(newValue.clamped(to: 12...96), forKey: Key.charmSize) }
    }
}
