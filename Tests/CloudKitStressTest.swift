import XCTest
import CloudKit
@testable import BaoBao

class CloudKitStressTest: XCTestCase {
    
    private var cloudKitService: CloudKitSyncService!
    private var dataService: DataService!
    private var configManager: ConfigurationManager!
    
    // 测试设置
    private let stressTestItemCount = 30 // 调整测试中的数据项数量
    private let storyContentLength = 5000 // 长故事内容的字符数
    private let concurrentOperations = 5 // 同时执行的操作数量
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        configManager = ConfigurationManager.shared
        cloudKitService = CloudKitSyncService.shared
        dataService = DataService.shared
        
        // 确保CloudKit同步开启
        configManager.setCloudKitSyncEnabled(true)
        
        // 等待CloudKit状态更新
        waitForCloudKitStatus()
    }
    
    override func tearDownWithError() throws {
        // 清理测试数据
        cleanupTestData()
        try super.tearDownWithError()
    }
    
    // MARK: - 辅助方法
    
    /// 等待CloudKit状态更新
    private func waitForCloudKitStatus() {
        let expectation = XCTestExpectation(description: "等待CloudKit状态更新")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 6)
    }
    
    /// 生成指定长度的随机文本
    private func generateRandomText(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789，。！？；：''""（）【】「」『』、—……《》"
        var text = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<chars.count)
            let char = chars[chars.index(chars.startIndex, offsetBy: randomIndex)]
            text.append(char)
            
            // 每隔70-100个字符添加一个换行，模拟段落
            if text.count % Int.random(in: 70...100) == 0 {
                text.append("\n\n")
            }
        }
        return text
    }
    
    /// 生成测试故事
    private func generateTestStory(index: Int, longContent: Bool = false) -> Story {
        let content = longContent ? generateRandomText(length: storyContentLength) : "这是测试故事内容\(index)"
        return Story(
            title: "压力测试故事\(index)",
            content: content,
            theme: "压力测试",
            childName: "测试宝宝\(index % 5)"
        )
    }
    
    /// 生成测试宝宝信息
    private func generateTestChild(index: Int) -> Child {
        let interests = [
            ["恐龙", "汽车", "绘画"],
            ["宇宙", "动物", "音乐"],
            ["故事", "运动", "科学"],
            ["海洋", "机器人", "植物"],
            ["童话", "数学", "建筑"]
        ][index % 5]
        
        return Child(
            name: "压力测试宝宝\(index)",
            age: 3 + (index % 5),
            gender: index % 2 == 0 ? "男" : "女",
            interests: interests
        )
    }
    
    /// 清理测试数据
    private func cleanupTestData() {
        // 从本地删除测试故事
        let storyExpectation = XCTestExpectation(description: "删除测试故事")
        dataService.getStories { result in
            if case .success(let stories) = result {
                for story in stories where story.title.starts(with: "压力测试") {
                    self.dataService.deleteStory(story.id) { _ in }
                }
            }
            storyExpectation.fulfill()
        }
        
        // 从本地删除测试宝宝信息
        let childExpectation = XCTestExpectation(description: "删除测试宝宝信息")
        dataService.getChildren { result in
            if case .success(let children) = result {
                for child in children where child.name.starts(with: "压力测试") {
                    self.dataService.deleteChild(child.id) { _ in }
                }
            }
            childExpectation.fulfill()
        }
        
        wait(for: [storyExpectation, childExpectation], timeout: 10)
    }
    
    // MARK: - 压力测试
    
    /// 测试大量小数据同步
    func testBulkSmallDataSync() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        let startTime = Date()
        let expectation = XCTestExpectation(description: "同步大量小数据")
        
        // 创建多个故事
        let dispatchGroup = DispatchGroup()
        var savedStories = 0
        var errorCount = 0
        
        for i in 0..<stressTestItemCount {
            dispatchGroup.enter()
            
            let story = generateTestStory(index: i)
            
            dataService.saveStory(story) { result in
                switch result {
                case .success:
                    savedStories += 1
                case .failure:
                    errorCount += 1
                }
                dispatchGroup.leave()
            }
            
            // 每批次暂停一下，避免请求过于密集
            if i % 5 == 4 {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        
        // 等待所有操作完成
        dispatchGroup.notify(queue: .main) {
            let syncTime = Date().timeIntervalSince(startTime)
            print("保存\(savedStories)个故事，失败\(errorCount)个，耗时\(String(format: "%.2f", syncTime))秒")
            
            // 等待CloudKit同步
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                // 检查是否成功同步到CloudKit
                self.cloudKitService.fetchAllStories { result in
                    switch result {
                    case .success(let stories):
                        let syncedStories = stories.filter { $0.title.starts(with: "压力测试") }
                        print("CloudKit中找到\(syncedStories.count)个测试故事")
                        
                        XCTAssertTrue(syncedStories.count > 0, "CloudKit中应该至少有一些测试故事")
                        
                        // 成功率分析
                        let successRate = Double(syncedStories.count) / Double(savedStories) * 100
                        print("同步成功率: \(String(format: "%.1f", successRate))%")
                        
                    case .failure(let error):
                        XCTFail("获取CloudKit故事失败: \(error.localizedDescription)")
                    }
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 60)
    }
    
    /// 测试大数据同步
    func testLargeDataSync() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        let expectation = XCTestExpectation(description: "同步大数据")
        let startTime = Date()
        
        // 创建大内容的故事
        let largeStory = generateTestStory(index: 0, longContent: true)
        
        dataService.saveStory(largeStory) { result in
            switch result {
            case .success(let savedStory):
                print("已保存大内容故事，内容长度：\(savedStory.content.count)字符")
                
                // 等待CloudKit同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                    // 检查是否成功同步到CloudKit
                    self.cloudKitService.fetchAllStories { result in
                        switch result {
                        case .success(let stories):
                            let syncedStory = stories.first { $0.title == "压力测试故事0" }
                            
                            if let syncedStory = syncedStory {
                                print("CloudKit中找到大内容故事，内容长度：\(syncedStory.content.count)字符")
                                let syncTime = Date().timeIntervalSince(startTime)
                                print("大内容同步总耗时：\(String(format: "%.2f", syncTime))秒")
                                
                                // 检查内容完整性
                                XCTAssertEqual(syncedStory.content.count, largeStory.content.count, "内容长度应该完全匹配")
                                
                            } else {
                                XCTFail("CloudKit中未找到同步的大内容故事")
                            }
                            
                        case .failure(let error):
                            XCTFail("获取CloudKit故事失败: \(error.localizedDescription)")
                        }
                        expectation.fulfill()
                    }
                }
                
            case .failure(let error):
                XCTFail("保存大内容故事失败: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60)
    }
    
    /// 测试并发操作
    func testConcurrentOperations() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        let expectation = XCTestExpectation(description: "并发同步操作")
        let startTime = Date()
        
        // 并发执行多种操作
        let dispatchGroup = DispatchGroup()
        let operationQueue = DispatchQueue(label: "com.example.baobao.concurrentoperations", attributes: .concurrent)
        
        var successCount = 0
        var failureCount = 0
        let lock = NSLock()
        
        for i in 0..<concurrentOperations {
            dispatchGroup.enter()
            
            // 随机选择操作类型：保存故事/保存宝宝/删除故事
            let operationType = Int.random(in: 0...2)
            
            operationQueue.async {
                switch operationType {
                case 0: // 保存故事
                    let story = self.generateTestStory(index: i)
                    self.dataService.saveStory(story) { result in
                        lock.lock()
                        switch result {
                        case .success:
                            print("并发操作\(i): 成功保存故事")
                            successCount += 1
                        case .failure(let error):
                            print("并发操作\(i): 保存故事失败 - \(error.localizedDescription)")
                            failureCount += 1
                        }
                        lock.unlock()
                        dispatchGroup.leave()
                    }
                    
                case 1: // 保存宝宝信息
                    let child = self.generateTestChild(index: i)
                    self.dataService.saveChild(child) { result in
                        lock.lock()
                        switch result {
                        case .success:
                            print("并发操作\(i): 成功保存宝宝信息")
                            successCount += 1
                        case .failure(let error):
                            print("并发操作\(i): 保存宝宝信息失败 - \(error.localizedDescription)")
                            failureCount += 1
                        }
                        lock.unlock()
                        dispatchGroup.leave()
                    }
                    
                case 2: // 先保存后删除故事
                    let story = self.generateTestStory(index: i + 100) // 用不同的索引避免冲突
                    self.dataService.saveStory(story) { result in
                        switch result {
                        case .success(let savedStory):
                            // 等待短暂时间后删除
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                self.dataService.deleteStory(savedStory.id) { deleteResult in
                                    lock.lock()
                                    switch deleteResult {
                                    case .success:
                                        print("并发操作\(i): 成功保存并删除故事")
                                        successCount += 1
                                    case .failure(let error):
                                        print("并发操作\(i): 删除故事失败 - \(error.localizedDescription)")
                                        failureCount += 1
                                    }
                                    lock.unlock()
                                    dispatchGroup.leave()
                                }
                            }
                        case .failure(let error):
                            lock.lock()
                            print("并发操作\(i): 保存故事失败 - \(error.localizedDescription)")
                            failureCount += 1
                            lock.unlock()
                            dispatchGroup.leave()
                        }
                    }
                    
                default:
                    lock.lock()
                    failureCount += 1
                    lock.unlock()
                    dispatchGroup.leave()
                }
            }
        }
        
        // 等待所有操作完成
        dispatchGroup.notify(queue: .main) {
            let operationTime = Date().timeIntervalSince(startTime)
            print("并发操作完成，成功\(successCount)个，失败\(failureCount)个，耗时\(String(format: "%.2f", operationTime))秒")
            
            // 等待CloudKit同步一会
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60)
    }
    
    /// 测试混合工作负载
    func testMixedWorkload() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        let expectation = XCTestExpectation(description: "混合工作负载测试")
        let startTime = Date()
        
        // 步骤1：创建10个普通故事
        let step1Expectation = XCTestExpectation(description: "步骤1：创建普通故事")
        var step1Stories: [Story] = []
        
        let dispatchGroup1 = DispatchGroup()
        
        for i in 0..<10 {
            dispatchGroup1.enter()
            let story = generateTestStory(index: i)
            
            dataService.saveStory(story) { result in
                switch result {
                case .success(let savedStory):
                    step1Stories.append(savedStory)
                case .failure:
                    break
                }
                dispatchGroup1.leave()
            }
        }
        
        dispatchGroup1.notify(queue: .main) {
            print("步骤1完成：创建了\(step1Stories.count)个普通故事")
            step1Expectation.fulfill()
            
            // 步骤2：创建5个宝宝信息
            let step2Expectation = XCTestExpectation(description: "步骤2：创建宝宝信息")
            var step2Children: [Child] = []
            
            let dispatchGroup2 = DispatchGroup()
            
            for i in 0..<5 {
                dispatchGroup2.enter()
                let child = self.generateTestChild(index: i)
                
                self.dataService.saveChild(child) { result in
                    switch result {
                    case .success(let savedChild):
                        step2Children.append(savedChild)
                    case .failure:
                        break
                    }
                    dispatchGroup2.leave()
                }
            }
            
            dispatchGroup2.notify(queue: .main) {
                print("步骤2完成：创建了\(step2Children.count)个宝宝信息")
                step2Expectation.fulfill()
                
                // 步骤3：修改一些故事
                let step3Expectation = XCTestExpectation(description: "步骤3：修改故事")
                
                if step1Stories.count >= 3 {
                    // 修改前3个故事
                    for i in 0..<3 {
                        let storyToUpdate = step1Stories[i]
                        let updatedStory = Story(
                            id: storyToUpdate.id,
                            title: "已更新-\(storyToUpdate.title)",
                            content: storyToUpdate.content + "\n\n这是更新的内容",
                            theme: storyToUpdate.theme,
                            childName: storyToUpdate.childName,
                            createdAt: storyToUpdate.createdAt
                        )
                        
                        self.dataService.saveStory(updatedStory) { _ in }
                    }
                }
                
                // 等待3秒让修改完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    print("步骤3完成：修改了部分故事")
                    step3Expectation.fulfill()
                    
                    // 步骤4：删除一些故事
                    let step4Expectation = XCTestExpectation(description: "步骤4：删除故事")
                    
                    if step1Stories.count >= 5 {
                        // 删除第4和第5个故事
                        for i in 3..<5 {
                            self.dataService.deleteStory(step1Stories[i].id) { _ in }
                        }
                    }
                    
                    // 等待3秒让删除完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        print("步骤4完成：删除了部分故事")
                        step4Expectation.fulfill()
                        
                        // 步骤5：创建一个大内容故事
                        let step5Expectation = XCTestExpectation(description: "步骤5：创建大内容故事")
                        
                        let largeStory = self.generateTestStory(index: 999, longContent: true)
                        
                        self.dataService.saveStory(largeStory) { _ in
                            print("步骤5完成：创建了大内容故事")
                            step5Expectation.fulfill()
                            
                            // 等待同步完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                                let testTime = Date().timeIntervalSince(startTime)
                                print("混合工作负载测试完成，总耗时：\(String(format: "%.2f", testTime))秒")
                                
                                // 验证同步结果
                                self.cloudKitService.fetchAllStories { result in
                                    switch result {
                                    case .success(let stories):
                                        let testStories = stories.filter { $0.title.starts(with: "压力测试") || $0.title.starts(with: "已更新-压力测试") }
                                        print("CloudKit中找到\(testStories.count)个测试故事")
                                        
                                        // 找到大内容故事
                                        let largeStoryInCloud = stories.first { $0.title == "压力测试故事999" }
                                        if largeStoryInCloud != nil {
                                            print("大内容故事同步成功")
                                        }
                                        
                                    case .failure(let error):
                                        print("获取CloudKit故事失败: \(error.localizedDescription)")
                                    }
                                    
                                    expectation.fulfill()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation, step1Expectation, step2Expectation], timeout: 90)
    }
} 