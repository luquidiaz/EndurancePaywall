import Foundation

/// One paywall analytics event. Names and parameters are the same in every
/// app, so paywall funnels can be compared across the portfolio.
public struct PaywallEvent: Sendable, Equatable {

    public enum Name: String, Sendable, CaseIterable {
        case paywallShown = "paywall_shown"
        case paywallClosed = "paywall_closed"
        case purchaseStarted = "purchase_started"
        case purchaseCompleted = "purchase_completed"
        case purchaseCancelled = "purchase_cancelled"
        case purchaseFailed = "purchase_failed"
        case restoreCompleted = "restore_completed"
        case restoreFailed = "restore_failed"
    }

    /// Why the paywall went away (`paywall_closed`).
    public enum CloseReason: String, Sendable {
        /// The X (the paywall's own or the fallback one).
        case close
        /// Swipe down or any dismissal the paywall didn't ask for.
        case swipe
        case purchased
        case restored
    }

    public var name: Name
    /// Where the paywall was opened from (`onboarding`, `settings`, a feature id...).
    public var source: String
    public var offeringId: String?
    public var packageId: String?
    public var productId: String?
    /// Revision of the dashboard paywall, when RevenueCat exposes it.
    public var paywallRevision: Int?
    public var reason: CloseReason?
    public var errorCode: Int?
    public var isPremium: Bool?

    public init(
        name: Name,
        source: String,
        offeringId: String? = nil,
        packageId: String? = nil,
        productId: String? = nil,
        paywallRevision: Int? = nil,
        reason: CloseReason? = nil,
        errorCode: Int? = nil,
        isPremium: Bool? = nil
    ) {
        self.name = name
        self.source = source
        self.offeringId = offeringId
        self.packageId = packageId
        self.productId = productId
        self.paywallRevision = paywallRevision
        self.reason = reason
        self.errorCode = errorCode
        self.isPremium = isPremium
    }

    /// Parameters ready for Firebase Analytics (snake_case, only the ones set).
    public var parameters: [String: Any] {
        var parameters: [String: Any] = ["source": source]
        if let offeringId { parameters["offering_id"] = offeringId }
        if let packageId { parameters["package_id"] = packageId }
        if let productId { parameters["product_id"] = productId }
        if let paywallRevision { parameters["paywall_revision"] = paywallRevision }
        if let reason { parameters["reason"] = reason.rawValue }
        if let errorCode { parameters["error_code"] = errorCode }
        if let isPremium { parameters["is_premium"] = isPremium ? 1 : 0 }
        return parameters
    }
}

/// Where the app sends paywall events (Firebase, a logger, a test fake).
///
/// `track` is nonisolated on purpose: it can be called from any thread, so
/// an implementation must not assume the main actor.
public protocol PaywallAnalytics: Sendable {
    func track(_ event: PaywallEvent)
}

/// Analytics from a closure: `.init { event in Analytics.logEvent(event.name.rawValue, parameters: event.parameters) }`.
public struct ClosurePaywallAnalytics: PaywallAnalytics {
    private let handler: @Sendable (PaywallEvent) -> Void

    public init(_ handler: @escaping @Sendable (PaywallEvent) -> Void) {
        self.handler = handler
    }

    public func track(_ event: PaywallEvent) {
        handler(event)
    }
}

/// Drops every event (default until the app configures analytics).
public struct NoPaywallAnalytics: PaywallAnalytics {
    public init() {}
    public func track(_ event: PaywallEvent) {}
}
