import Foundation
@testable import EndurancePaywall

/// Thread-safe analytics fake: records every event, from any thread.
final class RecordingAnalytics: PaywallAnalytics, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [PaywallEvent] = []
    private var storedProperties: [(name: String, value: String?)] = []

    func track(_ event: PaywallEvent) {
        lock.lock(); defer { lock.unlock() }
        stored.append(event)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        lock.lock(); defer { lock.unlock() }
        storedProperties.append((name, value))
    }

    var userProperties: [(name: String, value: String?)] {
        lock.lock(); defer { lock.unlock() }
        return storedProperties
    }

    var events: [PaywallEvent] {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    var names: [PaywallEvent.Name] { events.map(\.name) }
}

func freshDefaults(_ name: String = #function) -> UserDefaults {
    let suite = "EndurancePaywallTests.\(name).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
