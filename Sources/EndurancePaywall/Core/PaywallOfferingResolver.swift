import Foundation

/// How the offering of a paywall was picked.
public enum PaywallOfferingOrigin: String, Sendable {
    /// RevenueCat placement mapped from the `source`.
    case placement
    /// The dashboard's current offering (Experiments and Targeting apply).
    case current
    /// The configured fallback identifier.
    case fallback
}

/// Picks the offering a paywall shows:
/// 1. the placement mapped from the `source`, if RevenueCat resolves one;
/// 2. the current offering, so Experiments and Targeting reach every user;
/// 3. the fallback identifier, for projects without a current offering.
///
/// Generic so it is tested without RevenueCat types.
public enum PaywallOfferingResolver {
    public static func resolve<Offering>(
        placement: String?,
        offeringForPlacement: (String) -> Offering?,
        current: Offering?,
        fallbackIdentifier: String?,
        offeringWithIdentifier: (String) -> Offering?
    ) -> (offering: Offering, origin: PaywallOfferingOrigin)? {
        if let placement, let offering = offeringForPlacement(placement) {
            return (offering, .placement)
        }
        if let current {
            return (current, .current)
        }
        if let fallbackIdentifier, let offering = offeringWithIdentifier(fallbackIdentifier) {
            return (offering, .fallback)
        }
        return nil
    }
}
