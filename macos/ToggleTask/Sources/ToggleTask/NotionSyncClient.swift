import Foundation

protocol TimeTrackingSyncClient {
    func fetchProjects() async throws -> [Project]
    func createSession(_ session: TimeSession) async throws
}

enum SyncError: LocalizedError { case notConfigured
    var errorDescription: String? { "La autenticación de Notion aún no está configurada." }
}

struct NotionSyncClient: TimeTrackingSyncClient {
    func fetchProjects() async throws -> [Project] { throw SyncError.notConfigured }
    func createSession(_ session: TimeSession) async throws { throw SyncError.notConfigured }
}
