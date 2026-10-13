import SwiftUI

/// The paywall's X. Owned by the package and drawn over every phase
/// (loading, failure, "unavailable", placeholder, dashboard paywall), so the
/// delay is the same in every app. While hidden it takes no taps and is
/// hidden from VoiceOver; `EndurancePaywallView` fades it in after
/// `closeButtonDelay`. 44 pt hit area, inside the safe area, adapts to
/// light and dark (material background, secondary glyph).
struct PaywallCloseButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.thinMaterial))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("paywall.close", bundle: .module))
        .accessibilityIdentifier("paywall.close")
        .padding(.top, 4)
        .padding(.trailing, 8)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}

/// Shown when RevenueCat isn't configured (no API key yet). Apps can pass
/// their own view instead (e.g. a DEBUG mock paywall).
public struct PaywallUnavailableView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("paywall.unavailable.title", bundle: .module)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("paywall.unavailable.message", bundle: .module)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}

struct PaywallLoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .accessibilityIdentifier("paywall.loading")
    }
}
