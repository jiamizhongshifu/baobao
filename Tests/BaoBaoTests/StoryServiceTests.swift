import XCTest
import Combine
@testable import BaoBao

final class StoryServiceTests: XCTestCase {
    
    var storyService: TestStoryService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        storyService = TestStoryService()
    }
    
    override func tearDownWithError() throws {
        storyService = nil
        cancellables.removeAll()
        try super.tearDownWithError()
    }
    
    func testStoryGeneration() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "故事生成")
        
        // 模拟网络在线
        storyService.networkManager.setConnected(true)
        
        // 设置主题和长度
        let theme = StoryTheme.space
        let characterName = "小明"
        let length = StoryLength.medium
        
        // 生成故事
        storyService.generateStory(theme: theme, characterName: characterName, length: length) { result in
            switch result {
            case .success(let story):
                // 验证故事属性
                XCTAssertEqual(story.theme, theme.rawValue)
                XCTAssertEqual(story.childName, characterName)
                XCTAssertFalse(story.content.isEmpty)
                XCTAssertFalse(story.title.isEmpty)
                XCTAssertTrue(story.content.contains(characterName), "故事内容应包含角色名")
                
                // 验证故事长度
                let contentLength = story.content.count
                XCTAssertGreaterThanOrEqual(contentLength, length.wordCount.lowerBound)
                XCTAssertLessThanOrEqual(contentLength, length.wordCount.upperBound * 2) // 允许一定的长度偏差
                
            case .failure(let error):
                XCTFail("故事生成失败: \(error.localizedDescription)")
            }
            
            expectation.fulfill()
        }
        
        // 等待故事生成完成
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testStoryGenerationWithOfflineMode() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "离线模式故事生成")
        
        // 启用离线模式
        storyService.networkManager.enableOfflineMode()
        
        // 确保故事缓存为空
        storyService.cacheManager.clearCache(type: .story)
        
        // 尝试生成故事
        storyService.generateStory(theme: .forest, characterName: "小红", length: .short) { result in
            switch result {
            case .success:
                XCTFail("离线模式下没有缓存时不应该成功生成故事")
            case .failure(let error):
                if case .offlineMode = error {
                    // 预期的错误
                    XCTAssert(true)
                } else if case .noCache = error {
                    // 也可能是缓存不可用错误
                    XCTAssert(true)
                } else {
                    XCTFail("离线模式下应返回离线模式或缓存不可用错误")
                }
            }
            
            expectation.fulfill()
        }
        
        // 等待故事生成完成
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCachedStoryRetrieval() throws {
        // 创建期望
        let expectation1 = XCTestExpectation(description: "首次故事生成")
        let expectation2 = XCTestExpectation(description: "缓存故事获取")
        
        // 模拟网络在线
        storyService.networkManager.setConnected(true)
        
        // 生成故事
        let theme = StoryTheme.ocean
        let characterName = "小华"
        let length = StoryLength.short
        
        // 首次生成故事
        storyService.generateStory(theme: theme, characterName: characterName, length: length) { result in
            switch result {
            case .success(let story):
                // 保存首次生成的故事内容
                let firstContent = story.content
                
                // 再次生成相同参数的故事，应该返回缓存
                self.storyService.generateStory(theme: theme, characterName: characterName, length: length) { secondResult in
                    switch secondResult {
                    case .success(let cachedStory):
                        // 验证故事内容与首次生成相同
                        XCTAssertEqual(cachedStory.content, firstContent, "第二次应返回缓存的故事")
                        XCTAssertTrue(self.storyService.usedCache, "应使用缓存")
                    case .failure(let error):
                        XCTFail("缓存检索失败: \(error.localizedDescription)")
                    }
                    
                    expectation2.fulfill()
                }
                
            case .failure(let error):
                XCTFail("故事生成失败: \(error.localizedDescription)")
                expectation2.fulfill()
            }
            
            expectation1.fulfill()
        }
        
        // 等待两个操作完成
        wait(for: [expectation1, expectation2], timeout: 5.0)
    }
    
    func testStoryGenerationFailureRetry() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "故事生成重试")
        
        // 设置服务在第一次尝试时失败，第二次成功
        storyService.shouldFailOnFirstAttempt = true
        
        // 模拟网络在线
        storyService.networkManager.setConnected(true)
        
        // 生成故事
        storyService.generateStory(theme: .fairy, characterName: "小丽", length: .long) { result in
            switch result {
            case .success(let story):
                // 成功应该是通过重试机制实现的
                XCTAssertEqual(self.storyService.retryCount, 1, "应尝试重试一次")
                XCTAssertFalse(story.content.isEmpty)
            case .failure(let error):
                XCTFail("故事生成应通过重试成功，但失败了: \(error.localizedDescription)")
            }
            
            expectation.fulfill()
        }
        
        // 等待重试完成
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCancelStoryGeneration() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "取消故事生成")
        
        // 确保初始状态
        XCTAssertEqual(storyService.generationStatus, .idle)
        
        // this needs to be serial because the completion handler will get reset by the cancel call
        let longGenerationDispatchGroup = DispatchGroup()
        
        // 开始生成故事
        longGenerationDispatchGroup.enter()
        storyService.simulateLongGeneration(theme: .dinosaur, characterName: "小龙", length: .long) { result in
            switch result {
            case .success:
                XCTFail("取消后不应返回成功")
            case .failure(let error):
                if case .generationFailed = error {
                    // 预期的错误
                    XCTAssert(true)
                } else {
                    XCTFail("取消后应返回生成失败错误")
                }
            }
            longGenerationDispatchGroup.leave()
        }
        
        // 确认生成已开始
        XCTAssertEqual(storyService.generationStatus, .generating)
        
        // 取消生成
        storyService.cancelGeneration()
        
        // 验证状态重置
        XCTAssertEqual(storyService.generationStatus, .idle)
        
        longGenerationDispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }
        
        // 等待操作完成
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStoryGenerationStatusPublisher() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "状态发布者更新")
        
        // 变量跟踪状态变化
        var receivedStatuses: [StoryGenerationStatus] = []
        
        // 订阅状态变化
        storyService.generationStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 开始生成故事然后完成
        storyService.simulateSuccessfulGeneration()
        
        // 等待状态更新
        wait(for: [expectation], timeout: 2.0)
        
        // 验证状态更新
        XCTAssertEqual(receivedStatuses.count, 2, "应该收到两次状态更新")
        XCTAssertEqual(receivedStatuses[0], .generating, "第一次更新应为生成中状态")
        XCTAssertEqual(receivedStatuses[1], .idle, "第二次更新应为空闲状态")
    }
}

