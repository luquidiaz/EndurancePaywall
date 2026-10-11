import Foundation

/// When an automatic paywall may appear (the one the app shows on its own,
/// not the onboarding or a locked feature, which always show it).
///
/// Default: after 2 qualifying actions, at most 3 times, 3 days apart.
public struct PaywallTriggerPolicy: Sendable, Equatable {
    /// Qualifying actions (e.g. birthdays added) before each automatic show.
    public var actionsBeforeShow: Int
    /// Automatic shows in the whole life of the install.
    public var maxShows: Int
    /// Minimum time between two automatic shows.
    public var cooldown: TimeInterval

    public init(actionsBeforeShow: Int = 2, maxShows: Int = 3, cooldown: TimeInterval = PaywallTriggerPolicy.days(3)) {
        self.actionsBeforeShow = actionsBeforeShow
        self.maxShows = maxShows
        self.cooldown = cooldown
    }

    public static func days(_ days: Double) -> TimeInterval { days * 86_400 }

    public func shouldShow(_ state: PaywallTriggerState, isPremium: Bool, canPresent: Bool, now: Date) -> Bool {
        guard !isPremium, canPresent else { return false }
        guard state.actionCount >= actionsBeforeShow else { return false }
        guard state.showCount < maxShows else { return false }
        if let lastShown = state.lastShown, now.timeIntervalSince(lastShown) < cooldown { return false }
        return true
    }
}

public struct PaywallTriggerState: Codable, Sendable, Equatable {
    public var actionCount = 0
    public var showCount = 0
    public var lastShown: Date?

    public init(actionCount: Int = 0, showCount: Int = 0, lastShown: Date? = nil) {
        self.actionCount = actionCount
        self.showCount = showCount
        self.lastShown = lastShown
    }
}

/// Persistent counter for one automatic trigger (what Birthday's
/// `PaywallTriggerService` did). Usage:
///
/// ```swift
/// let trigger = PaywallTrigger(id: "birthday_added")
/// if trigger.recordAction(isPremium: premium.isPremium) { showPaywall = true }
/// // in the presentation: .endurancePaywall(isPresented: $showPaywall, source: PaywallSource.automatic)
/// ```
///
/// `recordAction` returning `true` also counts the show.
@MainActor
public final class PaywallTrigger {
    public let id: String
    public let policy: PaywallTriggerPolicy
    private let defaults: UserDefaults
    private var storageKey: String { "endurance_paywall_trigger_\(id)" }

    public init(id: String, policy: PaywallTriggerPolicy = PaywallTriggerPolicy(), defaults: UserDefaults = .standard) {
        self.id = id
        self.policy = policy
        self.defaults = defaults
    }

    public private(set) var state: PaywallTriggerState {
        get {
            guard let data = defaults.data(forKey: storageKey),
                  let state = try? JSONDecoder().decode(PaywallTriggerState.self, from: data) else {
                return PaywallTriggerState()
            }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: storageKey)
            }
        }
    }

    /// Counts a qualifying action. Returns `true` when the paywall should be
    /// shown now; the show is then recorded (count, date, actions reset).
    /// `canPresent: false` keeps it away from critical moments (a running timer).
    @discardableResult
    public func recordAction(isPremium: Bool, canPresent: Bool = true, now: Date = Date()) -> Bool {
        guard !isPremium else { return false }
        var state = self.state
        state.actionCount += 1
        let show = policy.shouldShow(state, isPremium: isPremium, canPresent: canPresent, now: now)
        if show {
            state.showCount += 1
            state.lastShown = now
            state.actionCount = 0
        }
        self.state = state
        return show
    }

    /// Forget everything (e.g. after a refund, or from a debug menu).
    public func reset() {
        defaults.removeObject(forKey: storageKey)
    }
}

/// Standard `source` values. Locked features use their own feature id.
public enum PaywallSource {
    public static let onboarding = "onboarding"
    public static let settings = "settings"
    public static let automatic = "automatic"
    public static let widget = "widget"
}
