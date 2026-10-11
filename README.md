# EndurancePaywall

One paywall for every Endurance Apptitude app: presented, resolved and measured the same way everywhere, so a change proven in one app can be carried to the rest.

- RevenueCatUI `PaywallView` (the paywall is designed in the RevenueCat dashboard) with a fallback X while it loads or if it fails. Never a dead end.
- Offering resolution: placement mapped from the `source` → **current** offering (so Experiments and Targeting work) → a fallback identifier.
- The same events in every app, with `source`, `offering_id` and `package_id`, through an injectable analytics protocol. The package does not depend on Firebase.
- Shared premium status (`@Observable` and `ObservableObject`), cached offline and optionally mirrored to an App Group for widgets.
- Rules for the automatic paywall: actions before showing, a cap and a cooldown.
- iOS 17+, Swift 6 strict concurrency. Depends only on RevenueCat `purchases-ios` (from 5.94.0).

## Install

In Xcode, go to File → Add Package Dependencies and use `https://github.com/luquidiaz/EndurancePaywall`. Add the `EndurancePaywall` product to the app target. If the app already depends on `purchases-ios`, keep the rule compatible (`from: 5.94.0`).

## Integration

### 1. Configure once at launch

```swift
import EndurancePaywall
import FirebaseAnalytics

EndurancePaywall.configure(
    apiKey: AppConfig.RevenueCat.apiKey,         // nil if the app configures Purchases itself
    entitlementId: "premium",
    fallbackOfferingId: "v2_annual_default",     // only used if there is no current offering
    placements: ["onboarding": "onboarding"],    // optional: source → RevenueCat placement
    premiumCache: PremiumCache(suiteName: "group.com.example.app") // App Group for widgets
) { event in
    // Nonisolated and @Sendable: may run off the main thread.
    Analytics.logEvent(event.name.rawValue, parameters: event.parameters)
}
```

Or build an `EndurancePaywallConfiguration` and pass your own `PaywallAnalytics` implementation.

### 2. Present it

```swift
// End of onboarding
OnboardingView(flow: flow) { _ in showPaywall = true }
    .endurancePaywall(isPresented: $showPaywall, source: PaywallSource.onboarding, style: .fullScreen) {
        hasCompletedOnboarding = true
    }

// A locked feature
Button("Export") { if premium.isPremium { export() } else { showPaywall = true } }
    .endurancePaywall(isPresented: $showPaywall, source: "export")

// Several entry points, one presentation
.endurancePaywall(item: $paywallRequest)   // paywallRequest = PaywallRequest(source: "widget")
```

While RevenueCat isn't configured (no API key yet) the paywall shows a neutral "unavailable" screen. Pass `unconfigured:` to show your own view instead, for example a DEBUG mock:

```swift
.endurancePaywall(isPresented: $show, source: "settings", unconfigured: MockPaywallView())
```

### 3. Read premium

```swift
// @Observable apps
.environment(EndurancePaywall.premium)
@Environment(PremiumState.self) private var premium

// ObservableObject apps
@ObservedObject private var premium = EndurancePaywall.premium

premium.isPremium
await premium.restore()            // settings "Restore purchases" (logs restore_* with source settings)
premium.onChange = { isPremium in WidgetCenter.shared.reloadAllTimelines() }
#if DEBUG
premium.debugOverride = true       // screenshots; never cached
#endif
```

### 4. Automatic paywall (optional)

```swift
let trigger = PaywallTrigger(id: "birthday_added",
                             policy: PaywallTriggerPolicy(actionsBeforeShow: 2, maxShows: 3, cooldown: PaywallTriggerPolicy.days(3)))

func didAddBirthday() {
    if trigger.recordAction(isPremium: premium.isPremium, canPresent: !timerIsRunning) {
        showPaywall = true // .endurancePaywall(isPresented: $showPaywall, source: PaywallSource.automatic)
    }
}
```

The onboarding and locked features always show the paywall; only the automatic one goes through the trigger.

## Events

| Event | When | Extra parameters |
|-------|------|------------------|
| `paywall_shown` | Offering resolved (or load failed / RevenueCat not configured) | `paywall_revision` (v1 paywalls) |
| `paywall_closed` | The paywall left the screen | `reason`: `close`, `swipe`, `purchased`, `restored` |
| `purchase_started` | A package was tapped | `package_id`, `product_id` |
| `purchase_completed` | Purchase finished | `package_id`, `product_id`, `is_premium` |
| `purchase_cancelled` | User cancelled the App Store sheet | `package_id`, `product_id` |
| `purchase_failed` | Purchase error | `package_id`, `product_id`, `error_code` |
| `restore_completed` | Restore finished | `is_premium` |
| `restore_failed` | Restore error | `error_code` |

All events carry `source` and, when known, `offering_id`.

## The X

Standard paywalls (dashboard) bring their own X. The package draws one while loading, after a failure, on the "unavailable" screen, and on a loaded paywall whose offering metadata has `has_close_button: false`. Offerings without a dashboard paywall use RevenueCat's default paywall with its close button.

## Concurrency

Nothing SwiftUI may evaluate while rendering is a `@MainActor`-typed closure, no `MainActor.assumeIsolated`, and no hand-made `Binding(get:set:)`. On iOS 26 SwiftUI can render on its async renderer, off the main thread, and such closures trap (the bug in EnduranceOnboarding 0.1.0). Analytics are nonisolated `@Sendable`.

## Develop

```sh
xcodebuild -scheme EndurancePaywall -destination 'generic/platform=iOS Simulator' build
xcodebuild test -scheme EndurancePaywall -destination 'platform=iOS Simulator,name=<your simulator>'
```

`swift build` doesn't work: the package is iOS only.
