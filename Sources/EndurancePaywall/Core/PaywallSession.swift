import Foundation

/// The events of one paywall presentation, from shown to closed. Holds no
/// RevenueCat types, so the funnel logic is tested without a store.
///
/// Rules:
/// - `paywall_shown` once, when the offering is known (or the load failed).
/// - Every other event carries the same `source` and `offering_id`.
/// - `paywall_closed` once, with the reason; a close before `shown`
///   still logs `paywall_shown` first so the funnel never has a close
///   without a view.
@MainActor
final class PaywallSession {
    let source: String
    private let analytics: any PaywallAnalytics

    private(set) var offeringId: String?
    private(set) var paywallRevision: Int?
    private(set) var didShow = false
    private(set) var didClose = false
    private(set) var closeReason: PaywallEvent.CloseReason?
    private var packageId: String?
    private var productId: String?

    init(source: String, analytics: any PaywallAnalytics) {
        self.source = source
        self.analytics = analytics
    }

    func shown(offeringId: String?, paywallRevision: Int? = nil) {
        guard !didShow else { return }
        didShow = true
        self.offeringId = offeringId
        self.paywallRevision = paywallRevision
        send(.paywallShown, revision: paywallRevision)
    }

    func purchaseStarted(packageId: String, productId: String) {
        self.packageId = packageId
        self.productId = productId
        send(.purchaseStarted, package: true)
    }

    func purchaseCompleted(isPremium: Bool) {
        if isPremium { closeReason = .purchased }
        send(.purchaseCompleted, package: true, isPremium: isPremium)
    }

    func purchaseCancelled() {
        send(.purchaseCancelled, package: true)
    }

    func purchaseFailed(errorCode: Int) {
        send(.purchaseFailed, package: true, errorCode: errorCode)
    }

    func restoreCompleted(isPremium: Bool) {
        if isPremium { closeReason = .restored }
        send(.restoreCompleted, isPremium: isPremium)
    }

    func restoreFailed(errorCode: Int) {
        send(.restoreFailed, errorCode: errorCode)
    }

    /// Premium became active while the paywall was up (purchase seen through
    /// the customer info stream, or a DEBUG override).
    func premiumUnlocked() {
        if closeReason == nil { closeReason = .purchased }
    }

    /// The X was tapped (the paywall's own or the fallback one).
    func closeRequested() {
        if closeReason == nil { closeReason = .close }
    }

    /// The paywall left the screen. Anything not explained before is a swipe.
    func ended() {
        guard !didClose else { return }
        if !didShow { shown(offeringId: offeringId) }
        didClose = true
        var event = makeEvent(.paywallClosed)
        event.reason = closeReason ?? .swipe
        analytics.track(event)
    }

    private func send(
        _ name: PaywallEvent.Name,
        package: Bool = false,
        revision: Int? = nil,
        errorCode: Int? = nil,
        isPremium: Bool? = nil
    ) {
        var event = makeEvent(name)
        if package {
            event.packageId = packageId
            event.productId = productId
        }
        event.paywallRevision = revision
        event.errorCode = errorCode
        event.isPremium = isPremium
        analytics.track(event)
    }

    private func makeEvent(_ name: PaywallEvent.Name) -> PaywallEvent {
        PaywallEvent(name: name, source: source, offeringId: offeringId)
    }
}
