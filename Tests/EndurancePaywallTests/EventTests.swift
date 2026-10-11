import Foundation
import Testing
@testable import EndurancePaywall

@Suite("Events")
@MainActor
struct EventTests {
    @Test func purchaseFunnelCarriesSourceOfferingAndPackage() {
        let analytics = RecordingAnalytics()
        let session = PaywallSession(source: "onboarding", analytics: analytics)
        session.shown(offeringId: "v3_standard_annual", paywallRevision: 4)
        session.shown(offeringId: "ignored")
        session.purchaseStarted(packageId: "$rc_annual", productId: "app.annual")
        session.purchaseCompleted(isPremium: true)
        session.ended()
        session.ended()

        #expect(analytics.names == [.paywallShown, .purchaseStarted, .purchaseCompleted, .paywallClosed])
        #expect(analytics.events.allSatisfy { $0.source == "onboarding" && $0.offeringId == "v3_standard_annual" })
        #expect(analytics.events[0].paywallRevision == 4)
        #expect(analytics.events[1].packageId == "$rc_annual")
        #expect(analytics.events[2].productId == "app.annual")
        #expect(analytics.events[2].isPremium == true)
        #expect(analytics.events[3].reason == .purchased)
    }

    @Test func cancelFailAndClose() {
        let analytics = RecordingAnalytics()
        let session = PaywallSession(source: "export", analytics: analytics)
        session.shown(offeringId: "o")
        session.purchaseStarted(packageId: "$rc_weekly", productId: "w")
        session.purchaseCancelled()
        session.purchaseStarted(packageId: "$rc_weekly", productId: "w")
        session.purchaseFailed(errorCode: 2)
        session.closeRequested()
        session.ended()
        #expect(analytics.names == [.paywallShown, .purchaseStarted, .purchaseCancelled, .purchaseStarted, .purchaseFailed, .paywallClosed])
        #expect(analytics.events[2].packageId == "$rc_weekly")
        #expect(analytics.events[4].errorCode == 2)
        #expect(analytics.events[5].reason == .close)
    }

    @Test func restoreEvents() {
        let analytics = RecordingAnalytics()
        let session = PaywallSession(source: "settings", analytics: analytics)
        session.shown(offeringId: "o")
        session.restoreFailed(errorCode: 7)
        session.restoreCompleted(isPremium: false)
        session.restoreCompleted(isPremium: true)
        session.ended()
        #expect(analytics.names == [.paywallShown, .restoreFailed, .restoreCompleted, .restoreCompleted, .paywallClosed])
        #expect(analytics.events[2].isPremium == false)
        #expect(analytics.events[4].reason == .restored)
    }

    @Test func swipeIsTheDefaultAndCloseBeforeLoadStillLogsShown() {
        let analytics = RecordingAnalytics()
        let session = PaywallSession(source: "automatic", analytics: analytics)
        session.ended()
        #expect(analytics.names == [.paywallShown, .paywallClosed])
        #expect(analytics.events[1].reason == .swipe)
    }

    @Test func firstReasonWins() {
        let analytics = RecordingAnalytics()
        let session = PaywallSession(source: "s", analytics: analytics)
        session.shown(offeringId: nil)
        session.purchaseCompleted(isPremium: true)
        session.closeRequested() // RevenueCatUI asks to dismiss after a purchase
        session.ended()
        #expect(analytics.events.last?.reason == .purchased)
    }

    @Test func parametersAreFirebaseReady() {
        let event = PaywallEvent(name: .paywallClosed, source: "onboarding", offeringId: "o",
                                 packageId: "p", productId: "id", paywallRevision: 2,
                                 reason: .swipe, errorCode: 3, isPremium: true)
        let parameters = event.parameters
        #expect(event.name.rawValue == "paywall_closed")
        #expect(parameters["source"] as? String == "onboarding")
        #expect(parameters["offering_id"] as? String == "o")
        #expect(parameters["package_id"] as? String == "p")
        #expect(parameters["product_id"] as? String == "id")
        #expect(parameters["paywall_revision"] as? Int == 2)
        #expect(parameters["reason"] as? String == "swipe")
        #expect(parameters["error_code"] as? Int == 3)
        #expect(parameters["is_premium"] as? Int == 1)
        #expect(PaywallEvent(name: .paywallShown, source: "s").parameters.count == 1)
        #expect(Set(PaywallEvent.Name.allCases.map(\.rawValue)) == [
            "paywall_shown", "paywall_closed", "purchase_started", "purchase_completed",
            "purchase_cancelled", "purchase_failed", "restore_completed", "restore_failed"])
    }
}
