import Combine
import Foundation
import Observation
import RevenueCat

/// Where the last known premium status is kept, so premium users keep
/// access offline and widgets can read it (App Group suite).
public struct PremiumCache: Sendable, Equatable {
    /// `nil` = `UserDefaults.standard`. An App Group id to share with widgets.
    public var suiteName: String?
    /// Last status confirmed by RevenueCat (never a DEBUG override).
    public var statusKey: String
    /// Effective status (with DEBUG override) for widgets. `nil` = not written.
    public var widgetFlagKey: String?

    public init(suiteName: String? = nil, statusKey: String = "revenuecat_premium_cache", widgetFlagKey: String? = "is_premium") {
        self.suiteName = suiteName
        self.statusKey = statusKey
        self.widgetFlagKey = widgetFlagKey
    }

    var defaults: UserDefaults {
        suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }
}

/// Premium status for the whole app. Works with `@Observable`
/// (`@Environment(PremiumState.self)`) and with `ObservableObject`
/// (`@ObservedObject`, `@EnvironmentObject`), whichever the app uses.
@MainActor
@Observable
public final class PremiumState: ObservableObject {
    public private(set) var isPremium: Bool {
        willSet { objectWillChange.send() }
    }
    /// RevenueCat is configured and reporting.
    public private(set) var isConfigured = false {
        willSet { objectWillChange.send() }
    }
    /// Free, trial or premium, as last confirmed by RevenueCat. `nil` until
    /// RevenueCat reports (the cache only keeps `isPremium`). Ignores the
    /// DEBUG override.
    public private(set) var status: PremiumStatus? {
        willSet { objectWillChange.send() }
    }

    /// Called on the main actor whenever `isPremium` changes.
    @ObservationIgnored public var onChange: (@MainActor (Bool) -> Void)?

    #if DEBUG
    /// Forced status for screenshots and manual testing. Never cached.
    public var debugOverride: Bool? {
        didSet { apply(confirmed) }
    }
    #endif

    @ObservationIgnored private(set) var entitlementId: String
    @ObservationIgnored private var cache: PremiumCache?
    @ObservationIgnored private var confirmed: Bool
    @ObservationIgnored private var listener: Task<Void, Never>?

    public init(entitlementId: String = "premium", cache: PremiumCache? = PremiumCache()) {
        self.entitlementId = entitlementId
        self.cache = cache
        let cached = cache.map { $0.defaults.bool(forKey: $0.statusKey) } ?? false
        confirmed = cached
        isPremium = cached
    }

    /// Reconfigure (entitlement and cache) and reload the cached status.
    func configure(entitlementId: String, cache: PremiumCache?) {
        self.entitlementId = entitlementId
        self.cache = cache
        apply(cache.map { $0.defaults.bool(forKey: $0.statusKey) } ?? false)
    }

    /// Follows RevenueCat: purchases made inside RevenueCatUI (or on another
    /// device) unlock at once. Called by `EndurancePaywall.configure`.
    func startListening() {
        guard Purchases.isConfigured, listener == nil else { return }
        isConfigured = true
        listener = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.update(with: info)
            }
        }
    }

    public func update(with customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[entitlementId]
        let isActive = entitlement?.isActive == true
        report(PremiumStatus(isActive: isActive, periodType: entitlement?.periodType))
        apply(isActive)
    }

    /// Keeps `status` and sets the `premium_status` user property when it changes.
    func report(_ newStatus: PremiumStatus) {
        guard newStatus != status else { return }
        status = newStatus
        EndurancePaywall.configuration.analytics.setUserProperty(newStatus.rawValue, forName: PremiumStatus.userPropertyName)
    }

    /// Asks RevenueCat again (e.g. on returning to foreground).
    public func refresh() async {
        guard Purchases.isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() {
            update(with: info)
        }
    }

    /// Restore from a settings button. Returns the status after restoring.
    /// Logs `restore_completed` / `restore_failed` with `source: settings`.
    @discardableResult
    public func restore(source: String = PaywallSource.settings) async -> Bool {
        guard Purchases.isConfigured else { return isPremium }
        let analytics = EndurancePaywall.configuration.analytics
        do {
            let info = try await Purchases.shared.restorePurchases()
            update(with: info)
            analytics.track(PaywallEvent(name: .restoreCompleted, source: source, isPremium: isPremium))
        } catch {
            analytics.track(PaywallEvent(name: .restoreFailed, source: source, errorCode: (error as NSError).code))
        }
        return isPremium
    }

    func apply(_ value: Bool) {
        confirmed = value
        let defaults = cache?.defaults
        if let cache { defaults?.set(value, forKey: cache.statusKey) }
        var effective = value
        #if DEBUG
        if let debugOverride { effective = debugOverride }
        #endif
        if let key = cache?.widgetFlagKey { defaults?.set(effective, forKey: key) }
        guard effective != isPremium else { return }
        isPremium = effective
        onChange?(effective)
    }
}
