# EndurancePaywall

Aplica el `CLAUDE.md` de la raíz del workspace (proceso, git, convenciones).

## Qué es

Paquete Swift con **el** paywall de todas las apps del portfolio
(`docs/paywall-standard.md`, sección 8). iOS 17+, swift-tools 6.0, Swift 6
estricto. Única dependencia: RevenueCat `purchases-ios` (from 5.94.0). No
depende de Firebase: los eventos salen por `PaywallAnalytics`.

## API

- `EndurancePaywall.configure(...)` / `EndurancePaywallConfiguration`.
- `.endurancePaywall(isPresented:source:style:onDismiss:)`, `(item:)`, variante con `unconfigured:`.
  `style` por defecto `.fullScreen` (`PaywallPresentationStyle.standard`); `.sheet` existe pero se desaconseja.
- `EndurancePaywallView` (RevenueCatUI + la X del paquete), `PremiumState` (`EndurancePaywall.premium`).
- `PaywallOfferingResolver` (placement → current → fallback), `PaywallSession` (eventos, interno).
- `PaywallTrigger` / `PaywallTriggerPolicy`, `PaywallSource`.

## Reglas

- Nada que SwiftUI evalúe al renderizar puede ser un closure tipado `@MainActor`,
  ni `MainActor.assumeIsolated`, ni `Binding(get:set:)` armado a mano (crash del
  async renderer de iOS 26, ver EnduranceOnboarding 0.1.0).
- Un string nuevo va en los 14 idiomas de `Resources/Localizable.xcstrings`
  (en, es, pt-BR, de, fr, it, ja, ko, zh-Hans, zh-Hant, nl, sv, pl, tr; ver `LocalizationTests`).
- Nombres de eventos: no se cambian sin migrar el análisis de todas las apps.
- Paywall siempre página completa y sin swipe-to-dismiss (`.interactiveDismissDisabled()`);
  decisión de Lucas del 2026-10-12 para todo el portfolio.
- La X es del paquete en todas las fases: oculta `closeButtonDelay` (8 s por defecto,
  `PaywallCloseButtonTimer`) y después fade-in. Los paywalls del dashboard de RevenueCat
  no llevan botón de cerrar (el paquete no puede demorarlo y se verían dos X).

## Cómo validar

```sh
SIM_UDID=<udid> ../scripts/build.sh EndurancePaywall   # build + tests
# o a mano:
xcodebuild -scheme EndurancePaywall -destination 'generic/platform=iOS Simulator' build
xcodebuild test -scheme EndurancePaywall -destination 'platform=iOS Simulator,id=<udid>'
```

Usar un simulador propio (`xcrun simctl create`), no los de otros agentes.

## Publicar versiones

Igual que EnduranceOnboarding: semver, tag anotado sobre `main` después de build y
tests, tags inmutables, CHANGELOG actualizado. Antes de cambiar la API pública,
buscar quién la usa (`grep -rl EndurancePaywall ../*/*.xcodeproj`) y avisar.
