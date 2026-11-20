import XCTest
@testable import ToggleTask

final class ToggleTaskTests: XCTestCase {
    func testFormatsElapsedTime() {
        XCTAssertEqual(TimerStore.format(seconds: 3723), "01:02:03")
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
