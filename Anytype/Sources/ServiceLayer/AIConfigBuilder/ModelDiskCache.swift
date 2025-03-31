import Foundation

protocol ModelDiskCacheProtocol {
    func cacheModel(_ model: String, data: Data) throws
    func getCachedModel(_ model: String) -> Data?
    func removeCachedModel(_ model: String) throws
    func getCacheSize() throws -> Int64
    func clearCache() throws
}

final class ModelDiskCache: ModelDiskCacheProtocol {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() throws {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("OllamaModels", isDirectory: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cacheModel(_ model: String, data: Data) throws {
        let fileURL = cacheDirectory.appendingPathComponent(model)
        try data.write(to: fileURL)
    }
    
    func getCachedModel(_ model: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(model)
        return try? Data(contentsOf: fileURL)
    }
    
    func removeCachedModel(_ model: String) throws {
        let fileURL = cacheDirectory.appendingPathComponent(model)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    func getCacheSize() throws -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(at: cacheDirectory,
                                                    includingPropertiesForKeys: Array(resourceKeys)) else {
            throw NSError(domain: "ModelDiskCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate cache directory"])
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let fileSize = resourceValues.totalFileAllocatedSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        return totalSize
    }
    
    func clearCache() throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for file in contents {
            try fileManager.removeItem(at: file)
        }
    }
}
