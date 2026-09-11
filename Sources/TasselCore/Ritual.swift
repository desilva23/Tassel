import Foundation

/// The one small thing a charm can have done to it.
///
/// The real objects are not ornaments you hang and forget. A daruma waits with
/// a blank eye until the wish it was bought for comes true. A nimbu mirchi dries
/// out and is replaced, traditionally on a Saturday. A guardian weathers and is
/// repainted. Each charm keeps the upkeep its own object actually asks for, so
/// the charm is something tended rather than something merely displayed.
public struct Ritual: Equatable, Sendable {
    /// What the ritual is called — "Hang a Fresh One", "Paint an Eye".
    public let name: String
    /// For a ritual that moves a charm through stages rather than keeping it
    /// fresh. Empty for the ordinary kind.
    ///
    /// Some of these objects are not maintained, they are *progressed*. A daruma
    /// is bought blank, has one eye painted when a wish is made and the other
    /// when it comes true. Fading would be exactly wrong for it: a daruma
    /// sitting with one eye open for months is the whole point, not neglect.
    public let stages: [RitualStage]
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
        self.stages = []
    }

    /// A ritual that advances through `stages` in order, and starts over after
    /// the last. It never fades and is never due.
    public init(name: String, stages: [RitualStage]) {
        self.name = name
        self.period = 0
        self.fade = 0
        self.stages = stages
    }

    public var isStaged: Bool { !stages.isEmpty }

    /// The stage at `index`, wrapping rather than trapping: a stored index can
    /// outlive a change to how many stages there are.
    public func stage(at index: Int) -> RitualStage? {
        guard isStaged else { return nil }
        let count = stages.count
        return stages[((index % count) + count) % count]
    }

    /// Where performing the ritual at `index` leads. After the last stage it
    /// begins again — a granted daruma is retired and a new one bought blank.
    public func stage(after index: Int) -> Int {
        guard isStaged else { return 0 }
        let count = stages.count
        return (((index % count) + count) % count + 1) % count
    }

    /// 1 just after the ritual, falling to 0 once a full period has passed.
    ///
    /// A charm that has never been tended starts fresh rather than derelict:
    /// hanging one up is itself the first observance.
    public func freshness(lastPerformed: Date?, now: Date = Date()) -> Double {
        guard !isStaged else { return 1 }
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
        !isStaged && freshness(lastPerformed: lastPerformed, now: now) < 0.5
    }
}

/// One step of a ritual that advances rather than fades.
public struct RitualStage: Equatable, Sendable {
    /// What the menu offers while the charm is at this stage — the act that
    /// moves it on to the next one.
    public let action: String
    /// The artwork to show at this stage.
    public let artwork: String

    public init(action: String, artwork: String) {
        self.action = action
        self.artwork = artwork
    }
}
