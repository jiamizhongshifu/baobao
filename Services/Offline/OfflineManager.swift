import Foundation
import os.log
import Combine

/// 离线模式管理器，负责管理应用的离线模式设置和状态
class OfflineManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = OfflineManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.offline", category: "OfflineManager")
    
    /// 配置管理器
    private let configManager = ConfigurationManager.shared
    
    /// 缓存管理器
    private let cacheManager = CacheManager.shared
    
    /// 网络管理器
    private let networkManager = NetworkManager.shared
    
    /// 故事服务
    private let storyService = StoryService.shared
    
    /// 语音服务
    private let speechService = SpeechService.shared
    
    /// 设置仓库
    private let settingsRepository = SettingsRepository.shared
    
    /// 孩子仓库
    private let childRepository = ChildRepository.shared
    
    /// 故事仓库
    private let storyRepository = StoryRepository.shared
    
    /// 预下载队列
    private let preDownloadQueue = DispatchQueue(label: "com.baobao.offline.predownload", qos: .utility)
    
    /// 是否正在预下载
    @Published private(set) var isPreDownloading = false
    
    /// 预下载进度（0-1）
    @Published private(set) var preDownloadProgress: Double = 0
    
    /// 预下载状态发布者
    var preDownloadStatusPublisher: AnyPublisher<(Bool, Double), Never> {
        return Publishers.CombineLatest($isPreDownloading, $preDownloadProgress)
            .eraseToAnyPublisher()
    }
    
    /// 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    private init() {
        // 监听网络状态变化
        networkManager.networkStatusPublisher
            .sink { [weak self] status in
                self?.logger.info("网络状态变化: \(status)")
                self?.handleNetworkStatusChange(status)
            }
            .store(in: &cancellables)
        
        // 监听设置变更
        settingsRepository.settingsChangesPublisher
            .sink { [weak self] settings in
                self?.logger.info("应用设置变更: offlineModeEnabled=\(settings.offlineModeEnabled)")
                self?.handleSettingsChange(settings)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /// 启用离线模式
    func enableOfflineMode() {
        settingsRepository.setOfflineMode(enabled: true)
        networkManager.setOfflineMode(enabled: true)
        logger.info("离线模式已启用")
    }
    
    /// 禁用离线模式
    func disableOfflineMode() {
        settingsRepository.setOfflineMode(enabled: false)
        networkManager.setOfflineMode(enabled: false)
        logger.info("离线模式已禁用")
    }
    
    /// 切换离线模式
    func toggleOfflineMode() {
        let settings = settingsRepository.getAppSettings()
        let newValue = !settings.offlineModeEnabled
        settingsRepository.setOfflineMode(enabled: newValue)
        networkManager.setOfflineMode(enabled: newValue)
        logger.info("离线模式已切换为: \(newValue ? "启用" : "禁用")")
    }
    
    /// 是否处于离线模式
    var isOfflineModeEnabled: Bool {
        return settingsRepository.getAppSettings().offlineModeEnabled
    }
    
    /// 设置仅在WiFi下同步
    func setSyncOnWifiOnly(enabled: Bool) {
        settingsRepository.setSyncOnWifiOnly(enabled: enabled)
        logger.info("仅在WiFi下同步已设置为: \(enabled ? "启用" : "禁用")")
    }
    
    /// 是否仅在WiFi下同步
    var isSyncOnWifiOnly: Bool {
        return settingsRepository.getAppSettings().syncOnWifiOnly
    }
    
    /// 设置自动下载新故事
    func setAutoDownloadNewStories(enabled: Bool) {
        settingsRepository.setAutoDownloadNewStories(enabled: enabled)
        logger.info("自动下载新故事已设置为: \(enabled ? "启用" : "禁用")")
    }
    
    /// 是否自动下载新故事
    var isAutoDownloadNewStories: Bool {
        return settingsRepository.getAppSettings().autoDownloadNewStories
    }
    
    /// 预下载常用内容
    /// - Parameters:
    ///   - characterNames: 角色名称数组
    ///   - progressCallback: 进度回调
    ///   - completion: 完成回调
    func preDownloadCommonContent(characterNames: [String], progressCallback: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        // 检查是否已经在预下载
        guard !isPreDownloading else {
            logger.warning("已有预下载任务正在进行")
            completion(false)
            return
        }
        
        // 检查网络状态
        if !networkManager.canPerformNetworkRequest() {
            logger.warning("无法预下载：当前处于离线模式或网络不可用")
            completion(false)
            return
        }
        
        // 检查是否仅在WiFi下同步
        if settingsRepository.getAppSettings().syncOnWifiOnly && !networkManager.isWifiConnected {
            logger.warning("无法预下载：设置为仅在WiFi下同步，但当前不是WiFi连接")
            completion(false)
            return
        }
        
        // 更新状态
        isPreDownloading = true
        preDownloadProgress = 0
        progressCallback(0)
        
        // 在后台队列中执行预下载
        preDownloadQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 获取所有主题和长度组合
            let themes = StoryTheme.allCases
            let lengths = [StoryLength.short] // 只预下载短篇故事
            let voiceTypes = [VoiceType.pingPing] // 只预下载萍萍阿姨的声音
            
            // 计算总任务数
            let totalTasks = characterNames.count * themes.count * lengths.count * 2 // 每个组合需要生成故事和语音，所以乘以2
            var completedTasks = 0
            
            // 预下载每个组合
            var success = true
            
            for characterName in characterNames {
                for theme in themes {
                    for length in lengths {
                        // 检查是否取消了预下载
                        if !self.isPreDownloading {
                            self.logger.info("预下载已取消")
                            DispatchQueue.main.async {
                                self.isPreDownloading = false
                                self.preDownloadProgress = 0
                                completion(false)
                            }
                            return
                        }
                        
                        // 预下载故事
                        let semaphore = DispatchSemaphore(value: 0)
                        var storyContent: String?
                        
                        self.storyService.generateStory(theme: theme, characterName: characterName, length: length) { result in
                            switch result {
                            case .success(let content):
                                storyContent = content
                                self.logger.info("故事预下载成功: \(characterName), \(theme.rawValue), \(length.rawValue)")
                            case .failure(let error):
                                self.logger.error("故事预下载失败: \(error.localizedDescription)")
                                success = false
                            }
                            
                            completedTasks += 1
                            let progress = Double(completedTasks) / Double(totalTasks)
                            
                            DispatchQueue.main.async {
                                self.preDownloadProgress = progress
                                progressCallback(progress)
                            }
                            
                            semaphore.signal()
                        }
                        
                        semaphore.wait()
                        
                        // 如果故事生成成功，预下载语音
                        if let content = storyContent {
                            for voiceType in voiceTypes {
                                let semaphore = DispatchSemaphore(value: 0)
                                
                                self.speechService.synthesizeSpeech(text: content, voiceType: voiceType) { result in
                                    switch result {
                                    case .success(_):
                                        self.logger.info("语音预下载成功: \(characterName), \(theme.rawValue), \(voiceType.rawValue)")
                                    case .failure(let error):
                                        self.logger.error("语音预下载失败: \(error.localizedDescription)")
                                        success = false
                                    }
                                    
                                    completedTasks += 1
                                    let progress = Double(completedTasks) / Double(totalTasks)
                                    
                                    DispatchQueue.main.async {
                                        self.preDownloadProgress = progress
                                        progressCallback(progress)
                                    }
                                    
                                    semaphore.signal()
                                }
                                
                                semaphore.wait()
                            }
                        }
                    }
                }
            }
            
            // 完成预下载
            DispatchQueue.main.async {
                self.isPreDownloading = false
                self.preDownloadProgress = 1.0
                progressCallback(1.0)
                self.logger.info("预下载完成，结果: \(success ? "成功" : "部分失败")")
                completion(success)
            }
        }
    }
    
    /// 取消预下载
    func cancelPreDownload() {
        guard isPreDownloading else {
            logger.warning("没有正在进行的预下载任务")
            return
        }
        
        isPreDownloading = false
        logger.info("预下载已取消")
    }
    
    /// 获取离线内容统计
    func getOfflineContentStats() -> (storyCount: Int, speechCount: Int, totalSizeMB: Double) {
        // 获取故事数量
        let storyCount = storyRepository.getAllStories().count
        
        // 获取语音缓存数量和大小
        let speechCount = cacheManager.getCacheCount(type: .speech)
        let speechSize = cacheManager.cacheSize(type: .speech)
        
        // 计算总大小（MB）
        let totalSizeMB = Double(speechSize) / (1024 * 1024)
        
        return (storyCount, speechCount, totalSizeMB)
    }
    
    // MARK: - 私有方法
    
    /// 处理网络状态变化
    private func handleNetworkStatusChange(_ status: NetworkStatus) {
        // 如果网络恢复连接，且不是手动设置的离线模式，则自动切换到在线模式
        if status.isConnected && !settingsRepository.getAppSettings().offlineModeEnabled {
            networkManager.setOfflineMode(enabled: false)
            logger.info("网络已恢复，自动切换到在线模式")
        }
    }
    
    /// 处理设置变更
    private func handleSettingsChange(_ settings: AppSettingsModel) {
        // 同步离线模式设置到网络管理器
        networkManager.setOfflineMode(enabled: settings.offlineModeEnabled)
    }
} 