import Foundation
import SwiftUI
import Darwin

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var projects = MockData.projects
    @Published private var allSessions: [TimeSession] = []
    @Published var selectedProjectID = "job-001"
    @Published var activityDescription = ""
    @Published var manualMode = false
    @Published private(set) var active: TimeSession?
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var syncState = "Notion disconnected · Local CSV"
    @Published var error: String?
    private(set) var currentWorkerID: String?
    private var timer: Timer?
    private let csv: LocalCSVStore?
    private var locked = false
    private let legacyKey = "task-track.sessions.v1"
    private struct Snapshot: Codable { var sessions: [TimeSession]; var active: TimeSession? }

    init(workerID: String? = nil, sessions: [TimeSession]? = nil, defaults: UserDefaults? = .standard, file: URL? = nil) {
        self.currentWorkerID = workerID ?? "local:macos:\(Darwin.getuid())"
        self.csv = sessions == nil ? LocalCSVStore(file: file ?? LocalCSVStore.defaultFile) : nil
        do {
            if let sessions { allSessions = sessions }
            else if let snapshot = try csv?.read() {
                if workerID == nil, let savedWorkerID = snapshot.workerID, !savedWorkerID.isEmpty {
                    currentWorkerID = savedWorkerID
                }
                projects = snapshot.projects
                allSessions = snapshot.sessions
                active = snapshot.active
            } else {
                var migratedLegacyData = false
                if let old = defaults?.data(forKey: legacyKey) {
                    let saved = try JSONDecoder().decode(Snapshot.self, from: old)
                    allSessions = saved.sessions.map { session in
                        var migrated = session
                        if migrated.workerID == nil { migrated.workerID = currentWorkerID }
                        return migrated
                    }
                    active = saved.active.map { session in
                        var migrated = session
                        if migrated.workerID == nil { migrated.workerID = currentWorkerID }
                        return migrated
                    }
                    migratedLegacyData = true
                } else if let workerID = currentWorkerID {
                    allSessions = [TimeSession(id: "demo-1", projectID: "job-001", projectName: MockData.projects[0].name, description: "Visual exploration", startedAt: .now.addingTimeInterval(-5400), endedAt: .now.addingTimeInterval(-3600), durationSeconds: 1800, recordedBy: "Demo profile", source: "mock", workerID: workerID)]
                } else {
                    allSessions = []
                }
                try csv?.write(DesktopSnapshot(projects: projects, sessions: allSessions, active: active, workerID: currentWorkerID))
                if migratedLegacyData { defaults?.removeObject(forKey: legacyKey) }
            }
            if let active {
                guard let workerID = currentWorkerID, active.workerID == workerID,
                      active.startedAt <= Date.now.addingTimeInterval(1) else {
                    throw CocoaError(.fileReadNoPermission)
                }
                selectedProjectID = active.projectID
                activityDescription = active.description
                beginTicks()
            } else if !projects.contains(where: { $0.id == selectedProjectID }), let first = projects.first {
                selectedProjectID = first.id
            }
        } catch {
            active = nil; locked = true
            syncState = "Could not open the local CSV. Your existing files are preserved."
            self.error = syncState
        }
    }
    var sessions: [TimeSession] { SessionPolicy.owned(allSessions, by: currentWorkerID).sorted { $0.startedAt > $1.startedAt } }
    var isRunning: Bool { active != nil }
    var selectedProject: Project? { projects.first { $0.id == selectedProjectID } }
    var formattedElapsed: String { Self.format(seconds: elapsedSeconds) }
    func toggleTimer() { isRunning ? stopTimer() : startTimer() }
    func startTimer() {
        guard !isRunning, let workerID = currentWorkerID, let project = selectedProject else { return }
        let started = TimeSession(id: UUID().uuidString, projectID: project.id, projectName: project.name, description: activityDescription.trimmingCharacters(in: .whitespacesAndNewlines), startedAt: .now, endedAt: nil, durationSeconds: 0, recordedBy: "Local profile", source: "timer", workerID: workerID)
        if commit(allSessions, running: started) { beginTicks() }
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
        if save(session) { timer?.invalidate(); timer = nil; elapsedSeconds = 0 }
    }
    func makeSession(start: Date, end: Date, description: String, projectID: String, id: String = UUID().uuidString, source: String = "manual") -> TimeSession? {
        guard let workerID = currentWorkerID, let project = projects.first(where: { $0.id == projectID }) else { return nil }
        return TimeSession(id: id, projectID: project.id, projectName: project.name, description: description, startedAt: start, endedAt: end, durationSeconds: Int(end.timeIntervalSince(start)), recordedBy: "Local profile", source: source, workerID: workerID)
    }
    @discardableResult func save(_ session: TimeSession) -> Bool {
        guard let workerID = currentWorkerID, session.workerID == workerID,
              !allSessions.contains(where: { $0.id == session.id && $0.workerID != workerID }) else { error = "This session belongs to another profile."; return false }
        guard let end = session.endedAt, end > session.startedAt, end <= Date.now.addingTimeInterval(1),
              projects.contains(where: { $0.id == session.projectID }) else { error = "Choose a project and check the times. End the session after it starts and by the current time."; return false }
        var validated = session; validated.durationSeconds = Int(end.timeIntervalSince(session.startedAt))
        let next = allSessions.filter { $0.id != session.id } + [validated]
        return commit(next, running: active?.id == session.id ? nil : active)
    }
    func delete(_ session: TimeSession) {
        guard session.workerID == currentWorkerID, currentWorkerID != nil else { return }
        _ = commit(allSessions.filter { $0.id != session.id || $0.workerID != currentWorkerID }, running: active)
    }
    func resume(_ session: TimeSession) {
        guard !isRunning, session.workerID == currentWorkerID, currentWorkerID != nil else { return }
        selectedProjectID = session.projectID; activityDescription = session.description; manualMode = false; startTimer()
    }
    private func commit(_ sessions: [TimeSession], running: TimeSession?) -> Bool {
        guard !locked else { error = syncState; return false }
        do {
            try csv?.write(DesktopSnapshot(projects: projects, sessions: sessions, active: running, workerID: currentWorkerID))
            allSessions = sessions; active = running; error = nil; syncState = "Saved to local CSV"
            return true
        } catch LocalCSVStoreError.conflict {
            locked = true
            syncState = "Local CSV changed outside Task Track"
            error = "The local CSV changed outside Task Track. Reopen the app before saving again."
            return false
        } catch {
            locked = true
            self.error = "Could not save the local CSV. Check its permissions, then reopen the app."
            syncState = "Could not save the local CSV"
            return false
        }
    }
    func sync() async { syncState = "Notion disconnected · Sessions saved to local CSV" }
    nonisolated static func format(seconds: Int) -> String { EntryDuration.format(seconds: seconds) }
}
