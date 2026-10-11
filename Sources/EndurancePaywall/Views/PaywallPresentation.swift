import SwiftUI

/// How the paywall is presented.
public enum PaywallPresentationStyle: Sendable {
    /// Sheet (swipe down closes it, logged as `reason: swipe`).
    case sheet
    /// Full screen (e.g. end of onboarding): only the X closes it.
    case fullScreen
}

/// A paywall to present for a `source`. Use with `.endurancePaywall(item:)`
/// when several entry points share one presentation.
public struct PaywallRequest: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let source: String

    public init(source: String) {
        self.id = UUID()
        self.source = source
    }
}

extension View {
    /// Presents the standard paywall.
    /// `onDismiss` runs after it closes for any reason (X, swipe, purchase).
    public func endurancePaywall(
        isPresented: Binding<Bool>,
        source: String,
        style: PaywallPresentationStyle = .sheet,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(PaywallPresentationModifier<Never>(
            isPresented: isPresented, source: source, style: style, placeholder: nil, onDismiss: onDismiss
        ))
    }

    /// Same, with the view to show while RevenueCat isn't configured
    /// (e.g. a DEBUG mock paywall; it must have its own way out).
    public func endurancePaywall<Placeholder: View>(
        isPresented: Binding<Bool>,
        source: String,
        style: PaywallPresentationStyle = .sheet,
        unconfigured: Placeholder,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(PaywallPresentationModifier(
            isPresented: isPresented, source: source, style: style, placeholder: unconfigured, onDismiss: onDismiss
        ))
    }

    /// Presents the paywall for a request (its `source`), then sets it to `nil`.
    public func endurancePaywall(
        item: Binding<PaywallRequest?>,
        style: PaywallPresentationStyle = .sheet,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(PaywallItemPresentationModifier(item: item, style: style, onDismiss: onDismiss))
    }
}

// No hand-made `Binding(get:set:)` here: SwiftUI reads bindings while
// rendering, and a getter closure formed on the main actor is exactly what
// traps on iOS 26's async renderer. Only SwiftUI's own presenters are used.

struct PaywallItemPresentationModifier: ViewModifier {
    @Binding var item: PaywallRequest?
    let style: PaywallPresentationStyle
    let onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        switch style {
        case .sheet:
            content.sheet(item: $item, onDismiss: onDismiss) { request in
                EndurancePaywallView<Never>(source: request.source, placeholder: nil)
            }
        case .fullScreen:
            content.fullScreenCover(item: $item, onDismiss: onDismiss) { request in
                EndurancePaywallView<Never>(source: request.source, placeholder: nil)
            }
        }
    }
}

struct PaywallPresentationModifier<Placeholder: View>: ViewModifier {
    @Binding var isPresented: Bool
    let source: String
    let style: PaywallPresentationStyle
    let placeholder: Placeholder?
    let onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        switch style {
        case .sheet:
            content.sheet(isPresented: $isPresented, onDismiss: onDismiss) { paywall }
        case .fullScreen:
            content.fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) { paywall }
        }
    }

    private var paywall: EndurancePaywallView<Placeholder> {
        EndurancePaywallView(source: source, placeholder: placeholder)
    }
}
