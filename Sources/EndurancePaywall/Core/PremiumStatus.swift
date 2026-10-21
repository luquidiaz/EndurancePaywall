import Foundation
import RevenueCat

/// Subscription status as a Firebase user property (`premium_status`), so
/// every funnel and retention report can be split into free, trial and paying
/// users. The package sets it through `PaywallAnalytics.setUserProperty`
/// each time RevenueCat reports a different status.
public enum PremiumStatus: String, Sendable, CaseIterable {
    /// No active entitlement.
    case free
    /// Active entitlement in a free trial.
    case trial
    /// Active entitlement, paid (normal, intro or prepaid period).
    case premium

    /// User property name (portfolio standard, `docs/specs/analytics-estandar.md`).
    public static let userPropertyName = "premium_status"

    init(isActive: Bool, periodType: PeriodType?) {
        guard isActive else { self = .free; return }
        self = periodType == .trial ? .trial : .premium
    }
}
