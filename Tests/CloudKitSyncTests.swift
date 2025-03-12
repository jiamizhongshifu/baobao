import XCTest
import CloudKit
@testable import BaoBao

class CloudKitSyncTests: XCTestCase {
    
    private var cloudKitService: CloudKitSyncService!
    private var dataService: DataService!
    private var configManager: ConfigurationManager!
    
    // 测试数据
    private let testStory = Story(
        title: "测试故事",
        content: "这是一个测试故事内容",
        theme: "测试主题",
        childName: "测试宝宝"
    )
    
    private let testChild = Child(
        name: "测试宝宝",
        age: 5,
        gender: "男",
        interests: ["恐龙", "宇宙"]
    )
    
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
        
        // 设置超时等待，以确保CloudKit状态被正确检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 6)
    }
    
    /// 清理测试数据
    private func cleanupTestData() {
        // 从本地删除测试故事
        let storyExpectation = XCTestExpectation(description: "删除测试故事")
        dataService.getStories { result in
            if case .success(let stories) = result {
                for story in stories where story.title == "测试故事" {
                    self.dataService.deleteStory(story.id) { _ in }
                }
            }
            storyExpectation.fulfill()
        }
        
        // 从本地删除测试宝宝信息
        let childExpectation = XCTestExpectation(description: "删除测试宝宝信息")
        dataService.getChildren { result in
            if case .success(let children) = result {
                for child in children where child.name == "测试宝宝" {
                    self.dataService.deleteChild(child.id) { _ in }
                }
            }
            childExpectation.fulfill()
        }
        
        wait(for: [storyExpectation, childExpectation], timeout: 5)
    }
    
    // MARK: - 测试案例
    
    /// 测试CloudKit状态检查
    func testCloudKitStatus() throws {
        XCTAssertTrue(configManager.cloudKitSyncEnabled, "CloudKit同步应该已启用")
        
        // 检查CloudKit状态
        cloudKitService.checkCloudKitStatus()
        
        // 等待状态更新
        let expectation = XCTestExpectation(description: "等待CloudKit状态更新")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4)
        
        // 验证状态 - 需要根据测试环境决定预期状态
        // 测试设备环境可能导致不同结果，所以我们记录状态而不是做断言
        XCTContext.runActivity(named: "当前CloudKit状态") { _ in
            switch cloudKitService.syncStatus {
            case .available:
                print("CloudKit状态: 可用")
            case .unavailable:
                print("CloudKit状态: 不可用")
            case .restricted:
                print("CloudKit状态: 受限")
            case .noAccount:
                print("CloudKit状态: 无账户")
            case .error(let error):
                print("CloudKit状态: 错误 - \(error.localizedDescription)")
            }
        }
    }
    
    /// 测试故事同步
    func testStorySynchronization() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        // 创建测试故事
        let storyExpectation = XCTestExpectation(description: "同步故事")
        
        dataService.saveStory(testStory) { result in
            switch result {
            case .success(let savedStory):
                XCTAssertEqual(savedStory.title, self.testStory.title)
                
                // 等待CloudKit同步完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    // 从CloudKit获取故事
                    self.cloudKitService.fetchAllStories { result in
                        switch result {
                        case .success(let stories):
                            // 检查是否包含我们保存的故事
                            let found = stories.contains { $0.title == self.testStory.title }
                            XCTAssertTrue(found, "CloudKit中应有保存的故事")
                        case .failure(let error):
                            XCTFail("获取CloudKit故事失败: \(error.localizedDescription)")
                        }
                        storyExpectation.fulfill()
                    }
                }
            case .failure(let error):
                XCTFail("保存故事失败: \(error.localizedDescription)")
                storyExpectation.fulfill()
            }
        }
        
        wait(for: [storyExpectation], timeout: 10)
    }
    
    /// 测试宝宝信息同步
    func testChildSynchronization() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        // 创建测试宝宝信息
        let childExpectation = XCTestExpectation(description: "同步宝宝信息")
        
        dataService.saveChild(testChild) { result in
            switch result {
            case .success(let savedChild):
                XCTAssertEqual(savedChild.name, self.testChild.name)
                
                // 等待CloudKit同步完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    // 从CloudKit获取宝宝信息
                    self.cloudKitService.fetchAllChildren { result in
                        switch result {
                        case .success(let children):
                            // 检查是否包含我们保存的宝宝信息
                            let found = children.contains { $0.name == self.testChild.name }
                            XCTAssertTrue(found, "CloudKit中应有保存的宝宝信息")
                        case .failure(let error):
                            XCTFail("获取CloudKit宝宝信息失败: \(error.localizedDescription)")
                        }
                        childExpectation.fulfill()
                    }
                }
            case .failure(let error):
                XCTFail("保存宝宝信息失败: \(error.localizedDescription)")
                childExpectation.fulfill()
            }
        }
        
        wait(for: [childExpectation], timeout: 10)
    }
    
    /// 测试全量同步
    func testFullSynchronization() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        // 执行全量同步
        let expectation = XCTestExpectation(description: "执行全量同步")
        
        cloudKitService.performFullSync { result in
            switch result {
            case .success:
                XCTAssert(true, "全量同步成功")
            case .failure(let error):
                XCTFail("全量同步失败: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15)
    }
    
    /// 测试禁用CloudKit同步
    func testDisableCloudKitSync() throws {
        // 禁用CloudKit同步
        configManager.setCloudKitSyncEnabled(false)
        
        // 等待状态更新
        let expectation = XCTestExpectation(description: "等待CloudKit状态更新")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
        
        // 尝试保存一个故事
        let storyExpectation = XCTestExpectation(description: "同步故事到CloudKit")
        
        // 直接调用CloudKit同步
        cloudKitService.syncStory(testStory, operation: .add) { result in
            switch result {
            case .success:
                XCTFail("CloudKit已禁用，不应该成功同步")
            case .failure:
                // 预期会失败
                XCTAssert(true, "CloudKit已禁用，同步应该失败")
            }
            storyExpectation.fulfill()
        }
        
        wait(for: [storyExpectation], timeout: 5)
        
        // 恢复CloudKit同步
        configManager.setCloudKitSyncEnabled(true)
    }
    
    /// 测试CloudKit诊断工具
    func testCloudKitDiagnosticTool() throws {
        let expectation = XCTestExpectation(description: "执行CloudKit诊断")
        
        CloudKitDiagnosticTool.shared.runDiagnostics { report in
            // 验证报告内容
            XCTAssertTrue(report.contains("CloudKit诊断报告"), "诊断报告应该包含标题")
            XCTAssertTrue(report.contains("iCloud账户状态"), "诊断报告应该包含账户状态")
            XCTAssertTrue(report.contains("CloudKit权限"), "诊断报告应该包含权限信息")
            
            // 记录诊断结果
            XCTContext.runActivity(named: "CloudKit诊断报告") { _ in
                print("诊断报告长度: \(report.count) 字符")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15)
    }
    
    /// 测试故事删除同步
    func testStoryDeletionSync() throws {
        // 只有当CloudKit可用时进行测试
        guard case .available = cloudKitService.syncStatus else {
            XCTContext.runActivity(named: "CloudKit状态") { _ in
                print("跳过测试，CloudKit状态不可用")
            }
            return
        }
        
        // 先保存测试故事
        let saveExpectation = XCTestExpectation(description: "保存故事")
        var savedStoryID: String = ""
        
        dataService.saveStory(testStory) { result in
            switch result {
            case .success(let savedStory):
                savedStoryID = savedStory.id
                saveExpectation.fulfill()
            case .failure(let error):
                XCTFail("保存故事失败: \(error.localizedDescription)")
                saveExpectation.fulfill()
            }
        }
        
        wait(for: [saveExpectation], timeout: 5)
        
        // 等待CloudKit同步
        let syncWaitExpectation = XCTestExpectation(description: "等待CloudKit同步")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            syncWaitExpectation.fulfill()
        }
        wait(for: [syncWaitExpectation], timeout: 4)
        
        // 删除故事并测试同步
        let deleteExpectation = XCTestExpectation(description: "删除故事")
        
        dataService.deleteStory(savedStoryID) { result in
            switch result {
            case .success:
                // 等待CloudKit同步完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    // 从CloudKit获取故事
                    self.cloudKitService.fetchAllStories { result in
                        switch result {
                        case .success(let stories):
                            // 检查是否不再包含我们删除的故事
                            let found = stories.contains { $0.id == savedStoryID }
                            XCTAssertFalse(found, "CloudKit中不应再有已删除的故事")
                        case .failure(let error):
                            XCTFail("获取CloudKit故事失败: \(error.localizedDescription)")
                        }
                        deleteExpectation.fulfill()
                    }
                }
            case .failure(let error):
                XCTFail("删除故事失败: \(error.localizedDescription)")
                deleteExpectation.fulfill()
            }
        }
        
        wait(for: [deleteExpectation], timeout: 10)
    }
} 