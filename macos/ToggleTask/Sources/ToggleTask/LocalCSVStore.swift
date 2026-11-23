import Foundation
import Darwin
import JavaScriptCore

struct DesktopSnapshot: Codable {
    var projects: [Project]
    var sessions: [TimeSession]
    var active: TimeSession?
    var workerID: String?
}

enum LocalCSVStoreError: LocalizedError, Equatable {
    case codecUnavailable
    case codecFailure(String)
    case lockUnavailable(Int32)
    case conflict

    var errorDescription: String? {
        switch self {
        case .codecUnavailable:
            return "The bundled CSV codec could not be loaded."
        case .codecFailure(let message):
            return "The local CSV could not be converted: \(message)"
        case .lockUnavailable(let code):
            return "The local CSV could not be locked (error \(code))."
        case .conflict:
            return "The local CSV changed outside Task Track. Reopen the app before saving again."
        }
    }
}

final class LocalCSVStore {
    let file: URL
    private var lastRead: Data?

    init(file: URL) { self.file = file }

    static var defaultFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TaskTrack", isDirectory: true)
            .appendingPathComponent("task-track.csv", isDirectory: false)
    }

    private static var codecURL: URL? {
        Bundle.main.url(forResource: "task-track-csv", withExtension: "js")
            ?? Bundle.module.url(forResource: "task-track-csv", withExtension: "js")
    }

    private func convert(_ method: String, _ input: String) throws -> String {
        guard let url = Self.codecURL, let js = JSContext() else {
            throw LocalCSVStoreError.codecUnavailable
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        js.evaluateScript(source)
        if let exception = js.exception {
            throw LocalCSVStoreError.codecFailure(exception.toString() ?? "JavaScript error")
        }
        guard let api = js.objectForKeyedSubscript("TaskTrackCSV"), !api.isUndefined else {
            throw LocalCSVStoreError.codecFailure("The codec API is unavailable.")
        }
        let result = api.invokeMethod(method, withArguments: [input])
        if let exception = js.exception {
            throw LocalCSVStoreError.codecFailure(exception.toString() ?? "JavaScript error")
        }
        guard let result, result.isString, let text = result.toString() else {
            throw LocalCSVStoreError.codecFailure("The codec returned an unexpected value.")
        }
        guard method == "decodeDesktop" else { return text }

        // decodeDesktop intentionally exposes only desktop model fields. Recover the
        // stable profile ID from the Settings row so an empty database keeps its owner.
        let decoded = api.invokeMethod("decode", withArguments: [input])
        if let exception = js.exception {
            throw LocalCSVStoreError.codecFailure(exception.toString() ?? "JavaScript error")
        }
        guard let ownerValue = decoded?.objectForKeyedSubscript("userId"),
              !ownerValue.isNull, !ownerValue.isUndefined,
              let owner = ownerValue.toString(), !owner.isEmpty else { return text }
        guard var object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw LocalCSVStoreError.codecFailure("The desktop snapshot is invalid.")
        }
        object["workerID"] = owner
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func current() throws -> Data? {
        do { return try Data(contentsOf: file) }
        catch let e as NSError where e.domain == NSCocoaErrorDomain && e.code == NSFileReadNoSuchFileError { return nil }
    }

    private func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
        let lockFile = file.appendingPathExtension("lock")
        let descriptor = lockFile.path.withCString { path in
            Darwin.open(path, O_CREAT | O_RDWR, 0o600)
        }
        guard descriptor >= 0 else { throw LocalCSVStoreError.lockUnavailable(errno) }
        defer { _ = Darwin.close(descriptor) }

        var lockResult: Int32
        repeat { lockResult = Darwin.flock(descriptor, LOCK_EX | LOCK_NB) } while lockResult != 0 && errno == EINTR
        guard lockResult == 0 else { throw LocalCSVStoreError.lockUnavailable(errno) }
        defer { _ = Darwin.flock(descriptor, LOCK_UN) }
        return try operation()
    }

    func read() throws -> DesktopSnapshot? {
        guard let data = try current() else {
            lastRead = nil
            return nil
        }
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(DesktopSnapshot.self, from: Data(try convert("decodeDesktop", text).utf8))
        lastRead = data
        return snapshot
    }

    func write(_ snapshot: DesktopSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let json = try encoder.encode(snapshot)
        let csv = try convert("encodeDesktop", String(decoding: json, as: UTF8.self))
        _ = try convert("decodeDesktop", csv)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(csv.utf8)
        try withExclusiveLock {
            guard try current() == lastRead else { throw LocalCSVStoreError.conflict }
            try data.write(to: file, options: .atomic)
            guard try current() == data else { throw LocalCSVStoreError.conflict }
            lastRead = data
        }
    }
}
