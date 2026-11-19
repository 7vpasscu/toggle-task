import XCTest
@testable import ToggleTask

final class ToggleTaskTests: XCTestCase {
    func testFormatsElapsedTime() {
        XCTAssertEqual(TimerStore.format(seconds: 3723), "01:02:03")
    }

    func testSessionDedupeKeyIncludesProjectAndRecorder() {
        let start = Date(timeIntervalSince1970: 100)
        let first = TimeSession(id: "1", projectID: "p1", projectName: "Project", description: "", startedAt: start, endedAt: nil, durationSeconds: 1, recordedBy: "Javier", source: "mock")
        let same = TimeSession(id: "2", projectID: "p1", projectName: "Project", description: "", startedAt: start, endedAt: nil, durationSeconds: 2, recordedBy: "Javier", source: "notion")
        let otherUser = TimeSession(id: "3", projectID: "p1", projectName: "Project", description: "", startedAt: start, endedAt: nil, durationSeconds: 2, recordedBy: "Carla", source: "mock")
        XCTAssertEqual(first.dedupeKey, same.dedupeKey)
        XCTAssertNotEqual(first.dedupeKey, otherUser.dedupeKey)
    }
}
