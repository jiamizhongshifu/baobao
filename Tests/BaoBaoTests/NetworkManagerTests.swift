import XCTest
import Network
@testable import BaoBao

final class NetworkManagerTests: XCTestCase {
    
    var networkManager: TestNetworkManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        networkManager = TestNetworkManager()
    }
    
    override func tearDownWithError() throws {
        networkManager = nil
        try super.tearDownWithError()
    }
    
    func testInitialState() throws {
        // 验证初始状态
        XCTAssertEqual(networkManager.status, .unknown, "初始网络状态应为未知")
        XCTAssertEqual(networkManager.connectionType, .none, "初始连接类型应为无")
        XCTAssertFalse(networkManager.isOfflineMode, "初始不应该处于离线模式")
    }
    
    func testOfflineModeToggle() throws {
        // 初始不应该是离线模式
        XCTAssertFalse(networkManager.isOfflineMode)
        
        // 启用离线模式
        networkManager.enableOfflineMode()
        XCTAssertTrue(networkManager.isOfflineMode, "启用离线模式失败")
        
        // 禁用离线模式
        networkManager.disableOfflineMode()
        XCTAssertFalse(networkManager.isOfflineMode, "禁用离线模式失败")
        
        // 切换离线模式
        networkManager.toggleOfflineMode()
        XCTAssertTrue(networkManager.isOfflineMode, "切换离线模式后应为开启状态")
        
        networkManager.toggleOfflineMode()
        XCTAssertFalse(networkManager.isOfflineMode, "再次切换离线模式后应为关闭状态")
    }
    
    func testNetworkStatusUpdates() throws {
        // 模拟网络状态变化
        networkManager.simulateNetworkStatusChange(status: .connected, type: .wifi)
        
        // 验证状态更新
        XCTAssertEqual(networkManager.status, .connected)
        XCTAssertEqual(networkManager.connectionType, .wifi)
        
        // 再次更改状态
        networkManager.simulateNetworkStatusChange(status: .disconnected, type: .none)
        
        // 验证状态更新
        XCTAssertEqual(networkManager.status, .disconnected)
        XCTAssertEqual(networkManager.connectionType, .none)
    }
    
    func testCanPerformNetworkRequest() throws {
        // 默认应该可以执行网络请求
        XCTAssertTrue(networkManager.canPerformNetworkRequest())
        
        // 启用离线模式后，不应该可以执行网络请求
        networkManager.enableOfflineMode()
        XCTAssertFalse(networkManager.canPerformNetworkRequest(), "离线模式下不应该允许网络请求")
        
        // 禁用离线模式，模拟断网状态
        networkManager.disableOfflineMode()
        networkManager.simulateNetworkStatusChange(status: .disconnected, type: .none)
        XCTAssertFalse(networkManager.canPerformNetworkRequest(), "断网状态下不应该允许网络请求")
        
        // 恢复网络连接
        networkManager.simulateNetworkStatusChange(status: .connected, type: .wifi)
        XCTAssertTrue(networkManager.canPerformNetworkRequest(), "网络恢复后应该允许网络请求")
    }
    
    func testWiFiOnlyRestriction() throws {
        // 设置仅WiFi下同步
        UserDefaults.standard.set(true, forKey: "syncOnWifiOnly")
        
        // 连接WiFi
        networkManager.simulateNetworkStatusChange(status: .connected, type: .wifi)
        XCTAssertTrue(networkManager.canPerformSyncOperation(), "WiFi下应该允许同步")
        
        // 切换到蜂窝网络
        networkManager.simulateNetworkStatusChange(status: .connected, type: .cellular)
        XCTAssertFalse(networkManager.canPerformSyncOperation(), "设置为仅WiFi同步时，蜂窝网络下不应该允许同步")
        
        // 关闭仅WiFi同步限制
        UserDefaults.standard.set(false, forKey: "syncOnWifiOnly")
        XCTAssertTrue(networkManager.canPerformSyncOperation(), "取消仅WiFi限制后，蜂窝网络下应该允许同步")
    }
    
    func testNetworkStateObservation() throws {
        // 创建一个期望
        let expectation = XCTestExpectation(description: "网络状态观察")
        
        // 设置状态改变观察者
        var receivedStatus: NetworkStatus?
        var statusChanged = false
        
        networkManager.statusPublisher
            .sink { status in
                receivedStatus = status
                statusChanged = true
                expectation.fulfill()
            }
            .store(in: &networkManager.cancellables)
        
        // 触发状态改变
        networkManager.simulateNetworkStatusChange(status: .connected, type: .wifi)
        
        // 等待状态改变回调
        wait(for: [expectation], timeout: 1.0)
        
        // 验证观察者收到了状态更新
        XCTAssertTrue(statusChanged, "状态改变观察者未被触发")
        XCTAssertEqual(receivedStatus, .connected, "观察者接收到的状态不正确")
    }
}

// 用于测试的NetworkManager子类
class TestNetworkManager: NetworkManager {
    
    var cancellables = Set<AnyCancellable>()
    
    // 重写初始化方法，避免真实网络监控
    override init() {
        super.init()
        // 不调用setupNetworkMonitoring，避免真实网络监控
    }
    
    // 模拟网络状态变化
    func simulateNetworkStatusChange(status: NetworkStatus, type: ConnectionType) {
        self.status = status
        self.connectionType = type
    }
    
    // 重写网络监控设置，避免真实网络监控
    override func setupNetworkMonitoring() {
        // 空实现，避免真实网络监控
    }
} 