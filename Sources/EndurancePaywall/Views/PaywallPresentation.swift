import SwiftUI

/// How the paywall is presented. Portfolio standard (Lucas, 2026-10-12):
/// always `.fullScreen`, the default of every `.endurancePaywall` modifier.
public enum PaywallPresentationStyle: Sendable {
    /// Discouraged: kept only for special cases. It looks like a sheet but
    /// can't be swiped down either (the paywall disables interactive
    /// dismissal); only the X closes it.
    case sheet
    /// Full page (`fullScreenCover`). The standard: only the package's X
    /// (fades in after `closeButtonDelay`) or a purchase closes it.
    case fullScreen

    /// The style every modifier uses when none is passed.
    public static let standard: PaywallPresentationStyle = .fullScreen
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
    /// Presents the standard paywall, full screen by default.
    /// `onDismiss` runs after it closes for any reason (X, purchase, the app).
    public func endurancePaywall(
        isPresented: Binding<Bool>,
        source: String,
        style: PaywallPresentationStyle = .standard,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(PaywallPresentationModifier<Never>(
            isPresented: isPresented, source: source, style: style, placeholder: nil, onDismiss: onDismiss
        ))
    }

    /// Same, with the view to show while RevenueCat isn't configured
    /// (e.g. a DEBUG mock paywall). The package draws its delayed X over it,
    /// so the placeholder must not draw its own.
    public func endurancePaywall<Placeholder: View>(
        isPresented: Binding<Bool>,
        source: String,
        style: PaywallPresentationStyle = .standard,
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
        style: PaywallPresentationStyle = .standard,
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
