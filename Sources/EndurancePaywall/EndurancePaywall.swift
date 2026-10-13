import Foundation
import RevenueCat

/// Per-app setup. One value, built once at launch (usually in `AppConfig`).
public struct EndurancePaywallConfiguration: Sendable {
    /// RevenueCat public API key. `nil` = the app configures `Purchases`
    /// itself, or isn't ready yet (premium stays at the cached value and the
    /// paywall shows its "unavailable" placeholder).
    public var apiKey: String?
    public var entitlementId: String
    /// Used only when there is no current offering (transition aid).
    public var fallbackOfferingId: String?
    /// `source` → RevenueCat placement id, to serve another offering per
    /// entry point without a release. Sources not listed use the current
    /// offering. Example: `["onboarding": "onboarding", "settings": "feature"]`.
    public var placements: [String: String]
    /// Placement for every source not in `placements` (optional).
    public var defaultPlacement: String?
    public var premiumCache: PremiumCache?
    public var analytics: any PaywallAnalytics
    /// `Purchases.logLevel = .debug` when the package configures RevenueCat.
    public var verboseLogs: Bool
    /// Seconds the paywall's X stays hidden before it fades in (portfolio
    /// standard: 8). Applies to every phase (loading, failure, "unavailable",
    /// placeholder and the dashboard paywall). Lower it in UI tests if needed.
    public var closeButtonDelay: TimeInterval

    /// Portfolio standard for `closeButtonDelay` (Lucas, 2026-10-12).
    public static let defaultCloseButtonDelay: TimeInterval = 8

    public init(
        apiKey: String?,
        entitlementId: String,
        fallbackOfferingId: String? = nil,
        placements: [String: String] = [:],
        defaultPlacement: String? = nil,
        premiumCache: PremiumCache? = PremiumCache(),
        analytics: any PaywallAnalytics = NoPaywallAnalytics(),
        verboseLogs: Bool = false,
        closeButtonDelay: TimeInterval = EndurancePaywallConfiguration.defaultCloseButtonDelay
    ) {
        self.apiKey = apiKey
        self.entitlementId = entitlementId
        self.fallbackOfferingId = fallbackOfferingId
        self.placements = placements
        self.defaultPlacement = defaultPlacement
        self.premiumCache = premiumCache
        self.analytics = analytics
        self.verboseLogs = verboseLogs
        self.closeButtonDelay = closeButtonDelay
    }

    /// Placement for a source, if any.
    public func placement(for source: String) -> String? {
        placements[source] ?? defaultPlacement
    }
}

/// Entry point: `EndurancePaywall.configure(...)` once at launch, then
/// `.endurancePaywall(isPresented:source:)` anywhere and
/// `EndurancePaywall.premium` for the premium status.
@MainActor
public enum EndurancePaywall {
    public private(set) static var configuration = EndurancePaywallConfiguration(apiKey: nil, entitlementId: "premium")

    /// Shared premium status. Same instance before and after `configure`,
    /// so it can be injected into the environment at any time.
    public static let premium = PremiumState()

    /// RevenueCat is configured (by the package or by the app).
    public static var isPurchasesConfigured: Bool { Purchases.isConfigured }

    /// Call once at launch, before showing any paywall. Configures RevenueCat
    /// when `apiKey` is set and it isn't configured yet.
    public static func configure(_ configuration: EndurancePaywallConfiguration) {
        self.configuration = configuration
        premium.configure(entitlementId: configuration.entitlementId, cache: configuration.premiumCache)
        if let apiKey = configuration.apiKey, !apiKey.isEmpty, !Purchases.isConfigured {
            if configuration.verboseLogs { Purchases.logLevel = .debug }
            Purchases.configure(withAPIKey: apiKey)
        }
        premium.startListening()
    }

    /// Same as `configure(_:)` with analytics from a closure. The closure is
    /// `@Sendable` and nonisolated: it may run off the main thread.
    public static func configure(
        apiKey: String?,
        entitlementId: String,
        fallbackOfferingId: String? = nil,
        placements: [String: String] = [:],
        premiumCache: PremiumCache? = PremiumCache(),
        verboseLogs: Bool = false,
        closeButtonDelay: TimeInterval = EndurancePaywallConfiguration.defaultCloseButtonDelay,
        analytics: @escaping @Sendable (PaywallEvent) -> Void
    ) {
        configure(EndurancePaywallConfiguration(
            apiKey: apiKey,
            entitlementId: entitlementId,
            fallbackOfferingId: fallbackOfferingId,
            placements: placements,
            premiumCache: premiumCache,
            analytics: ClosurePaywallAnalytics(analytics),
            verboseLogs: verboseLogs,
            closeButtonDelay: closeButtonDelay
        ))
    }
}

extension Offerings {
    /// The offering the paywall shows for `source` (placement → current → fallback).
    @MainActor
    public func paywallOffering(for source: String) -> (offering: Offering, origin: PaywallOfferingOrigin)? {
        let configuration = EndurancePaywall.configuration
        return PaywallOfferingResolver.resolve(
            placement: configuration.placement(for: source),
            offeringForPlacement: { currentOffering(forPlacement: $0) },
            current: current,
            fallbackIdentifier: configuration.fallbackOfferingId,
            offeringWithIdentifier: { offering(identifier: $0) }
        )
    }
}
