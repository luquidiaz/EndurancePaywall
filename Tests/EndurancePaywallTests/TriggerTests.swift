import Foundation
import Testing
@testable import EndurancePaywall

@Suite("Trigger rules")
@MainActor
struct TriggerTests {
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func policyNeedsActionsAndRespectsCapAndCooldown() {
        let policy = PaywallTriggerPolicy(actionsBeforeShow: 2, maxShows: 3, cooldown: PaywallTriggerPolicy.days(3))
        #expect(!policy.shouldShow(PaywallTriggerState(actionCount: 1), isPremium: false, canPresent: true, now: start))
        #expect(policy.shouldShow(PaywallTriggerState(actionCount: 2), isPremium: false, canPresent: true, now: start))
        #expect(!policy.shouldShow(PaywallTriggerState(actionCount: 2), isPremium: true, canPresent: true, now: start))
        #expect(!policy.shouldShow(PaywallTriggerState(actionCount: 2), isPremium: false, canPresent: false, now: start))
        #expect(!policy.shouldShow(PaywallTriggerState(actionCount: 5, showCount: 3), isPremium: false, canPresent: true, now: start))
        let recent = PaywallTriggerState(actionCount: 2, showCount: 1, lastShown: start)
        #expect(!policy.shouldShow(recent, isPremium: false, canPresent: true, now: start.addingTimeInterval(PaywallTriggerPolicy.days(2.9))))
        #expect(policy.shouldShow(recent, isPremium: false, canPresent: true, now: start.addingTimeInterval(PaywallTriggerPolicy.days(3))))
    }

    @Test func triggerCountsPersistsAndStopsAtTheCap() {
        let defaults = freshDefaults()
        let trigger = PaywallTrigger(id: "item_added", defaults: defaults)
        var now = start
        var shows = 0
        for _ in 0..<40 {
            if trigger.recordAction(isPremium: false, now: now) { shows += 1 }
            now = now.addingTimeInterval(PaywallTriggerPolicy.days(1))
        }
        #expect(shows == 3)
        // Another instance reads the same persisted state.
        #expect(PaywallTrigger(id: "item_added", defaults: defaults).state.showCount == 3)
        trigger.reset()
        #expect(trigger.state == PaywallTriggerState())
    }

    @Test func showResetsActionsAndCooldownApplies() {
        let trigger = PaywallTrigger(id: "t", defaults: freshDefaults())
        #expect(!trigger.recordAction(isPremium: false, now: start))
        #expect(trigger.recordAction(isPremium: false, now: start))
        #expect(trigger.state.actionCount == 0)
        #expect(trigger.state.lastShown == start)
        #expect(!trigger.recordAction(isPremium: false, now: start))
        #expect(!trigger.recordAction(isPremium: false, now: start.addingTimeInterval(60)))
        #expect(trigger.recordAction(isPremium: false, now: start.addingTimeInterval(PaywallTriggerPolicy.days(3))))
    }

    @Test func premiumAndBlockedMomentsNeverShow() {
        let trigger = PaywallTrigger(id: "t", defaults: freshDefaults())
        for _ in 0..<5 { #expect(!trigger.recordAction(isPremium: true, now: start)) }
        #expect(trigger.state.actionCount == 0)
        for _ in 0..<5 { #expect(!trigger.recordAction(isPremium: false, canPresent: false, now: start)) }
        #expect(trigger.recordAction(isPremium: false, now: start))
    }
}
