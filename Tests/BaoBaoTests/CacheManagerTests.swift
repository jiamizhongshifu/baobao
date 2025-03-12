import XCTest
@testable import BaoBao

final class CacheManagerTests: XCTestCase {
    
    var cacheManager: CacheManager!
    var testCacheDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建临时目录作为测试缓存目录
        let tempDir = FileManager.default.temporaryDirectory
        testCacheDirectory = tempDir.appendingPathComponent("TestCache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testCacheDirectory, withIntermediateDirectories: true)
        
        // 创建测试用的CacheManager实例
        cacheManager = TestCacheManager(cacheRootDirectory: testCacheDirectory)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        
        // 清理测试缓存目录
        if FileManager.default.fileExists(atPath: testCacheDirectory.path) {
            try FileManager.default.removeItem(at: testCacheDirectory)
        }
        
        cacheManager = nil
        testCacheDirectory = nil
    }
    
    func testCacheDirectorySetup() throws {
        // 验证缓存目录是否正确创建
        for cacheType in CacheType.allCases {
            let cacheDir = testCacheDirectory.appendingPathComponent(cacheType.rawValue, isDirectory: true)
            XCTAssertTrue(FileManager.default.fileExists(atPath: cacheDir.path), "缓存目录未创建: \(cacheType.rawValue)")
        }
    }
    
    func testSavingAndRetrievingFromCache() throws {
        // 测试数据
        let testKey = "test-story-key"
        let testData = "测试故事内容".data(using: .utf8)!
        
        // 保存到缓存
        let savedURL = cacheManager.saveToCache(data: testData, forKey: testKey, type: .story)
        XCTAssertNotNil(savedURL, "保存到缓存失败")
        
        // 验证文件存在
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL!.path), "缓存文件不存在")
        
        // 从缓存获取
        let retrievedData = cacheManager.getFromCache(forKey: testKey, type: .story)
        XCTAssertNotNil(retrievedData, "从缓存获取失败")
        
        // 验证数据一致
        XCTAssertEqual(String(data: retrievedData!, encoding: .utf8), "测试故事内容", "缓存数据不一致")
    }
    
    func testCacheExpiry() throws {
        // 测试数据
        let testKey = "expiry-test-key"
        let testData = "过期测试内容".data(using: .utf8)!
        
        // 保存到缓存
        let savedURL = cacheManager.saveToCache(data: testData, forKey: testKey, type: .story)
        XCTAssertNotNil(savedURL, "保存到缓存失败")
        
        // 验证文件存在
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL!.path), "缓存文件不存在")
        
        // 修改文件的访问日期使其过期
        if let testCacheManager = cacheManager as? TestCacheManager {
            testCacheManager.makeFileExpired(at: savedURL!)
        }
        
        // 清理过期缓存
        cacheManager.cleanExpiredCache()
        
        // 验证文件已删除
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL!.path), "过期缓存文件未被删除")
        
        // 验证从缓存获取为nil
        let retrievedData = cacheManager.getFromCache(forKey: testKey, type: .story)
        XCTAssertNil(retrievedData, "过期缓存依然可以获取")
    }
    
    func testCacheSizeLimit() throws {
        // 使用大小限制测试
        if let testCacheManager = cacheManager as? TestCacheManager {
            // 设置极小的缓存大小限制
            testCacheManager.setMaxCacheSize(1024) // 1KB
            
            // 创建超过限制的数据
            let largeData = Data(repeating: 0, count: 2048) // 2KB
            let testKey = "size-limit-test"
            
            // 保存到缓存
            testCacheManager.saveToCache(data: largeData, forKey: testKey, type: .speech)
            
            // 触发缓存大小检查
            testCacheManager.checkCacheSize()
            
            // 验证是否触发了缓存清理
            XCTAssertLessThanOrEqual(testCacheManager.calculateTotalCacheSize(), 1024, "缓存大小超过限制")
        } else {
            XCTFail("无法创建测试缓存管理器")
        }
    }
    
    func testClearCache() throws {
        // 测试数据
        let testKeys = ["clear-test-1", "clear-test-2", "clear-test-3"]
        let testData = "清除测试内容".data(using: .utf8)!
        
        // 保存多个文件到缓存
        for key in testKeys {
            cacheManager.saveToCache(data: testData, forKey: key, type: .story)
        }
        
        // 清除故事类型的缓存
        cacheManager.clearCache(type: .story)
        
        // 验证所有故事缓存文件已删除
        for key in testKeys {
            let cacheURL = cacheManager.cacheFileURL(forKey: key, type: .story)
            XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path), "缓存文件未被清除: \(key)")
        }
    }
    
    func testHasCachedData() throws {
        // 测试数据
        let testKey = "has-cache-test"
        let testData = "缓存存在测试".data(using: .utf8)!
        
        // 初始状态应该没有缓存
        XCTAssertFalse(cacheManager.hasCache(forKey: testKey, type: .story), "初始不应该有缓存")
        
        // 保存到缓存
        cacheManager.saveToCache(data: testData, forKey: testKey, type: .story)
        
        // 现在应该有缓存
        XCTAssertTrue(cacheManager.hasCache(forKey: testKey, type: .story), "应该有缓存")
        
        // 清除缓存
        cacheManager.clearCache(type: .story)
        
        // 应该再次没有缓存
        XCTAssertFalse(cacheManager.hasCache(forKey: testKey, type: .story), "清除后不应该有缓存")
    }
}

// 扩展CacheType以支持遍历所有类型
extension CacheType: CaseIterable {}

// 测试用的CacheManager子类
class TestCacheManager: CacheManager {
    private let testCacheRootDirectory: URL
    private var testMaxCacheSize: Int64 = 100 * 1024 * 1024 // 默认100MB
    
    init(cacheRootDirectory: URL) {
        self.testCacheRootDirectory = cacheRootDirectory
        super.init()
        setupCacheDirectories()
    }
    
    override var cacheRootDirectory: URL {
        return testCacheRootDirectory
    }
    
    override var maxCacheSize: Int64 {
        return testMaxCacheSize
    }
    
    func setMaxCacheSize(_ size: Int64) {
        testMaxCacheSize = size
    }
    
    func makeFileExpired(at url: URL) {
        // 将文件的修改日期改为很久以前，使其过期
        let pastDate = Date(timeIntervalSinceNow: -30 * 24 * 60 * 60) // 30天前
        try? FileManager.default.setAttributes([.modificationDate: pastDate], ofItemAtPath: url.path)
    }
    
    // 暴露内部方法用于测试
    override func checkCacheSize() {
        super.checkCacheSize()
    }
    
    func calculateTotalCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        for cacheType in CacheType.allCases {
            let cacheDir = cacheRootDirectory.appendingPathComponent(cacheType.rawValue)
            if let enumerator = FileManager.default.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = attributes.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }
        
        return totalSize
    }
} 