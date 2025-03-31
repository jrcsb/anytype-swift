import XCTest
@testable import Anytype

final class LocalModelManagerTests: XCTestCase {
    var modelManager: LocalModelManager!
    var mockConfigBuilder: MockOllamaConfigBuilder!
    
    override func setUp() {
        super.setUp()
        mockConfigBuilder = MockOllamaConfigBuilder()
        modelManager = LocalModelManager()
        // Inject mock config builder
        modelManager.configBuilder = mockConfigBuilder
    }
    
    override func tearDown() {
        modelManager = nil
        mockConfigBuilder = nil
        super.tearDown()
    }
    
    func testModelDownloadWithSufficientResources() async throws {
        // Given
        let testModel = "testModel"
        mockConfigBuilder.modelRequirements = (ram: 4, disk: 2)
        mockConfigBuilder.availableModels = [testModel]
        
        // When
        try await modelManager.downloadModel(testModel)
        
        // Then
        let status = await modelManager.getModelStatus(testModel)
        XCTAssertEqual(status, .ready)
        
        // Verify cache
        XCTAssertNotNil(try modelManager.modelCache.getCachedModel(testModel))
    }
    
    func testModelCacheReuse() async throws {
        // Given
        let testModel = "testModel"
        let mockData = "test data".data(using: .utf8)!
        try modelManager.modelCache.cacheModel(testModel, data: mockData)
        
        // When
        try await modelManager.downloadModel(testModel)
        
        // Then
        let status = await modelManager.getModelStatus(testModel)
        XCTAssertEqual(status, .ready)
        XCTAssertEqual(try modelManager.modelCache.getCachedModel(testModel), mockData)
    }
    
    func testCacheCleanupOnLowSpace() async throws {
        // Given
        let oldModel = "oldModel"
        let newModel = "newModel"
        mockConfigBuilder.modelRequirements = (ram: 4, disk: Int.max - 1) // Force cleanup
        
        // Setup old model
        try modelManager.modelCache.cacheModel(oldModel, data: Data())
        modelManager.recordModelUse(model: oldModel)
        let oldDate = Date().addingTimeInterval(-Double(31 * 24 * 60 * 60))
        UserDefaults.standard.set([oldModel: oldDate.timeIntervalSince1970], forKey: "ModelLastUsedDates")
        
        // When/Then
        do {
            try await modelManager.downloadModel(newModel)
            XCTAssertNil(try modelManager.modelCache.getCachedModel(oldModel), "Old model should be cleaned up")
        } catch {
            XCTFail("Should clean up old models and succeed: \(error)")
        }
    }
    
    func testModelDownloadWithInsufficientResources() async throws {
        // Given
        let testModel = "testModel"
        mockConfigBuilder.modelRequirements = (ram: 999, disk: 999) // Unrealistic requirements
        
        // When/Then
        do {
            try await modelManager.downloadModel(testModel)
            XCTFail("Should throw insufficient resources error")
        } catch LocalModelError.insufficientResources {
            // Expected error
        }
    }
    
    func testModelCleanup() async throws {
        // Given
        let oldModel = "oldModel"
        mockConfigBuilder.availableModels = [oldModel]
        
        // When
        modelManager.recordModelUse(model: oldModel)
        // Simulate time passing
        let oldDate = Date().addingTimeInterval(-Double(31 * 24 * 60 * 60)) // 31 days ago
        UserDefaults.standard.set([oldModel: oldDate.timeIntervalSince1970], forKey: "ModelLastUsedDates")
        
        // Then
        try await modelManager.cleanupUnusedModels()
        let status = await modelManager.getModelStatus(oldModel)
        XCTAssertEqual(status, .notDownloaded)
    }
}

// Mock OllamaConfigBuilder for testing
class MockOllamaConfigBuilder: OllamaConfigBuilderProtocol {
    var modelRequirements: (ram: Int, disk: Int)?
    var availableModels: [String] = []
    let defaultModel = "mockModel"
    
    func makeOllamaConfig(model: String) -> AIProviderConfig {
        return AIProviderConfig()
    }
    
    func getAvailableModels() async throws -> [String] {
        return availableModels
    }
    
    func getModelRequirements(for model: String) -> (ram: Int, disk: Int)? {
        return modelRequirements
    }
    
    func getModelDescription(for model: String) -> String? {
        return "Mock description"
    }
    
    func recommendModel(for taskType: AITaskType) -> String {
        return defaultModel
    }
}
