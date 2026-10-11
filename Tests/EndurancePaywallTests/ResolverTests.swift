import Testing
@testable import EndurancePaywall

@Suite("Offering resolver")
struct ResolverTests {
    let all = ["legacy": "legacy-offering", "standard": "standard-offering"]
    let placements = ["onboarding": "onboarding-offering"]

    @Test func placementWinsWhenRevenueCatResolvesIt() throws {
        let result = try #require(PaywallOfferingResolver.resolve(
            placement: "onboarding", offeringForPlacement: { placements[$0] },
            current: "current-offering", fallbackIdentifier: "legacy", offeringWithIdentifier: { all[$0] }))
        #expect(result.offering == "onboarding-offering")
        #expect(result.origin == .placement)
    }

    @Test func currentComesBeforeTheFallbackIdentifier() throws {
        // Experiments and Targeting only change the current offering.
        let result = try #require(PaywallOfferingResolver.resolve(
            placement: "unknown", offeringForPlacement: { placements[$0] },
            current: "current-offering", fallbackIdentifier: "legacy", offeringWithIdentifier: { all[$0] }))
        #expect(result.offering == "current-offering")
        #expect(result.origin == .current)
    }

    @Test func fallbackIdentifierWithoutCurrent() throws {
        let result = try #require(PaywallOfferingResolver.resolve(
            placement: nil, offeringForPlacement: { placements[$0] },
            current: String?.none, fallbackIdentifier: "legacy", offeringWithIdentifier: { all[$0] }))
        #expect(result.offering == "legacy-offering")
        #expect(result.origin == .fallback)
    }

    @Test func nothingToShow() {
        #expect(PaywallOfferingResolver.resolve(
            placement: nil, offeringForPlacement: { placements[$0] },
            current: String?.none, fallbackIdentifier: "missing", offeringWithIdentifier: { all[$0] }) == nil)
    }

    @Test func placementMapping() {
        let configuration = EndurancePaywallConfiguration(
            apiKey: nil, entitlementId: "premium",
            placements: ["onboarding": "onboarding_placement"], defaultPlacement: "feature_placement")
        #expect(configuration.placement(for: "onboarding") == "onboarding_placement")
        #expect(configuration.placement(for: "export") == "feature_placement")
        #expect(EndurancePaywallConfiguration(apiKey: nil, entitlementId: "premium").placement(for: "export") == nil)
    }

    @Test func closeButtonPolicyFollowsMetadata() {
        #expect(!PaywallCloseButtonPolicy.needsFallback(metadata: [:]))
        #expect(PaywallCloseButtonPolicy.needsFallback(metadata: ["has_close_button": false]))
        #expect(!PaywallCloseButtonPolicy.needsFallback(metadata: ["has_close_button": true]))
    }
}
