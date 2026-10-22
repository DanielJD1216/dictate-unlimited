import Foundation
public struct ModelFile: Codable, Sendable { public let path: String; public let size: Int64; public let sha256: String? }
public struct BarkModel: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let repository: String
    public let revision: String
    public let prefix: String
    public let precision: String
    public let files: [ModelFile]
    public var bytes: Int64 { files.reduce(0) { $0 + $1.size } }
    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
}
public enum ModelCatalog {
    public static func load() throws -> [BarkModel] {
        let packaged = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("DictateUnlimited_DictateCore.bundle")) }
        let resources = packaged ?? Bundle.module
        guard let url = resources.url(forResource: "models", withExtension: "json") else { throw CatalogError.missing }
        return try JSONDecoder().decode([BarkModel].self, from: Data(contentsOf: url))
    }
    public static func safeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
    }
    enum CatalogError: Error { case missing }
}
public enum AudioLimits {
    public static let sampleRate = 16000
    public static let maximumSeconds = 300
    public static func valid(_ samples: [Float]) -> Bool { !samples.isEmpty && samples.count <= sampleRate * maximumSeconds && samples.allSatisfy(\.isFinite) }
}
