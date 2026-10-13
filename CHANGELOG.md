# Changelog

## 0.2.0 - 2026-10-12

Portfolio standard (Lucas, 2026-10-12): the paywall is always a full page and the X fades in after 8 seconds. Default behavior changes; source compatible.

- **Full screen by default**: every `.endurancePaywall` modifier defaults to `style: .fullScreen` (new `PaywallPresentationStyle.standard`). `.sheet` is kept but discouraged.
- `EndurancePaywallView` applies `.interactiveDismissDisabled()`: no swipe-to-dismiss, also when presented as a sheet or embedded.
- **The package owns the X** in every phase (loading, failure, "unavailable", `unconfigured:` placeholder and the dashboard paywall). Hidden for `closeButtonDelay` seconds, then a 0.35 s fade-in; tapping it logs `paywall_closed` (`reason: close`).
- New `EndurancePaywallConfiguration.closeButtonDelay` (default `EndurancePaywallConfiguration.defaultCloseButtonDelay` = 8 s), also on `EndurancePaywall.configure(apiKey:...)`.
- Dashboard paywalls must not have their own close button (the package can't delay it). RevenueCat's default paywall (offering without a dashboard paywall) no longer shows its close button. The `has_close_button` offering metadata is no longer read.
- Placeholders passed as `unconfigured:` get the package's X: remove the mock's own X.

## 0.1.1 - 2026-10-11

- Strings in six more languages: zh-Hans, zh-Hant, nl, sv, pl, tr (informal register). The fallback close button and "unavailable" screen no longer fall back to English there. No API changes.

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
