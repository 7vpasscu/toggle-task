import XCTest
@testable import ToggleTask

final class ToggleTaskTests: XCTestCase {
    func testCSVReopensACompletedSessionAndRunningTimer() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = folder.appendingPathComponent("task-track.csv")
        defer { try? FileManager.default.removeItem(at: folder) }
        let clock = Date(timeIntervalSince1970: 1720000000)
        let session = TimeSession(id: "s", projectID: "job-001", projectName: "P", description: "Layout, \"print\"\nnext", startedAt: clock, endedAt: clock.addingTimeInterval(60), durationSeconds: 60, recordedBy: "Alice", source: "manual", workerID: "alice", workType: "Layout", units: 2)
        var running = session; running.endedAt = nil
        let store = LocalCSVStore(file: url)
        try store.write(DesktopSnapshot(projects: MockData.projects, sessions: [session], active: nil, workerID: "alice"))
        let restored = try XCTUnwrap(LocalCSVStore(file: url).read())
        XCTAssertEqual(restored.sessions.first?.description, session.description)
        XCTAssertEqual(restored.sessions.first?.workerID, "alice")
        XCTAssertEqual(restored.sessions.first?.units, 2)
        try store.write(DesktopSnapshot(projects: MockData.projects, sessions: [], active: running, workerID: "alice"))
        XCTAssertEqual(try LocalCSVStore(file: url).read()?.active?.id, "s")
        try Data("broken".utf8).write(to: url)
        XCTAssertThrowsError(try store.write(restored)) { error in
            XCTAssertEqual(error as? LocalCSVStoreError, .conflict)
        }
        XCTAssertEqual(try String(contentsOf: url), "broken")
    }

    func testCSVRejectsAStaleWriterWithoutOverwritingNewerData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = folder.appendingPathComponent("task-track.csv")
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = LocalCSVStore(file: url)
        let second = LocalCSVStore(file: url)
        let original = DesktopSnapshot(projects: MockData.projects, sessions: [], active: nil, workerID: "alice")
        try first.write(original)
        _ = try first.read()
        _ = try second.read()

        var newer = original
        newer.workerID = "newer-writer"
        try first.write(newer)
        XCTAssertThrowsError(try second.write(original)) { error in
            XCTAssertEqual(error as? LocalCSVStoreError, .conflict)
        }
        XCTAssertEqual(try LocalCSVStore(file: url).read()?.workerID, "newer-writer")
        XCTAssertTrue(try String(contentsOf: url).contains("newer-writer"))
    }

    @MainActor func testLegacyDefaultsMigrateOnceAndAssignTheStableWorker() throws {
        struct LegacySnapshot: Codable { var sessions: [TimeSession]; var active: TimeSession? }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = folder.appendingPathComponent("task-track.csv")
        let suite = "TaskTrackTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let now = Date.now
        let legacy = TimeSession(id: "legacy", projectID: "job-001", projectName: MockData.projects[0].name, description: "Legacy session", startedAt: now.addingTimeInterval(-120), endedAt: now.addingTimeInterval(-60), durationSeconds: 60, recordedBy: "Local profile", source: "timer")
        defaults.set(try JSONEncoder().encode(LegacySnapshot(sessions: [legacy], active: nil)), forKey: "task-track.sessions.v1")

        let migrated = TimerStore(workerID: "alice", defaults: defaults, file: url)
        XCTAssertEqual(migrated.sessions.first?.workerID, "alice")
        XCTAssertNil(defaults.data(forKey: "task-track.sessions.v1"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        var replacement = legacy
        replacement.description = "Must not be imported"
        defaults.set(try JSONEncoder().encode(LegacySnapshot(sessions: [replacement], active: nil)), forKey: "task-track.sessions.v1")
        let reopened = TimerStore(workerID: "alice", defaults: defaults, file: url)
        XCTAssertEqual(reopened.sessions.first?.description, "Legacy session")
    }

    @MainActor func testTimerStoreRecoversAndCompletesARunningTimer() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = folder.appendingPathComponent("task-track.csv")
        defer { try? FileManager.default.removeItem(at: folder) }
        let startedAt = Date.now.addingTimeInterval(-120)
        let running = TimeSession(id: "running", projectID: "job-001", projectName: MockData.projects[0].name, description: "Recovered timer", startedAt: startedAt, endedAt: nil, durationSeconds: 0, recordedBy: "Local profile", source: "timer", workerID: "alice")
        try LocalCSVStore(file: url).write(DesktopSnapshot(projects: MockData.projects, sessions: [], active: running, workerID: "alice"))

        let store = TimerStore(workerID: "alice", defaults: nil, file: url)
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.active?.id, "running")
        XCTAssertEqual(store.selectedProjectID, "job-001")
        XCTAssertEqual(store.activityDescription, "Recovered timer")
        XCTAssertGreaterThanOrEqual(store.elapsedSeconds, 119)
        store.stopTimer()

        let persisted = try XCTUnwrap(LocalCSVStore(file: url).read())
        XCTAssertNil(persisted.active)
        XCTAssertEqual(persisted.sessions.first?.id, "running")
        XCTAssertGreaterThanOrEqual(persisted.sessions.first?.durationSeconds ?? 0, 119)
    }

    func testFormatsElapsedTime() {
        XCTAssertEqual(TimerStore.format(seconds: 3723), "01:02")
        for (input, minutes) in [("26",26), ("126",86), ("0126",86), ("1:26",86), ("1000",600)] {
            XCTAssertEqual(EntryDuration.minutes(input), minutes)
        }
        for input in ["0","160","1:60","-5","1:2:3"] { XCTAssertNil(EntryDuration.minutes(input)) }
    }

    func testStableSessionIDIsDedupeKey() {
        let start = Date(timeIntervalSince1970: 100)
        let first = TimeSession(id: "1", projectID: "p1", projectName: "Project", description: "", startedAt: start, endedAt: nil, durationSeconds: 1, recordedBy: "Javier", source: "mock")
        let same = TimeSession(id: "1", projectID: "p1", projectName: "Project", description: "", startedAt: start, endedAt: nil, durationSeconds: 2, recordedBy: "Integration bot", source: "notion")
        let otherUser = TimeSession(id: "3", projectID: "p1", projectName: "Project", description: "", startedAt: start, endedAt: nil, durationSeconds: 2, recordedBy: "Carla", source: "mock")
        XCTAssertEqual(first.dedupeKey, same.dedupeKey)
        XCTAssertNotEqual(first.dedupeKey, otherUser.dedupeKey)
    }

    func testOwnershipNeverFallsBackToCreatedByOrDisplayName() {
        let s = TimeSession(id: "a", projectID: "p", projectName: "P", description: "", startedAt: .now, endedAt: .now, durationSeconds: 1, recordedBy: "Bot", source: "notion", workerID: "alice")
        var other = s; other.workerID = "bob"
        var legacy = s; legacy.workerID = nil
        XCTAssertEqual(SessionPolicy.owned([s, other, legacy], by: "alice").count, 1)
        XCTAssertEqual(SessionPolicy.owned([s, other, legacy], by: nil).count, 0)
    }

    func testActivityDoesNotBridgeIdleSleepOrWorkers() {
        var ledger = ActivityLedger()
        let start = Date(timeIntervalSince1970: 1000)
        for t in stride(from: 0, through: 20, by: 2) { ledger.sample(workerID: "a", appID: "editor", appName: "Editor", at: start.addingTimeInterval(Double(t)), eligible: true) }
        ledger.sample(workerID: "b", appID: "editor", appName: "Editor", at: start.addingTimeInterval(22), eligible: true)
        ledger.sample(workerID: "b", appID: "editor", appName: "Editor", at: start.addingTimeInterval(500), eligible: true)
        ledger.sample(workerID: "b", appID: nil, appName: nil, at: start.addingTimeInterval(502), eligible: false)
        XCTAssertEqual(ledger.suggestions(for: "a").map(\.seconds), [20])
        XCTAssertEqual(ledger.suggestions(for: "b").count, 0)
        XCTAssertNil(ledger.pending)
    }

    @MainActor func testStoreRejectsForeignSessionAndSnapshotsRunningProject() {
        let store = TimerStore(workerID: "alice", sessions: [], defaults: nil)
        store.startTimer(); let project = store.active!.projectID
        store.selectedProjectID = "job-002"; store.stopTimer()
        XCTAssertEqual(store.sessions.first?.projectID, project)
        var foreign = store.sessions.first!; foreign.workerID = "bob"
        XCTAssertFalse(store.save(foreign))
        store.delete(foreign); XCTAssertEqual(store.sessions.count, 1)
    }
}
