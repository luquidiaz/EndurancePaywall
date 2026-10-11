import RevenueCat
import RevenueCatUI
import SwiftUI

/// The paywall: RevenueCatUI's `PaywallView` for the resolved offering, the
/// standard events, and a fallback X while loading or after a failure.
///
/// Usually presented with `.endurancePaywall(isPresented:source:)`. Use it
/// directly only to embed the paywall in your own container; it closes
/// itself with the environment's `dismiss`.
///
/// Concurrency: no closure stored here is `@MainActor`-typed and nothing is
/// evaluated with `MainActor.assumeIsolated`, so SwiftUI may render it on
/// its async renderer (iOS 26) without tripping an isolation check.
public struct EndurancePaywallView<Placeholder: View>: View {
    private let placeholder: Placeholder?

    @Environment(\.dismiss) private var dismiss
    @State private var session: PaywallSession
    @State private var phase: Phase

    enum Phase {
        case loading
        case loaded(Offering)
        case failed
        case unconfigured
    }

    /// - Parameters:
    ///   - source: where it was opened from (`PaywallSource.onboarding`, a feature id...).
    ///   - unconfigured: shown instead of the paywall while RevenueCat isn't
    ///     configured (e.g. a DEBUG mock). It must have its own way out.
    public init(source: String, unconfigured: Placeholder) {
        self.init(source: source, placeholder: unconfigured)
    }

    init(source: String, placeholder: Placeholder?, analytics: (any PaywallAnalytics)? = nil, initialPhase: Phase? = nil) {
        self.placeholder = placeholder
        _session = State(initialValue: PaywallSession(
            source: source,
            analytics: analytics ?? EndurancePaywall.configuration.analytics
        ))
        _phase = State(initialValue: initialPhase ?? Self.initialPhase(source: source))
    }

    private static func initialPhase(source: String) -> Phase {
        guard Purchases.isConfigured else { return .unconfigured }
        // Offerings are usually cached by the time a paywall opens.
        if let offering = Purchases.shared.cachedOfferings?.paywallOffering(for: source)?.offering {
            return .loaded(offering)
        }
        return .loading
    }

    public var body: some View {
        content
            .overlay(alignment: .topTrailing) {
                if needsFallbackCloseButton {
                    PaywallFallbackCloseButton(action: closeTapped)
                }
            }
            .task { await load() }
            .onChange(of: EndurancePaywall.premium.isPremium) { _, isPremium in
                guard isPremium else { return }
                session.premiumUnlocked()
                dismiss()
            }
            .onDisappear { session.ended() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            PaywallLoadingView()
        case .unconfigured:
            if let placeholder {
                placeholder
            } else {
                PaywallUnavailableView()
            }
        case .loaded(let offering):
            revenueCatPaywall(PaywallView(offering: offering, displayCloseButton: !offering.hasPaywall))
        case .failed:
            revenueCatPaywall(PaywallView())
        }
    }

    private func revenueCatPaywall(_ paywall: PaywallView) -> some View {
        paywall
            .onPurchaseStarted { package in
                session.purchaseStarted(packageId: package.identifier,
                                        productId: package.storeProduct.productIdentifier)
            }
            .onPurchaseCompleted { customerInfo in
                EndurancePaywall.premium.update(with: customerInfo)
                session.purchaseCompleted(isPremium: EndurancePaywall.premium.isPremium)
            }
            .onPurchaseCancelled {
                session.purchaseCancelled()
            }
            .onPurchaseFailure { error in
                session.purchaseFailed(errorCode: error.code)
            }
            .onRestoreCompleted { customerInfo in
                EndurancePaywall.premium.update(with: customerInfo)
                session.restoreCompleted(isPremium: EndurancePaywall.premium.isPremium)
            }
            .onRestoreFailure { error in
                session.restoreFailed(errorCode: error.code)
            }
            .onRequestedDismissal {
                // RevenueCatUI asks for it on its X and after a purchase.
                if EndurancePaywall.premium.isPremium {
                    session.premiumUnlocked()
                } else {
                    session.closeRequested()
                }
                dismiss()
            }
    }

    private var needsFallbackCloseButton: Bool {
        switch phase {
        case .loading, .failed:
            true
        case .unconfigured:
            placeholder == nil
        case .loaded(let offering):
            PaywallCloseButtonPolicy.needsFallback(metadata: offering.metadata)
        }
    }

    private func closeTapped() {
        session.closeRequested()
        dismiss()
    }

    private func load() async {
        switch phase {
        case .unconfigured:
            session.shown(offeringId: nil)
        case .loaded(let offering):
            session.shown(offeringId: offering.identifier, paywallRevision: offering.paywall?.revision)
        case .failed:
            session.shown(offeringId: nil)
        case .loading:
            guard Purchases.isConfigured else {
                phase = .unconfigured
                session.shown(offeringId: nil)
                return
            }
            let offering = try? await Purchases.shared.offerings().paywallOffering(for: session.source)?.offering
            if let offering {
                phase = .loaded(offering)
                session.shown(offeringId: offering.identifier, paywallRevision: offering.paywall?.revision)
            } else {
                phase = .failed
                session.shown(offeringId: nil)
            }
        }
    }
}

extension EndurancePaywallView where Placeholder == Never {
    /// Paywall with the package's "unavailable" screen while RevenueCat isn't configured.
    public init(source: String) {
        self.init(source: source, placeholder: nil)
    }
}

/// Whether the package draws its X over a loaded dashboard paywall.
/// Standard paywalls bring their own X; an offering can opt out with the
/// metadata `has_close_button: false`.
enum PaywallCloseButtonPolicy {
    static let metadataKey = "has_close_button"

    static func needsFallback(metadata: [String: Any]) -> Bool {
        if let hasCloseButton = metadata[metadataKey] as? Bool {
            return !hasCloseButton
        }
        return false
    }
}
