import AppKit
import Combine
import CoreGraphics

@MainActor
final class AppActivityMonitor: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var ledger = ActivityLedger()
    private let workerID: String?
    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var suspended = false
    private let storageKey = "task-track.activity.v1"

    init(workerID: String?, defaults: UserDefaults = .standard) {
        self.workerID = workerID; self.defaults = defaults
        if let data = defaults.data(forKey: storageKey), let saved = try? JSONDecoder().decode(ActivityLedger.self, from: data) {
            ledger = saved; ledger.finish()
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspended = true; self?.flush() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspended = false }
            })
        }
        // Deliberately off on every launch; recording requires an explicit choice.
    }
    var suggestions: [AppActivity] { ledger.suggestions(for: workerID) }
    func setEnabled(_ value: Bool) {
        enabled = value && workerID != nil
        timer?.invalidate(); timer = nil
        if enabled {
            sample()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.sample() }
            }
        } else { flush() }
    }
    private func sample() {
        guard enabled else { return }
        let app = NSWorkspace.shared.frontmostApplication
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        let eligible = !suspended && idle < 120 && app?.processIdentifier != ProcessInfo.processInfo.processIdentifier
        ledger.sample(workerID: workerID, appID: app?.bundleIdentifier, appName: app?.localizedName, at: .now, eligible: eligible)
        persist()
    }
    func flush() { ledger.finish(); persist() }
    func dismiss(_ id: String) {
        ledger.intervals.removeAll { $0.id == id && $0.workerID == workerID }; persist()
    }
    func clear() {
        ledger.intervals.removeAll { $0.workerID == workerID }
        if ledger.pending?.workerID == workerID { ledger.pending = nil }
        persist()
    }
    private func persist() { if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: storageKey) } }
    deinit { timer?.invalidate(); observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) } }
}
