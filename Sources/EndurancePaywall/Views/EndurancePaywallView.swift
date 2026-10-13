import RevenueCat
import RevenueCatUI
import SwiftUI

/// The paywall: RevenueCatUI's `PaywallView` for the resolved offering, the
/// standard events, and the package's own X.
///
/// The X belongs to the package in every phase (loading, failure,
/// "unavailable", the `unconfigured:` placeholder and the dashboard
/// paywall): hidden for `EndurancePaywallConfiguration.closeButtonDelay`
/// seconds (8 by default), then it fades in. Dashboard paywalls must NOT
/// have their own close button: the package can't delay it, and the user
/// would see two.
///
/// Usually presented with `.endurancePaywall(isPresented:source:)` (full
/// screen). Use it directly only to embed the paywall in your own container;
/// it closes itself with the environment's `dismiss` and disables
/// interactive dismissal (no swipe-to-dismiss).
///
/// Concurrency: no closure stored here is `@MainActor`-typed and nothing is
/// evaluated with `MainActor.assumeIsolated`, so SwiftUI may render it on
/// its async renderer (iOS 26) without tripping an isolation check.
public struct EndurancePaywallView<Placeholder: View>: View {
    private let placeholder: Placeholder?

    @Environment(\.dismiss) private var dismiss
    @State private var session: PaywallSession
    @State private var phase: Phase
    @State private var isCloseButtonVisible: Bool
    private let closeButtonTimer: PaywallCloseButtonTimer

    enum Phase {
        case loading
        case loaded(Offering)
        case failed
        case unconfigured
    }

    /// - Parameters:
    ///   - source: where it was opened from (`PaywallSource.onboarding`, a feature id...).
    ///   - unconfigured: shown instead of the paywall while RevenueCat isn't
    ///     configured (e.g. a DEBUG mock). The package's X (with the same
    ///     delay) is drawn over it: don't add another one.
    public init(source: String, unconfigured: Placeholder) {
        self.init(source: source, placeholder: unconfigured)
    }

    init(
        source: String,
        placeholder: Placeholder?,
        analytics: (any PaywallAnalytics)? = nil,
        initialPhase: Phase? = nil,
        closeButtonTimer: PaywallCloseButtonTimer? = nil
    ) {
        self.placeholder = placeholder
        let timer = closeButtonTimer ?? PaywallCloseButtonTimer(delay: EndurancePaywall.configuration.closeButtonDelay)
        self.closeButtonTimer = timer
        _isCloseButtonVisible = State(initialValue: timer.isVisibleImmediately)
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
                PaywallCloseButton(isVisible: isCloseButtonVisible, action: closeTapped)
            }
            .interactiveDismissDisabled()
            .task { await load() }
            .task { await revealCloseButton() }
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
            // The package draws the X; RevenueCat's default paywall (offering
            // without a dashboard paywall) must not add a second one.
            revenueCatPaywall(PaywallView(offering: offering, displayCloseButton: false))
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
                // RevenueCatUI asks for it after a purchase, or on a dashboard
                // close button (not allowed by the standard, still handled).
                if EndurancePaywall.premium.isPremium {
                    session.premiumUnlocked()
                } else {
                    session.closeRequested()
                }
                dismiss()
            }
    }

    private func revealCloseButton() async {
        guard !isCloseButtonVisible else { return }
        guard await closeButtonTimer.waitUntilVisible() else { return }
        withAnimation(.easeIn(duration: PaywallCloseButtonTimer.fadeInDuration)) {
            isCloseButtonVisible = true
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
