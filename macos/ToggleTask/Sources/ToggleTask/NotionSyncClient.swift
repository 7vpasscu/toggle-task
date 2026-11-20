import Foundation

protocol TimeTrackingSyncClient {
    func fetchProjects() async throws -> [Project]
    func createSession(_ session: TimeSession) async throws
}

enum SyncError: LocalizedError { case notConfigured
    var errorDescription: String? { "Connect your Notion account to sync." }
}

struct NotionSyncClient: TimeTrackingSyncClient {
    func fetchProjects() async throws -> [Project] { throw SyncError.notConfigured }
    func createSession(_ session: TimeSession) async throws { throw SyncError.notConfigured }
}
