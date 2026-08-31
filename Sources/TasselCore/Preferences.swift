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
        static let placementKind = "placementKind"
        static let placementX = "placementX"
        static let placementDrop = "placementDrop"
    }

    /// Whether the charm can be grabbed with the pointer. With this off it is
    /// purely decorative and never takes a click.
    public var catchesPointer: Bool {
        get { defaults.object(forKey: Key.catchesPointer) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.catchesPointer) }
    }

    /// Where the charm hangs. Stored as a kind plus two fractions rather than a
    /// point, so it survives a resolution change.
    public var placement: Placement {
        get {
            guard defaults.string(forKey: Key.placementKind) == "fixed" else {
                return .followStatusItem
            }
            return .fixed(
                x: (defaults.object(forKey: Key.placementX) as? Double ?? 0.5).clamped(to: 0...1),
                drop: (defaults.object(forKey: Key.placementDrop) as? Double ?? 0.2).clamped(to: 0...1)
            )
        }
        set {
            switch newValue {
            case .followStatusItem:
                defaults.set("statusItem", forKey: Key.placementKind)
            case let .fixed(x, drop):
                defaults.set("fixed", forKey: Key.placementKind)
                defaults.set(x.clamped(to: 0...1), forKey: Key.placementX)
                defaults.set(drop.clamped(to: 0...1), forKey: Key.placementDrop)
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
        get { (defaults.object(forKey: Key.cordLength) as? Double ?? 92).clamped(to: 32...400) }
        set { defaults.set(newValue.clamped(to: 32...400), forKey: Key.cordLength) }
    }

    public var charmSize: Double {
        get { (defaults.object(forKey: Key.charmSize) as? Double ?? 28).clamped(to: 12...96) }
        set { defaults.set(newValue.clamped(to: 12...96), forKey: Key.charmSize) }
    }
}
