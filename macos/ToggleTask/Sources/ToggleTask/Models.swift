import Foundation

enum ProjectStatus: String, Codable, CaseIterable { case pending = "Pendiente", active = "En proceso", closed = "Cerrado" }

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
        Project(id: "job-001", name: "Carolina Herrera — Good Girl", client: "Carolina Herrera", area: "Good Girl", status: .active, historicalMinutes: 1420, participants: ["Javier", "Carla"], workTypes: ["Visuales", "Artes finales"]),
        Project(id: "job-002", name: "Rabanne — Christmas 2026", client: "Rabanne", area: "XMAS", status: .pending, historicalMinutes: 860, participants: ["Nidia"], workTypes: ["Propuestas"]),
        Project(id: "job-003", name: "L’Artisan Parfumeur — Gifting", client: "L’Artisan Parfumeur", area: "Gifting", status: .active, historicalMinutes: 430, participants: ["Javier", "Paula"], workTypes: ["Visuales"])
    ]
}
