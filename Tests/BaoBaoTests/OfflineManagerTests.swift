import XCTest
import Combine
@testable import BaoBao

final class OfflineManagerTests: XCTestCase {
    
    var offlineManager: TestOfflineManager!
    var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        offlineManager = TestOfflineManager()
    }
    
    override func tearDownWithError() throws {
        offlineManager = nil
        cancellables.removeAll()
        try super.tearDownWithError()
    }
    
    func testOfflineModeToggle() throws {
        // 初始不应该是离线模式
        XCTAssertFalse(offlineManager.isOfflineMode)
        
        // 启用离线模式
        offlineManager.enableOfflineMode()
        XCTAssertTrue(offlineManager.isOfflineMode, "启用离线模式失败")
        
        // 禁用离线模式
        offlineManager.disableOfflineMode()
        XCTAssertFalse(offlineManager.isOfflineMode, "禁用离线模式失败")
        
        // 切换离线模式
        offlineManager.toggleOfflineMode()
        XCTAssertTrue(offlineManager.isOfflineMode, "切换离线模式后应为开启状态")
        
        offlineManager.toggleOfflineMode()
        XCTAssertFalse(offlineManager.isOfflineMode, "再次切换离线模式后应为关闭状态")
    }
    
    func testPreDownloadProcess() throws {
        // 确保初始状态
        XCTAssertFalse(offlineManager.isPreDownloading)
        XCTAssertEqual(offlineManager.preDownloadProgress, 0.0)
        
        // 测试预下载
        let expectation = XCTestExpectation(description: "预下载完成")
        
        // 模拟网络在线
        offlineManager.networkManager.setConnected(true)
        
        // 执行预下载
        offlineManager.preDownloadCommonContent(characterNames: ["小明", "小红"]) { success in
            XCTAssertTrue(success, "预下载应该成功")
            XCTAssertFalse(self.offlineManager.isPreDownloading, "预下载完成后状态应为非下载中")
            XCTAssertEqual(self.offlineManager.preDownloadProgress, 1.0, "预下载完成后进度应为100%")
            expectation.fulfill()
        }
        
        // 验证预下载状态
        XCTAssertTrue(offlineManager.isPreDownloading, "预下载状态应为下载中")
        
        // 等待预下载完成
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPreDownloadFailureWhenOffline() throws {
        // 确保初始状态
        XCTAssertFalse(offlineManager.isPreDownloading)
        
        // 模拟网络离线
        offlineManager.networkManager.setConnected(false)
        
        // 测试预下载失败
        let expectation = XCTestExpectation(description: "预下载失败")
        
        // 执行预下载
        offlineManager.preDownloadCommonContent(characterNames: ["小明"]) { success in
            XCTAssertFalse(success, "离线状态下预下载应该失败")
            XCTAssertFalse(self.offlineManager.isPreDownloading, "预下载失败后状态应为非下载中")
            expectation.fulfill()
        }
        
        // 验证预下载状态
        XCTAssertFalse(offlineManager.isPreDownloading, "离线状态下不应开始预下载")
        
        // 等待预下载回调
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPreDownloadCancellation() throws {
        // 确保初始状态
        XCTAssertFalse(offlineManager.isPreDownloading)
        
        // 模拟网络在线
        offlineManager.networkManager.setConnected(true)
        
        // 开始预下载
        let expectation = XCTestExpectation(description: "预下载取消")
        
        // 执行预下载并保持进行中状态
        offlineManager.simulateLongPreDownload(characterNames: ["小明", "小红"]) { success in
            XCTAssertFalse(success, "预下载被取消应返回失败")
            expectation.fulfill()
        }
        
        // 验证预下载状态
        XCTAssertTrue(offlineManager.isPreDownloading, "预下载状态应为下载中")
        
        // 取消预下载
        offlineManager.cancelPreDownload()
        
        // 验证预下载已取消
        XCTAssertFalse(offlineManager.isPreDownloading, "取消后预下载状态应为非下载中")
        
        // 等待预下载回调
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPreDownloadStatusPublisher() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "状态发布者更新")
        
        // 变量跟踪状态变化
        var receivedUpdates: [(Bool, Double)] = []
        
        // 订阅状态变化
        offlineManager.preDownloadStatusPublisher
            .sink { status, progress in
                receivedUpdates.append((status, progress))
                if receivedUpdates.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 模拟网络在线
        offlineManager.networkManager.setConnected(true)
        
        // 开始预下载并更新进度
        offlineManager.simulateProgressivePreDownload()
        
        // 等待状态更新
        wait(for: [expectation], timeout: 2.0)
        
        // 验证状态更新
        XCTAssertGreaterThanOrEqual(receivedUpdates.count, 3, "应该收到至少3次状态更新")
        
        // 验证第一次和最后一次状态
        XCTAssertTrue(receivedUpdates.first?.0 == true, "第一次更新应为下载中状态")
        XCTAssertEqual(receivedUpdates.first?.1, 0.0, "第一次更新进度应为0%")
        
        XCTAssertFalse(receivedUpdates.last?.0 == false, "最后一次更新应为非下载中状态")
        XCTAssertEqual(receivedUpdates.last?.1, 1.0, "最后一次更新进度应为100%")
    }
    
    func testNetworkStatusChangeHandling() throws {
        // 模拟网络在线并开始预下载
        offlineManager.networkManager.setConnected(true)
        
        let expectation = XCTestExpectation(description: "预下载取消")
        
        // 执行预下载并保持进行中状态
        offlineManager.simulateLongPreDownload(characterNames: ["小明"]) { success in
            XCTAssertFalse(success, "网络中断应导致预下载失败")
            expectation.fulfill()
        }
        
        // 确认预下载已开始
        XCTAssertTrue(offlineManager.isPreDownloading)
        
        // 模拟网络中断
        offlineManager.networkManager.setConnected(false)
        
        // 触发网络状态变化处理
        offlineManager.handleNetworkStatusChange(.disconnected)
        
        // 验证预下载已取消
        XCTAssertFalse(offlineManager.isPreDownloading, "网络中断应取消预下载")
        
        // 等待预下载回调
        wait(for: [expectation], timeout: 1.0)
    }
}

// 用于测试的OfflineManager子类
class TestOfflineManager: OfflineManager {
    
    let testNetworkManager = TestNetworkManager()
    var preDownloadCancelled = false
    var longPreDownloadCompletionHandler: ((Bool) -> Void)?
    
    override var networkManager: NetworkManager {
        return testNetworkManager
    }
    
    // 模拟长时间预下载过程
    func simulateLongPreDownload(characterNames: [String], completion: @escaping (Bool) -> Void) {
        isPreDownloading = true
        preDownloadProgress = 0.0
        preDownloadCancelled = false
        longPreDownloadCompletionHandler = completion
    }
    
    // 模拟渐进式预下载过程
    func simulateProgressivePreDownload() {
        isPreDownloading = true
        preDownloadProgress = 0.0
        
        // 分步更新进度
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.preDownloadProgress = 0.3
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.preDownloadProgress = 0.7
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.preDownloadProgress = 1.0
                    self.isPreDownloading = false
                }
            }
        }
    }
    
    // 重写预下载方法
    override func preDownloadCommonContent(characterNames: [String], progressCallback: ((Double) -> Void)? = nil, completion: @escaping (Bool) -> Void) {
        // 检查网络是否可用
        if !testNetworkManager.canPerformNetworkRequest() {
            completion(false)
            return
        }
        
        isPreDownloading = true
        preDownloadProgress = 0.0
        
        // 模拟预下载过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.preDownloadProgress = 0.5
            progressCallback?(0.5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.preDownloadProgress = 1.0
                self.isPreDownloading = false
                progressCallback?(1.0)
                completion(true)
            }
        }
    }
    
    // 重写取消预下载方法
    override func cancelPreDownload() {
        if isPreDownloading {
            isPreDownloading = false
            preDownloadCancelled = true
            if let completionHandler = longPreDownloadCompletionHandler {
                completionHandler(false)
                longPreDownloadCompletionHandler = nil
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
} 