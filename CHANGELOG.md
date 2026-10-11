# Changelog

## 0.1.0 - 2026-10-11

First release.

- `EndurancePaywall.configure` (RevenueCat key, entitlement, fallback offering, source → placement map, premium cache, analytics).
- `EndurancePaywallView` around RevenueCatUI with a fallback X while loading, after a failure and when the offering says it has none.
- `.endurancePaywall(isPresented:source:style:onDismiss:)`, `.endurancePaywall(item:)` and the `unconfigured:` placeholder variant.
- Offering resolution: placement → current → fallback identifier.
- Standard events: `paywall_shown`, `paywall_closed` (with `reason`), `purchase_started/completed/cancelled/failed`, `restore_completed/failed`, with `source`, `offering_id`, `package_id` and `product_id`. Analytics through the nonisolated `PaywallAnalytics` protocol.
- `PremiumState` (`@Observable` + `ObservableObject`), offline cache and App Group flag for widgets, `restore()`, DEBUG override.
- `PaywallTrigger` / `PaywallTriggerPolicy`: actions before showing, cap and cooldown.
- Strings in en, es, pt-BR, de, fr, it, ja, ko.
