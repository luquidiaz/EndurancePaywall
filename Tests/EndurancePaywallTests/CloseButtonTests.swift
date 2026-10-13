import Foundation
import SwiftUI
import Testing
@testable import EndurancePaywall

/// Records the waits the timer asks for, without waiting.
final class RecordingSleep: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Duration] = []
    private let error: (any Error)?

    init(throwing error: (any Error)? = nil) {
        self.error = error
    }

    var calls: [Duration] {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in
            record(duration)
            if let error { throw error }
        }
    }

    private func record(_ duration: Duration) {
        lock.lock(); defer { lock.unlock() }
        stored.append(duration)
    }
}

@Suite("Close button delay")
struct CloseButtonTests {

    @Test func standardDelayIsEightSeconds() {
        #expect(EndurancePaywallConfiguration.defaultCloseButtonDelay == 8)
        #expect(EndurancePaywallConfiguration(apiKey: nil, entitlementId: "premium").closeButtonDelay == 8)
        #expect(EndurancePaywallConfiguration(apiKey: nil, entitlementId: "premium", closeButtonDelay: 2).closeButtonDelay == 2)
    }

    @MainActor
    @Test func configureClosureVariantPassesTheDelay() {
        EndurancePaywall.configure(apiKey: nil, entitlementId: "premium", premiumCache: nil, closeButtonDelay: 3) { _ in }
        #expect(EndurancePaywall.configuration.closeButtonDelay == 3)
        EndurancePaywall.configure(apiKey: nil, entitlementId: "premium", premiumCache: nil) { _ in }
        #expect(EndurancePaywall.configuration.closeButtonDelay == 8)
    }

    @Test func waitsTheConfiguredDelayThenShows() async {
        let recorder = RecordingSleep()
        let timer = PaywallCloseButtonTimer(delay: 8, sleep: recorder.sleep)
        #expect(!timer.isVisibleImmediately)
        #expect(await timer.waitUntilVisible())
        #expect(recorder.calls == [.seconds(8)])
    }

    @Test func fractionalDelayKeepsMilliseconds() async {
        let recorder = RecordingSleep()
        #expect(await PaywallCloseButtonTimer(delay: 0.25, sleep: recorder.sleep).waitUntilVisible())
        #expect(recorder.calls == [.milliseconds(250)])
    }

    @Test(arguments: [0, -1, .nan, .infinity] as [TimeInterval])
    func zeroOrInvalidDelayShowsImmediately(delay: TimeInterval) async {
        let recorder = RecordingSleep()
        let timer = PaywallCloseButtonTimer(delay: delay, sleep: recorder.sleep)
        #expect(timer.delay == 0)
        #expect(timer.isVisibleImmediately)
        #expect(await timer.waitUntilVisible())
        #expect(recorder.calls.isEmpty)
    }

    @Test func cancelledWaitKeepsTheXHidden() async {
        let recorder = RecordingSleep(throwing: CancellationError())
        #expect(!(await PaywallCloseButtonTimer(delay: 8, sleep: recorder.sleep).waitUntilVisible()))
    }

    @Test func paywallLeavingBeforeTheDelayKeepsTheXHidden() async {
        let timer = PaywallCloseButtonTimer(delay: 8, sleep: { _ in
            // The real sleep returns early by throwing; a sleep that returns
            // normally on a cancelled task must not show the X either.
            withUnsafeCurrentTask { $0?.cancel() }
        })
        #expect(!(await timer.waitUntilVisible()))
    }

    @Test func realClockWaitsAtLeastTheDelay() async {
        let start = ContinuousClock.now
        #expect(await PaywallCloseButtonTimer(delay: 0.2).waitUntilVisible())
        #expect(ContinuousClock.now - start >= .milliseconds(200))
    }

    @Test func fullScreenIsTheStandardPresentation() {
        #expect(PaywallPresentationStyle.standard == .fullScreen)
    }

    @MainActor
    @Test func closeButtonRendersHiddenAndVisible() {
        for isVisible in [false, true] {
            let button = PaywallCloseButton(isVisible: isVisible) {}
            #expect(ImageRenderer(content: button).uiImage != nil)
        }
    }
}
