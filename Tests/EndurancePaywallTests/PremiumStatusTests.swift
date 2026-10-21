import Foundation
import RevenueCat
import Testing
@testable import EndurancePaywall

/// Thread-safe recorder for the closure-based configure.
private final class PropertyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func append(_ value: String) { lock.lock(); stored.append(value); lock.unlock() }
    var values: [String] { lock.lock(); defer { lock.unlock() }; return stored }
}

@Suite("Premium status and Firebase link", .serialized)
@MainActor
struct PremiumStatusTests {
    @Test func statusFromEntitlement() {
        #expect(PremiumStatus(isActive: false, periodType: .trial) == .free)
        #expect(PremiumStatus(isActive: false, periodType: nil) == .free)
        #expect(PremiumStatus(isActive: true, periodType: .trial) == .trial)
        #expect(PremiumStatus(isActive: true, periodType: .normal) == .premium)
        #expect(PremiumStatus(isActive: true, periodType: .intro) == .premium)
        #expect(PremiumStatus.userPropertyName == "premium_status")
    }

    @Test func setsTheUserPropertyOnlyWhenTheStatusChanges() {
        let analytics = RecordingAnalytics()
        EndurancePaywall.configure(EndurancePaywallConfiguration(apiKey: nil, entitlementId: "premium", premiumCache: nil, analytics: analytics))
        let state = PremiumState(entitlementId: "premium", cache: nil)
        #expect(state.status == nil)
        state.report(.trial)
        state.report(.trial)
        state.report(.premium)
        #expect(state.status == .premium)
        #expect(analytics.userProperties.map(\.name) == ["premium_status", "premium_status"])
        #expect(analytics.userProperties.map(\.value) == ["trial", "premium"])
        #expect(analytics.events.isEmpty)
    }

    @Test func closureConfigureForwardsUserPropertiesAndKeepsTheInstanceID() {
        let box = PropertyBox()
        EndurancePaywall.configure(
            apiKey: nil,
            entitlementId: "premium",
            premiumCache: nil,
            firebaseAppInstanceID: "abc123",
            userProperty: { value, name in box.append("\(name)=\(value ?? "nil")") }
        ) { _ in }
        #expect(EndurancePaywall.configuration.firebaseAppInstanceID == "abc123")
        EndurancePaywall.configuration.analytics.setUserProperty("free", forName: "premium_status")
        #expect(box.values == ["premium_status=free"])

        // Without RevenueCat configured the id is kept for later.
        EndurancePaywall.setFirebaseAppInstanceID("def456")
        #expect(EndurancePaywall.configuration.firebaseAppInstanceID == "def456")

        // Old call sites (trailing analytics closure only) still compile and drop properties.
        EndurancePaywall.configure(apiKey: nil, entitlementId: "premium", premiumCache: nil) { _ in }
        EndurancePaywall.configuration.analytics.setUserProperty("x", forName: "premium_status")
        #expect(EndurancePaywall.configuration.firebaseAppInstanceID == nil)
    }
}
