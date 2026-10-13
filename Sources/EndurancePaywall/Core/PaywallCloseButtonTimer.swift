import Foundation

/// When the package's X appears: hidden for `delay` seconds after the
/// paywall shows up, then it fades in and works normally.
///
/// The wait is injectable (`sleep`) so the logic is tested without real time.
/// `sleep` is `@Sendable` and nonisolated: it never runs during rendering.
struct PaywallCloseButtonTimer: Sendable {
    /// Seconds the X stays hidden. Negative or non-finite values count as 0.
    let delay: TimeInterval
    private let sleep: @Sendable (Duration) async throws -> Void

    /// Fade-in once the delay is over.
    static let fadeInDuration: TimeInterval = 0.35

    init(
        delay: TimeInterval,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.delay = delay.isFinite ? max(0, delay) : 0
        self.sleep = sleep
    }

    /// The X is visible from the first frame (no wait, no fade).
    var isVisibleImmediately: Bool { delay == 0 }

    /// Waits out the delay. `true` = show the X now; `false` = the wait was
    /// cancelled (the paywall left the screen first), keep it hidden.
    func waitUntilVisible() async -> Bool {
        if isVisibleImmediately { return !Task.isCancelled }
        do {
            try await sleep(.milliseconds(Int64((delay * 1000).rounded())))
        } catch {
            return false
        }
        return !Task.isCancelled
    }
}
