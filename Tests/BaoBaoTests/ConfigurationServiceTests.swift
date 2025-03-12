import XCTest
@testable import BaoBao

final class ConfigurationServiceTests: XCTestCase {
    
    var configManager: ConfigurationManager!
    var tempConfigURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建一个临时配置文件用于测试
        let tempDir = FileManager.default.temporaryDirectory
        tempConfigURL = tempDir.appendingPathComponent("TestConfig.plist")
        
        // 创建一个测试配置字典
        let testConfig: [String: Any] = [
            "DEEPSEEK_API_KEY": "test_api_key",
            "AZURE_SPEECH_KEY": "test_speech_key",
            "AZURE_SPEECH_REGION": "eastasia",
            "DEFAULT_VOICE_TYPE": "小明哥哥",
            "CACHE_EXPIRY_DAYS": 7,
            "MAX_CACHE_SIZE_MB": 100,
            "USE_LOCAL_FALLBACK": true,
            "USE_LOCAL_TTS_BY_DEFAULT": false
        ]
        
        // 写入临时配置文件
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: testConfig,
            format: .xml,
            options: 0
        )
        try plistData.write(to: tempConfigURL)
        
        // 注入测试依赖（使用了一个继承自ConfigurationManager的测试子类）
        configManager = TestConfigurationManager(configURL: tempConfigURL)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        
        // 清理临时文件
        if FileManager.default.fileExists(atPath: tempConfigURL.path) {
            try FileManager.default.removeItem(at: tempConfigURL)
        }
        
        configManager = nil
        tempConfigURL = nil
    }
    
    func testConfigurationLoading() throws {
        // 验证配置正确加载
        XCTAssertEqual(configManager.deepseekApiKey, "test_api_key")
        XCTAssertEqual(configManager.azureSpeechKey, "test_speech_key")
        XCTAssertEqual(configManager.azureSpeechRegion, "eastasia")
        XCTAssertEqual(configManager.defaultVoiceType, "小明哥哥")
        XCTAssertEqual(configManager.cacheExpiryDays, 7)
        XCTAssertEqual(configManager.maxCacheSizeMB, 100)
        XCTAssertTrue(configManager.useLocalFallback)
        XCTAssertFalse(configManager.useLocalTTSByDefault)
    }
    
    func testConfigurationUpdating() throws {
        // 创建临时测试配置管理器
        guard let testConfigManager = configManager as? TestConfigurationManager else {
            XCTFail("无法创建测试配置管理器")
            return
        }
        
        // 测试更新配置
        testConfigManager.updateConfig(value: "updated_api_key", forKey: "DEEPSEEK_API_KEY")
        testConfigManager.updateConfig(value: 14, forKey: "CACHE_EXPIRY_DAYS")
        testConfigManager.updateConfig(value: false, forKey: "USE_LOCAL_FALLBACK")
        
        // 重新加载配置验证更新
        testConfigManager.reloadConfiguration()
        
        // 验证配置已更新
        XCTAssertEqual(testConfigManager.deepseekApiKey, "updated_api_key")
        XCTAssertEqual(testConfigManager.cacheExpiryDays, 14)
        XCTAssertFalse(testConfigManager.useLocalFallback)
    }
    
    func testDefaultValues() throws {
        // 创建测试配置管理器但不提供完整配置
        let incompleteConfigDict: [String: Any] = [
            "DEEPSEEK_API_KEY": "test_api_key"
            // 省略其他配置，测试默认值
        ]
        
        // 写入不完整的配置文件
        let incompleteConfigURL = FileManager.default.temporaryDirectory.appendingPathComponent("IncompleteConfig.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: incompleteConfigDict,
            format: .xml,
            options: 0
        )
        try plistData.write(to: incompleteConfigURL)
        
        // 创建使用不完整配置的管理器
        let incompleteConfigManager = TestConfigurationManager(configURL: incompleteConfigURL)
        
        // 验证默认值正确应用
        XCTAssertEqual(incompleteConfigManager.deepseekApiKey, "test_api_key") // 这个有设置
        XCTAssertEqual(incompleteConfigManager.azureSpeechRegion, "eastasia") // 默认值
        XCTAssertEqual(incompleteConfigManager.maxCacheSizeMB, 100) // 默认值
        
        // 清理
        try? FileManager.default.removeItem(at: incompleteConfigURL)
    }
}

// 测试用的ConfigurationManager子类，允许我们注入测试配置URL
class TestConfigurationManager: ConfigurationManager {
    private let testConfigURL: URL
    
    init(configURL: URL) {
        self.testConfigURL = configURL
        super.init()
        loadConfiguration()
    }
    
    override func findConfigFile() -> URL? {
        return testConfigURL
    }
    
    func updateConfig(value: Any, forKey key: String) {
        // 读取现有配置
        if var config = try? PropertyListSerialization.propertyList(
            from: Data(contentsOf: testConfigURL),
            options: [],
            format: nil
        ) as? [String: Any] {
            // 更新配置
            config[key] = value
            
            // 保存更新后的配置
            if let updatedData = try? PropertyListSerialization.data(
                fromPropertyList: config,
                format: .xml,
                options: 0
            ) {
                try? updatedData.write(to: testConfigURL)
            }
        }
    }
} 