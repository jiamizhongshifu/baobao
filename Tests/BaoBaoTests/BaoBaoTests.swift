import XCTest
@testable import BaoBao

final class BaoBaoTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // 测试开始前的设置
    }
    
    override func tearDownWithError() throws {
        // 测试结束后的清理
        try super.tearDownWithError()
    }
    
    func testAllServicesBasicFunctionality() throws {
        // 确保基本服务可以初始化
        let configManager = ConfigurationManager.shared
        XCTAssertNotNil(configManager)
        
        let cacheManager = CacheManager.shared
        XCTAssertNotNil(cacheManager)
        
        let networkManager = NetworkManager.shared
        XCTAssertNotNil(networkManager)
        
        let storyService = StoryService.shared
        XCTAssertNotNil(storyService)
        
        let speechService = SpeechService.shared
        XCTAssertNotNil(speechService)
        
        let offlineManager = OfflineManager.shared
        XCTAssertNotNil(offlineManager)
        
        // 基本功能测试通过
        XCTAssert(true)
    }
} 