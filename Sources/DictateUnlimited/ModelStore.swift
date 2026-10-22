import Foundation
import CryptoKit
import DictateCore

@MainActor final class ModelStore: ObservableObject {
    @Published var models: [BarkModel] = []
    @Published var installed: Set<String> = []
    @Published var downloading: String?
    @Published var progress: Double = 0
    @Published var message = "Models download only when you choose Download. Audio stays on this Mac."
    private var task: Task<Void, Never>?
    let root: URL
    private let sessionConfiguration: URLSessionConfiguration
    init(root: URL? = nil, models: [BarkModel]? = nil, sessionConfiguration: URLSessionConfiguration = .ephemeral) {
        self.sessionConfiguration = sessionConfiguration
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DOO MADE/Dictate Unlimited/Models", isDirectory: true)
        do { self.models = try models ?? ModelCatalog.load(); try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true); refresh() }
        catch { message = error.localizedDescription }
    }
    func directory(_ m: BarkModel) -> URL { root.appendingPathComponent(m.id + "-" + m.revision) }
    func refresh() { installed = Set(models.filter { FileManager.default.fileExists(atPath: directory($0).appendingPathComponent(".complete").path) }.map(\.id)) }
    func cancel() { task?.cancel() }
    func download(_ m: BarkModel, repair: Bool = false) {
        guard task == nil, (!installed.contains(m.id) || repair) else { return }
        downloading = m.id; progress = 0
        task = Task {
            let staging = root.appendingPathComponent(".partial-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: staging); downloading = nil; task = nil; refresh() }
            do {
                try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                let session = URLSession(configuration: sessionConfiguration)
                defer { session.invalidateAndCancel() }
                var total: Int64 = 0
                for file in m.files {
                    try Task.checkCancellation()
                    guard ModelCatalog.safeRelativePath(file.path) else { throw AppError("Invalid model manifest path.") }
                    message = "Downloading \(m.name): \(file.path)"
                    let url = URL(string: "https://huggingface.co/\(m.repository)/resolve/\(m.revision)/\(m.prefix)\(file.path)")!
                    let (temporary, response) = try await session.download(from: url)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AppError("Model download failed. Check your connection and retry.") }
                    try await Task.detached { try Self.verify(temporary, file) }.value
                    try Task.checkCancellation()
                    let target = staging.appendingPathComponent(file.path)
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: temporary, to: target)
                    total += file.size; progress = Double(total) / Double(m.bytes)
                }
                try Data(m.revision.utf8).write(to: staging.appendingPathComponent(".complete"))
                let destination = directory(m)
                let previous = root.appendingPathComponent(".previous-" + UUID().uuidString)
                let replacing = FileManager.default.fileExists(atPath: destination.path)
                if replacing { try FileManager.default.moveItem(at: destination, to: previous) }
                do { try FileManager.default.moveItem(at: staging, to: destination) }
                catch { if replacing { try? FileManager.default.moveItem(at: previous, to: destination) }; throw error }
                if replacing { try? FileManager.default.removeItem(at: previous) }
                message = "\(m.name) is ready to load."
            } catch is CancellationError { message = "Download cancelled. No partial model was installed." }
            catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    message = "Download cancelled. No partial model was installed."
                } else { message = error.localizedDescription }
            }
        }
    }
    nonisolated static func verify(_ url: URL, _ file: ModelFile) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attrs[.size] as? NSNumber)?.int64Value == file.size else { throw AppError("Wrong size for \(file.path). Download was not installed.") }
        if let expected = file.sha256 {
            let h = try FileHandle(forReadingFrom: url); defer { try? h.close() }
            var digest = SHA256()
            while let chunk = try h.read(upToCount: 1024 * 1024), !chunk.isEmpty { digest.update(data: chunk) }
            let actual = digest.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == expected else { throw AppError("Integrity check failed for \(file.path).") }
        }
    }
    func validate(_ m: BarkModel) async throws {
        let dir = directory(m)
        try await Task.detached { for file in m.files { try Task.checkCancellation(); try Self.verify(dir.appendingPathComponent(file.path), file) } }.value
    }
}
struct AppError: LocalizedError { let text: String; init(_ text: String) { self.text = text }; var errorDescription: String? { text } }
