import Foundation
import SwiftUI

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var projects = MockData.projects
    @Published private var allSessions: [TimeSession] = []
    @Published var selectedProjectID = "job-001"
    @Published var activityDescription = ""
    @Published var manualMode = false
    @Published private(set) var active: TimeSession?
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var syncState = "Notion sin conectar · perfil local"
    @Published var error: String?
    let currentWorkerID: String?
    private var timer: Timer?
    private let defaults: UserDefaults?
    private let key = "task-track.sessions.v1"
    private struct Snapshot: Codable { var sessions: [TimeSession]; var active: TimeSession? }

    init(workerID: String? = "local-demo", sessions: [TimeSession]? = nil, defaults: UserDefaults? = .standard) {
        currentWorkerID = workerID; self.defaults = defaults
        if let sessions { allSessions = sessions }
        else if let data = defaults?.data(forKey: key), let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            allSessions = saved.sessions
            if let workerID, !workerID.isEmpty, saved.active?.workerID == workerID { active = saved.active }
        } else {
            allSessions = [TimeSession(id: "demo-1", projectID: "job-001", projectName: MockData.projects[0].name, description: "Exploración visual", startedAt: .now.addingTimeInterval(-5400), endedAt: .now.addingTimeInterval(-3600), durationSeconds: 1800, recordedBy: "Perfil demo", source: "mock", workerID: "local-demo")]
        }
        if let active { selectedProjectID = active.projectID; activityDescription = active.description; beginTicks() }
    }
    var sessions: [TimeSession] { SessionPolicy.owned(allSessions, by: currentWorkerID).sorted { $0.startedAt > $1.startedAt } }
    var isRunning: Bool { active != nil }
    var selectedProject: Project? { projects.first { $0.id == selectedProjectID } }
    var formattedElapsed: String { Self.format(seconds: elapsedSeconds) }
    func toggleTimer() { isRunning ? stopTimer() : startTimer() }
    func startTimer() {
        guard !isRunning, let workerID = currentWorkerID, let project = selectedProject else { return }
        active = TimeSession(id: UUID().uuidString, projectID: project.id, projectName: project.name, description: activityDescription.trimmingCharacters(in: .whitespacesAndNewlines), startedAt: .now, endedAt: nil, durationSeconds: 0, recordedBy: "Perfil local", source: "timer", workerID: workerID)
        beginTicks(); persist()
    }
    private func beginTicks() {
        elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(active?.startedAt ?? .now)))
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self, let active = self.active else { return }; self.elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(active.startedAt))) }
        }
    }
    func stopTimer() {
        guard var session = active, session.workerID == currentWorkerID else { return }
        let end = max(Date.now, session.startedAt.addingTimeInterval(1))
        session.endedAt = end; session.durationSeconds = max(1, Int(end.timeIntervalSince(session.startedAt)))
        if save(session) { active = nil; timer?.invalidate(); timer = nil; elapsedSeconds = 0; persist() }
    }
    func makeSession(start: Date, end: Date, description: String, projectID: String, id: String = UUID().uuidString, source: String = "manual") -> TimeSession? {
        guard let workerID = currentWorkerID, let project = projects.first(where: { $0.id == projectID }) else { return nil }
        return TimeSession(id: id, projectID: project.id, projectName: project.name, description: description, startedAt: start, endedAt: end, durationSeconds: Int(end.timeIntervalSince(start)), recordedBy: "Perfil local", source: source, workerID: workerID)
    }
    @discardableResult func save(_ session: TimeSession) -> Bool {
        guard let workerID = currentWorkerID, session.workerID == workerID,
              !allSessions.contains(where: { $0.id == session.id && $0.workerID != workerID }) else { error = "La sesión no pertenece a este perfil."; return false }
        guard let end = session.endedAt, end > session.startedAt, end <= Date.now.addingTimeInterval(1),
              projects.contains(where: { $0.id == session.projectID }) else { error = "Revisa el proyecto y las fechas. El fin debe ser posterior al inicio y no estar en el futuro."; return false }
        guard !sessions.contains(where: { $0.id != session.id && session.startedAt < ($0.endedAt ?? $0.startedAt) && end > $0.startedAt }),
              !(active != nil && active?.id != session.id && end > active!.startedAt) else { error = "La sesión se solapa con tiempo ya registrado o con el temporizador activo."; return false }
        var validated = session; validated.durationSeconds = Int(end.timeIntervalSince(session.startedAt))
        allSessions.removeAll { $0.id == session.id }; allSessions.append(validated); error = nil; persist(); return true
    }
    func delete(_ session: TimeSession) {
        guard session.workerID == currentWorkerID, currentWorkerID != nil else { return }
        allSessions.removeAll { $0.id == session.id && $0.workerID == currentWorkerID }; persist()
    }
    func resume(_ session: TimeSession) {
        guard !isRunning, session.workerID == currentWorkerID, currentWorkerID != nil else { return }
        selectedProjectID = session.projectID; activityDescription = session.description; manualMode = false; startTimer()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(Snapshot(sessions: allSessions, active: active)) { defaults?.set(data, forKey: key) }
    }
    func sync() async { syncState = "Notion sin conectar · sesiones locales" }
    nonisolated static func format(seconds: Int) -> String { let s = max(0, seconds); return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
}
