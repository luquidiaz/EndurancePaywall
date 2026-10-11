import Foundation
import SwiftUI
import Testing
import UIKit
@testable import EndurancePaywall

/// Regression guard for the iOS 26 crash EnduranceOnboarding 0.1.0 had: a
/// closure typed `@MainActor` that SwiftUI (or a background thread) ends up
/// calling off the main thread traps on the isolation check. Everything the
/// app injects (analytics) must run from any thread, and the views must
/// render and close without the package assuming main-actor isolation.
@Suite("Concurrency and rendering", .serialized)
@MainActor
struct ConcurrencyTests {

    @Test func analyticsRunsOffTheMainThread() async {
        let recorder = RecordingAnalytics()
        EndurancePaywall.configure(apiKey: nil, entitlementId: "premium", premiumCache: nil) { event in
            recorder.track(event)
        }
        let analytics = EndurancePaywall.configuration.analytics
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                #expect(!Thread.isMainThread)
                let event = PaywallEvent(name: .paywallShown, source: "background", offeringId: "o")
                _ = event.parameters
                analytics.track(event)
                continuation.resume()
            }
        }
        await Task.detached {
            analytics.track(PaywallEvent(name: .paywallClosed, source: "detached", reason: .swipe))
        }.value
        #expect(recorder.names == [.paywallShown, .paywallClosed])
    }

    @Test func viewRendersInEveryPhaseWithoutRevenueCat() async throws {
        let recorder = RecordingAnalytics()
        let phases: [EndurancePaywallView<Never>.Phase] = [.loading, .unconfigured]
        for phase in phases {
            let view = EndurancePaywallView<Never>(source: "render", placeholder: nil, analytics: recorder, initialPhase: phase)
            let renderer = ImageRenderer(content: view.frame(width: 390, height: 844))
            #expect(renderer.uiImage != nil)
        }
        let withPlaceholder = EndurancePaywallView(source: "render", unconfigured: Text(verbatim: "Mock paywall"))
        #expect(ImageRenderer(content: withPlaceholder.frame(width: 390, height: 844)).uiImage != nil)
    }

    @Test func hostedPaywallLogsShownAndClosed() async throws {
        let recorder = RecordingAnalytics()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: AnyView(
            EndurancePaywallView<Never>(source: "hosted", placeholder: nil, analytics: recorder, initialPhase: .unconfigured)
        ))
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await settle()
        #expect(recorder.names == [.paywallShown])

        // Leaving the screen without the X is a swipe.
        host.rootView = AnyView(Color.clear)
        try await settle()
        #expect(recorder.names == [.paywallShown, .paywallClosed])
        #expect(recorder.events.last?.reason == .swipe)
        #expect(recorder.events.allSatisfy { $0.source == "hosted" })
        window.isHidden = true
    }

    @Test func presentationModifierBuildsForEveryStyle() async throws {
        EndurancePaywall.configure(apiKey: nil, entitlementId: "premium", premiumCache: nil) { _ in }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: PresentationHost())
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await settle()
        host.rootView = PresentationHost(sheet: true, cover: true, item: PaywallRequest(source: "feature"))
        try await settle()
        window.isHidden = true
    }

    private func settle() async throws {
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(60))
        }
    }
}

private struct PresentationHost: View {
    var sheet = false
    var cover = false
    var item: PaywallRequest?

    var body: some View {
        VStack {
            Color.clear.endurancePaywall(isPresented: .constant(sheet), source: "sheet")
            Color.clear.endurancePaywall(isPresented: .constant(cover), source: PaywallSource.onboarding, style: .fullScreen)
            Color.clear.endurancePaywall(item: .constant(item))
            Color.clear.endurancePaywall(isPresented: .constant(false), source: "mock", unconfigured: Text(verbatim: "Mock"))
        }
    }
}
