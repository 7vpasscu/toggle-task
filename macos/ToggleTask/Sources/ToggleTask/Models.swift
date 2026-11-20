import Foundation

enum ProjectStatus: String, Codable, CaseIterable { case pending = "Pending", active = "Active", closed = "Closed" }

struct Project: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var client: String
    var area: String
    var status: ProjectStatus
    var historicalMinutes: Int
    var participants: [String]
    var workTypes: [String]
}

struct TimeSession: Identifiable, Codable, Hashable {
    let id: String
    var projectID: String
    var projectName: String
    var description: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int
    var recordedBy: String
    var source: String
    // Stable application identity, independent of Notion's integration Created By.
    // Legacy records without an explicit owner remain hidden until mapped.
    var workerID: String? = nil

    var dedupeKey: String { id }
}

enum SessionPolicy {
    static func owned(_ sessions: [TimeSession], by workerID: String?) -> [TimeSession] {
        guard let workerID, !workerID.isEmpty else { return [] }
        return sessions.filter { $0.workerID == workerID }
    }
    static func overlap(_ session: TimeSession, day: DateInterval) -> TimeInterval {
        max(0, min(session.endedAt ?? session.startedAt, day.end).timeIntervalSince(max(session.startedAt, day.start)))
    }
}

enum MockData {
    static let projects = [
        Project(id: "job-001", name: "Carolina Herrera — Good Girl", client: "Carolina Herrera", area: "Good Girl", status: .active, historicalMinutes: 1420, participants: ["Javier", "Carla"], workTypes: ["Visuals", "Final artwork"]),
        Project(id: "job-002", name: "Rabanne — Christmas 2026", client: "Rabanne", area: "XMAS", status: .pending, historicalMinutes: 860, participants: ["Nidia"], workTypes: ["Proposals"]),
        Project(id: "job-003", name: "L’Artisan Parfumeur — Gifting", client: "L’Artisan Parfumeur", area: "Gifting", status: .active, historicalMinutes: 430, participants: ["Javier", "Paula"], workTypes: ["Visuals"])
    ]
}

enum EntryDuration {
    static func minutes(_ raw: String) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.range(of: #"^[0-9]{1,2}$"#, options: .regularExpression) != nil {
            guard let n = Int(text), n > 0 else { return nil }
            return n
        }
        guard text.range(of: #"^[0-9]{1,4}:?[0-5][0-9]$"#, options: .regularExpression) != nil else { return nil }
        let digits = text.replacingOccurrences(of: ":", with: "")
        guard let h = Int(digits.dropLast(2)), let m = Int(digits.suffix(2)) else { return nil }
        let total = h * 60 + m
        return (1...100000).contains(total) ? total : nil
    }
    static func format(seconds: Int) -> String {
        let minutes = max(0, Int((Double(seconds) / 60).rounded()))
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
