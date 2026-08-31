import Foundation

/// The one small thing a charm can have done to it.
///
/// The real objects are not ornaments you hang and forget. A daruma waits with
/// a blank eye until the wish it was bought for comes true. A nimbu mirchi dries
/// out and is replaced, traditionally on a Saturday. A guardian weathers and is
/// repainted. Each charm keeps the upkeep its own object actually asks for, so
/// the charm is something tended rather than something merely displayed.
public struct Ritual: Equatable, Sendable {
    /// What the menu calls it — "Hang a Fresh One", "Paint an Eye".
    public let name: String
    /// How long the charm stays fresh once tended, in seconds.
    public let period: TimeInterval
    /// How far it fades once completely untended, from 0 (not at all) to 1
    /// (invisible). Well short of 1: a charm nobody has touched in a month
    /// should look neglected, never disappear.
    public let fade: Double

    /// For a charm the user typed in themselves, which has no tradition of its
    /// own to draw on.
    public static let generic = Ritual(name: "Tend It", days: 10)

    public init(name: String, days: Double, fade: Double = 0.55) {
        self.name = name
        self.period = days * 24 * 60 * 60
        self.fade = fade.clamped(to: 0...0.9)
    }

    /// 1 just after the ritual, falling to 0 once a full period has passed.
    ///
    /// A charm that has never been tended starts fresh rather than derelict:
    /// hanging one up is itself the first observance.
    public func freshness(lastPerformed: Date?, now: Date = Date()) -> Double {
        guard let lastPerformed else { return 1 }
        guard period > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(lastPerformed)
        guard elapsed > 0 else { return 1 }
        return (1 - elapsed / period).clamped(to: 0...1)
    }

    /// What to draw the charm at, given how long it has been left.
    public func opacity(lastPerformed: Date?, now: Date = Date()) -> Double {
        1 - fade * (1 - freshness(lastPerformed: lastPerformed, now: now))
    }

    /// True once it is more than half faded, which is when the menu starts
    /// saying so rather than waiting for the user to notice.
    public func isDue(lastPerformed: Date?, now: Date = Date()) -> Bool {
        freshness(lastPerformed: lastPerformed, now: now) < 0.5
    }
}
