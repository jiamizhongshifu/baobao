import Foundation
import Network
import os.log
import Combine

/// 网络状态
enum NetworkStatus {
    case connected
    case disconnected
    case unknown
    
    var isConnected: Bool {
        return self == .connected
    }
}

/// 网络连接类型
enum ConnectionType {
    case wifi
    case cellular
    case wiredEthernet
    case other
    case none
    
    var isWifi: Bool {
        return self == .wifi
    }
    
    var isCellular: Bool {
        return self == .cellular
    }
}

/// 网络连接管理器，负责检测网络状态和管理离线模式
class NetworkManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = NetworkManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.network", category: "NetworkManager")
    
    /// 网络监视器
    private let monitor = NWPathMonitor()
    
    /// 监视器队列
    private let monitorQueue = DispatchQueue(label: "com.baobao.network.monitor")
    
    /// 当前网络状态
    @Published private(set) var networkStatus: NetworkStatus = .unknown
    
    /// 当前连接类型
    @Published private(set) var connectionType: ConnectionType = .none
    
    /// 是否处于离线模式
    @Published private(set) var isOfflineMode: Bool = false
    
    /// 网络状态发布者
    var networkStatusPublisher: AnyPublisher<NetworkStatus, Never> {
        return $networkStatus.eraseToAnyPublisher()
    }
    
    /// 连接类型发布者
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        return $connectionType.eraseToAnyPublisher()
    }
    
    /// 离线模式发布者
    var offlineModePublisher: AnyPublisher<Bool, Never> {
        return $isOfflineMode.eraseToAnyPublisher()
    }
    
    // MARK: - 初始化
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - 公共方法
    
    /// 设置离线模式
    func setOfflineMode(enabled: Bool) {
        isOfflineMode = enabled
        logger.info("离线模式已\(enabled ? "启用" : "禁用")")
    }
    
    /// 是否可以执行网络请求
    func canPerformNetworkRequest() -> Bool {
        return networkStatus == .connected && !isOfflineMode
    }
    
    /// 是否连接到WiFi
    var isWifiConnected: Bool {
        return networkStatus == .connected && connectionType == .wifi
    }
    
    // MARK: - 私有方法
    
    /// 开始监控网络状态
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // 更新网络状态
                if path.status == .satisfied {
                    self.networkStatus = .connected
                } else {
                    self.networkStatus = .disconnected
                }
                
                // 更新连接类型
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wiredEthernet
                } else if self.networkStatus == .connected {
                    self.connectionType = .other
                } else {
                    self.connectionType = .none
                }
                
                self.logger.info("网络状态变化: \(self.networkStatus), 连接类型: \(self.connectionType)")
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    /// 停止监控网络状态
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
} 