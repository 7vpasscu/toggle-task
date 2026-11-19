import Foundation
import SwiftUI

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var projects = MockData.projects
    @Published private(set) var sessions: [TimeSession] = []
    @Published var selectedProjectID = "job-001"
    @Published var activityDescription = ""
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var syncState = "Datos simulados"

    private var timer: Timer?
    private var startedAt: Date?
    private let currentUser = "Javier"

    init() {
        sessions = [TimeSession(id: "demo-1", projectID: "job-001", projectName: MockData.projects[0].name, description: "Dirección de arte y revisión de visuales", startedAt: .now.addingTimeInterval(-5400), endedAt: .now.addingTimeInterval(-3600), durationSeconds: 1800, recordedBy: "Javier", source: "mock")]
    }

    var selectedProject: Project? { projects.first { $0.id == selectedProjectID } }
    var formattedElapsed: String { Self.format(seconds: elapsedSeconds) }

    func toggleTimer() { isRunning ? stopTimer() : startTimer() }

    func startTimer() {
        guard !isRunning else { return }
        isRunning = true; startedAt = .now; elapsedSeconds = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startedAt else { return }
            self.elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(start)))
        }
    }

    func stopTimer() {
        guard isRunning, let start = startedAt, let project = selectedProject else { return }
        timer?.invalidate(); timer = nil
        let duration = max(1, Int(Date.now.timeIntervalSince(start)))
        let session = TimeSession(id: UUID().uuidString, projectID: project.id, projectName: project.name, description: activityDescription.trimmingCharacters(in: .whitespacesAndNewlines), startedAt: start, endedAt: .now, durationSeconds: duration, recordedBy: currentUser, source: "mock")
        if !sessions.contains(where: { $0.dedupeKey == session.dedupeKey }) { sessions.insert(session, at: 0) }
        isRunning = false; startedAt = nil; elapsedSeconds = 0; syncState = "Pendiente de sincronizar"
    }

    func sync() async { syncState = "Sincronizado (simulado)" }
    static func format(seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60) }
}
