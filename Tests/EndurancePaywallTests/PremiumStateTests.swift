import Foundation
import Testing
@testable import EndurancePaywall

@Suite("Premium state")
@MainActor
struct PremiumStateTests {
    @Test func readsAndWritesTheCache() {
        let suite = "EndurancePaywallTests.premium.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: "revenuecat_premium_cache")
        let cache = PremiumCache(suiteName: suite)
        let state = PremiumState(entitlementId: "premium", cache: cache)
        #expect(state.isPremium)

        var changes: [Bool] = []
        state.onChange = { changes.append($0) }
        state.apply(false)
        #expect(!state.isPremium)
        #expect(defaults.bool(forKey: "revenuecat_premium_cache") == false)
        #expect(defaults.object(forKey: "is_premium") as? Bool == false)
        state.apply(false)
        #expect(changes == [false])
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func notifiesObservableObjectSubscribers() {
        let state = PremiumState(entitlementId: "premium", cache: nil)
        var notifications = 0
        let cancellable = state.objectWillChange.sink { notifications += 1 }
        state.apply(true)
        #expect(state.isPremium)
        #expect(notifications == 1)
        cancellable.cancel()
    }

    #if DEBUG
    @Test func debugOverrideIsNeverCached() {
        let suite = "EndurancePaywallTests.override.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let state = PremiumState(entitlementId: "premium", cache: PremiumCache(suiteName: suite))
        state.debugOverride = true
        #expect(state.isPremium)
        #expect(defaults.bool(forKey: "revenuecat_premium_cache") == false)
        #expect(defaults.bool(forKey: "is_premium"))
        state.debugOverride = nil
        #expect(!state.isPremium)
        defaults.removePersistentDomain(forName: suite)
    }
    #endif
}
