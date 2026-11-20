import Foundation

struct AppActivity: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    let workerID: String
    let appID: String
    let appName: String
    var start: Date
    var end: Date
    var seconds: Int { max(0, Int(end.timeIntervalSince(start))) }
}

/// Records only observed foreground intervals. No inference across sleep or polling gaps.
struct ActivityLedger: Codable {
    var intervals: [AppActivity] = []
    var pending: AppActivity?

    mutating func sample(workerID: String?, appID: String?, appName: String?, at now: Date, eligible: Bool) {
        intervals.removeAll { $0.end < now.addingTimeInterval(-7 * 86400) }
        guard eligible, let workerID, !workerID.isEmpty, let appID, let appName else { finish(); return }
        if var p = pending, p.workerID == workerID, p.appID == appID,
           now >= p.end, now.timeIntervalSince(p.end) <= 10 {
            p.end = now; pending = p
        } else {
            finish()
            pending = AppActivity(workerID: workerID, appID: appID, appName: appName, start: now, end: now)
        }
    }
    mutating func finish() {
        if let p = pending, p.seconds >= 15 { intervals.append(p) }
        pending = nil
    }
    func suggestions(for workerID: String?) -> [AppActivity] {
        guard let workerID, !workerID.isEmpty else { return [] }
        return intervals.filter { $0.workerID == workerID }.sorted { $0.start > $1.start }
    }
}
