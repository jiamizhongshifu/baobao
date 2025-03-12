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
    @Published private(set) var status: NetworkStatus = .unknown
    
    /// 当前连接类型
    @Published private(set) var connectionType: ConnectionType = .none
    
    /// 是否处于离线模式
    @Published private(set) var isOfflineMode: Bool = false
    
    /// 网络状态发布者
    var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        return $status.eraseToAnyPublisher()
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
        setupNetworkMonitoring()
        
        // 从用户默认设置中加载离线模式状态
        isOfflineMode = UserDefaults.standard.bool(forKey: "isOfflineMode")
    }
    
    // MARK: - 公共方法
    
    /// 启用离线模式
    func enableOfflineMode() {
        isOfflineMode = true
        UserDefaults.standard.set(true, forKey: "isOfflineMode")
        logger.info("已启用离线模式")
    }
    
    /// 禁用离线模式
    func disableOfflineMode() {
        isOfflineMode = false
        UserDefaults.standard.set(false, forKey: "isOfflineMode")
        logger.info("已禁用离线模式")
    }
    
    /// 切换离线模式
    func toggleOfflineMode() {
        isOfflineMode.toggle()
        UserDefaults.standard.set(isOfflineMode, forKey: "isOfflineMode")
        logger.info("已切换离线模式: \(isOfflineMode ? "启用" : "禁用")")
    }
    
    /// 检查是否可以执行网络请求
    /// - Returns: 是否可以执行网络请求
    func canPerformNetworkRequest() -> Bool {
        // 如果处于离线模式，不允许执行网络请求
        if isOfflineMode {
            return false
        }
        
        // 如果网络已连接，允许执行网络请求
        return status.isConnected
    }
    
    /// 检查是否可以执行同步
    /// - Returns: 是否可以执行同步
    func canPerformSync() -> Bool {
        // 如果处于离线模式，不允许执行同步
        if isOfflineMode {
            return false
        }
        
        // 如果配置为仅在WiFi下同步，检查当前是否为WiFi连接
        if ConfigurationManager.shared.syncOnWifiOnly {
            return connectionType.isWifi && status.isConnected
        }
        
        // 否则，只要网络已连接，就允许执行同步
        return status.isConnected
    }
    
    // MARK: - 私有方法
    
    /// 设置网络监视
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // 更新网络状态
            if path.status == .satisfied {
                self.status = .connected
            } else {
                self.status = .disconnected
            }
            
            // 更新连接类型
            if path.usesInterfaceType(.wifi) {
                self.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self.connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                self.connectionType = .wiredEthernet
            } else if path.status == .satisfied {
                self.connectionType = .other
            } else {
                self.connectionType = .none
            }
            
            self.logger.info("网络状态更新: \(self.status), 连接类型: \(self.connectionType)")
        }
        
        // 开始监视
        monitor.start(queue: monitorQueue)
    }
} 