// 用于测试的StoryService子类
class TestStoryService: StoryService {
    
    let testNetworkManager = TestNetworkManager()
    let testCacheManager = CacheManager()
    var usedCache = false
    var retryCount = 0
    var shouldFailOnFirstAttempt = false
    var longGenerationCompletionHandler: ((Result<Story, StoryServiceError>) -> Void)?
    
    override var networkManager: NetworkManager {
        return testNetworkManager
    }
    
    override var cacheManager: CacheManager {
        return testCacheManager
    }
    
    // 模拟长时间生成过程
    func simulateLongGeneration(theme: StoryTheme, characterName: String, length: StoryLength, completion: @escaping (Result<Story, StoryServiceError>) -> Void) {
        generationStatus = .generating
        longGenerationCompletionHandler = completion
    }
    
    // 模拟成功的生成过程
    func simulateSuccessfulGeneration() {
        generationStatus = .generating
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.generationStatus = .idle
        }
    }
    
    // 重写故事生成方法
    override func generateStory(theme: StoryTheme, characterName: String, length: StoryLength, additionalPrompt: String? = nil, completion: @escaping (Result<Story, StoryServiceError>) -> Void) {
        // 检查是否使用缓存
        let cacheKey = generateCacheKey(theme: theme, characterName: characterName, length: length)
        
        if testCacheManager.hasCache(forKey: cacheKey, type: .story),
           let cachedData = testCacheManager.getFromCache(forKey: cacheKey, type: .story),
           let cachedStoryString = String(data: cachedData, encoding: .utf8),
           let cachedStory = Story(dictionary: parseStoryJSON(cachedStoryString)) {
            
            usedCache = true
            completion(.success(cachedStory))
            return
        }
        
        // 检查网络是否可用
        if !testNetworkManager.canPerformNetworkRequest() {
            completion(.failure(.offlineMode))
            return
        }
        
        // 设置生成状态
        generationStatus = .generating
        
        // 模拟生成过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 检查是否取消
            if self.generationStatus != .generating {
                completion(.failure(.generationFailed))
                return
            }
            
            // 检查是否应该第一次失败
            if self.shouldFailOnFirstAttempt && self.retryCount == 0 {
                self.retryCount += 1
                
                // 在短暂延迟后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.generateStoryContent(theme: theme, characterName: characterName, length: length) { result in
                        self.generationStatus = .idle
                        completion(result)
                    }
                }
                return
            }
            
            // 生成故事内容
            self.generateStoryContent(theme: theme, characterName: characterName, length: length) { result in
                self.generationStatus = .idle
                completion(result)
            }
        }
    }
    
    // 生成故事内容
    private func generateStoryContent(theme: StoryTheme, characterName: String, length: StoryLength, completion: @escaping (Result<Story, StoryServiceError>) -> Void) {
        // 生成示例故事内容
        let title = "《\(characterName)的\(theme.rawValue)》"
        
        var content = ""
        let targetLength = length.wordCount.lowerBound + (length.wordCount.upperBound - length.wordCount.lowerBound) / 2
        
        // 根据主题生成内容
        switch theme {
        case .space:
            content = "\(characterName)乘坐宇宙飞船，前往太空探险。他遇见了友好的外星人，一起探索了神秘的星球。他们发现了闪闪发光的宇宙晶石，学习了外星科技。回到地球后，\(characterName)把这次奇妙的太空旅行讲给了所有朋友听。"
        case .ocean:
            content = "在蓝色的海洋里，\(characterName)变成了一条勇敢的小鱼。他遇见了海龟爷爷，跟随着海龟爷爷探索了美丽的珊瑚礁。在那里，他们帮助被困在渔网中的海豚，并找到了传说中的海底宫殿。"
        case .forest:
            content = "\(characterName)在神奇的森林里迷路了，遇到了会说话的松鼠。松鼠带着\(characterName)拜访了森林里的各种动物朋友，他们一起找到了回家的路，并学会了保护自然环境的重要性。"
        case .dinosaur:
            content = "一天，\(characterName)发现了一个恐龙蛋。当蛋孵化后，一只可爱的小恐龙出生了！\(characterName)和小恐龙成为了好朋友，一起冒险，帮助小恐龙找到了它的恐龙家族。"
        case .fairy:
            content = "在一个古老的城堡里，\(characterName)遇见了一位仙女。仙女给了\(characterName)一个神奇的魔法棒，帮助他们实现愿望。但\(characterName)学会了魔法的真谛：真正的魔法来自于善良的心和勇敢的行动。"
        }
        
        // 扩展内容以达到目标长度
        while content.count < targetLength {
            content += " \(characterName)的冒险还在继续，每一天都有新的发现和惊喜。"
        }
        
        // 创建故事对象
        let story = Story(
            title: title,
            content: content,
            theme: theme.rawValue,
            childName: characterName,
            createdAt: Date()
        )
        
        // 缓存故事
        let storyDict = story.toDictionary()
        let jsonData = try? JSONSerialization.data(withJSONObject: storyDict)
        if let data = jsonData {
            let cacheKey = generateCacheKey(theme: theme, characterName: characterName, length: length)
            _ = testCacheManager.saveToCache(data: data, forKey: cacheKey, type: .story)
        }
        
        completion(.success(story))
    }
    
    // 解析故事JSON
    private func parseStoryJSON(_ jsonString: String) -> [String: Any] {
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }
    
    // 重写取消生成方法
    override func cancelGeneration() {
        if generationStatus == .generating {
            generationStatus = .idle
            if let completionHandler = longGenerationCompletionHandler {
                completionHandler(.failure(.generationFailed))
                longGenerationCompletionHandler = nil
            }
        }
    }
}

// 用于测试的NetworkManager子类
class TestNetworkManager: NetworkManager {
    private var isConnected = true
    
    func setConnected(_ connected: Bool) {
        isConnected = connected
        status = connected ? .connected : .disconnected
        connectionType = connected ? .wifi : .none
    }
    
    override func canPerformNetworkRequest() -> Bool {
        return isConnected && !isOfflineMode
    }
    
    func enableOfflineMode() {
        isOfflineMode = true
    }
    
    func disableOfflineMode() {
        isOfflineMode = false
    }
} 