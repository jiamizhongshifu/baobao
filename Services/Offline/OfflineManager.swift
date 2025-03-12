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
        networkManager.statusPublisher
            .sink { [weak self] status in
                self?.handleNetworkStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /// 启用离线模式
    func enableOfflineMode() {
        networkManager.enableOfflineMode()
    }
    
    /// 禁用离线模式
    func disableOfflineMode() {
        networkManager.disableOfflineMode()
    }
    
    /// 切换离线模式
    func toggleOfflineMode() {
        networkManager.toggleOfflineMode()
    }
    
    /// 是否处于离线模式
    var isOfflineMode: Bool {
        return networkManager.isOfflineMode
    }
    
    /// 预下载常用故事和语音
    /// - Parameters:
    ///   - characterNames: 角色名称列表
    ///   - progressCallback: 进度回调
    ///   - completion: 完成回调
    func preDownloadCommonContent(characterNames: [String], progressCallback: ((Double) -> Void)? = nil, completion: @escaping (Bool) -> Void) {
        // 检查是否已经在预下载
        if isPreDownloading {
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
        
        // 更新状态
        isPreDownloading = true
        preDownloadProgress = 0
        
        // 在后台队列执行预下载
        preDownloadQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 准备预下载项
            var downloadItems: [(theme: StoryTheme, character: String, length: StoryLength, voice: VoiceType)] = []
            
            // 为每个角色和主题组合生成下载项
            for character in characterNames {
                for theme in StoryTheme.allCases {
                    // 默认使用中篇故事
                    let length = StoryLength.medium
                    
                    // 为每个故事选择合适的语音类型
                    let voice: VoiceType
                    switch theme {
                    case .space, .dinosaur:
                        voice = .xiaoMing
                    case .ocean, .fairy:
                        voice = .xiaoHong
                    case .forest:
                        voice = .pingPing
                    }
                    
                    downloadItems.append((theme, character, length, voice))
                }
            }
            
            // 添加一些额外的语音类型
            if !downloadItems.isEmpty {
                downloadItems.append((downloadItems[0].theme, downloadItems[0].character, downloadItems[0].length, .laoWang))
                downloadItems.append((downloadItems[0].theme, downloadItems[0].character, downloadItems[0].length, .robot))
            }
            
            // 总下载项数
            let totalItems = downloadItems.count
            var completedItems = 0
            
            // 如果没有下载项，直接完成
            if totalItems == 0 {
                DispatchQueue.main.async {
                    self.isPreDownloading = false
                    self.preDownloadProgress = 1.0
                    progressCallback?(1.0)
                    completion(true)
                }
                return
            }
            
            // 创建一个组来跟踪所有下载任务
            let downloadGroup = DispatchGroup()
            
            // 预下载每个项目
            for (index, item) in downloadItems.enumerated() {
                // 检查是否仍然可以执行网络请求
                if !self.networkManager.canPerformNetworkRequest() {
                    self.logger.warning("预下载中断：网络不可用")
                    break
                }
                
                // 进入组
                downloadGroup.enter()
                
                // 预生成故事
                self.storyService.preGenerateStory(theme: item.theme, characterName: item.character, length: item.length)
                
                // 延迟一小段时间，避免API请求过于频繁
                Thread.sleep(forTimeInterval: 0.5)
                
                // 更新进度
                completedItems += 1
                let progress = Double(completedItems) / Double(totalItems * 2)
                DispatchQueue.main.async {
                    self.preDownloadProgress = progress
                    progressCallback?(progress)
                }
                
                // 离开组
                downloadGroup.leave()
                
                // 每隔几个项目暂停一下，避免过度请求
                if index % 3 == 2 {
                    Thread.sleep(forTimeInterval: 2.0)
                }
            }
            
            // 等待所有故事生成完成
            downloadGroup.wait()
            
            // 预下载语音（使用已缓存的故事）
            for item in downloadItems {
                // 检查是否仍然可以执行网络请求
                if !self.networkManager.canPerformNetworkRequest() {
                    self.logger.warning("预下载中断：网络不可用")
                    break
                }
                
                // 生成缓存键
                let storyCacheKey = self.generateStoryCacheKey(theme: item.theme, characterName: item.character, length: item.length)
                
                // 检查故事是否已缓存
                if let storyText = self.cacheManager.textFromCache(forKey: storyCacheKey, type: .story) {
                    // 进入组
                    downloadGroup.enter()
                    
                    // 预合成语音
                    self.speechService.preSynthesizeSpeech(text: storyText, voiceType: item.voice)
                    
                    // 延迟一小段时间，避免API请求过于频繁
                    Thread.sleep(forTimeInterval: 1.0)
                    
                    // 更新进度
                    completedItems += 1
                    let progress = Double(completedItems) / Double(totalItems * 2)
                    DispatchQueue.main.async {
                        self.preDownloadProgress = progress
                        progressCallback?(progress)
                    }
                    
                    // 离开组
                    downloadGroup.leave()
                }
                
                // 每隔几个项目暂停一下，避免过度请求
                if completedItems % 3 == 2 {
                    Thread.sleep(forTimeInterval: 2.0)
                }
            }
            
            // 等待所有语音合成完成
            downloadGroup.wait()
            
            // 完成预下载
            DispatchQueue.main.async {
                self.isPreDownloading = false
                self.preDownloadProgress = 1.0
                progressCallback?(1.0)
                completion(true)
                
                self.logger.info("预下载完成，共下载 \(completedItems) 个项目")
            }
        }
    }
    
    /// 取消预下载
    func cancelPreDownload() {
        if isPreDownloading {
            // 设置标志位，预下载循环会检查这个标志位
            isPreDownloading = false
            logger.info("预下载已取消")
        }
    }
    
    /// 获取离线可用的故事列表
    /// - Returns: 离线可用的故事列表
    func getOfflineAvailableStories() -> [(theme: StoryTheme, character: String, length: StoryLength)] {
        var availableStories: [(theme: StoryTheme, character: String, length: StoryLength)] = []
        
        // 获取所有故事缓存文件
        if let cacheDir = try? FileManager.default.contentsOfDirectory(at: cacheManager.cacheDirectories[.story]!, includingPropertiesForKeys: nil) {
            for fileURL in cacheDir {
                // 从文件名解析缓存键
                let fileName = fileURL.lastPathComponent
                if let cacheKey = fileName.split(separator: ".").first {
                    // 尝试解析缓存键
                    let components = String(cacheKey).split(separator: "_")
                    if components.count >= 3 {
                        // 尝试解析主题
                        if let themeIndex = StoryTheme.allCases.firstIndex(where: { $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "_") == components[0] }) {
                            let theme = StoryTheme.allCases[themeIndex]
                            
                            // 解析角色名（可能包含多个下划线）
                            var characterComponents: [String] = []
                            for i in 1..<components.count-1 {
                                characterComponents.append(String(components[i]))
                            }
                            let character = characterComponents.joined(separator: "_")
                            
                            // 尝试解析长度
                            if let lengthIndex = StoryLength.allCases.firstIndex(where: { $0.rawValue.lowercased() == components.last }) {
                                let length = StoryLength.allCases[lengthIndex]
                                
                                // 添加到可用故事列表
                                availableStories.append((theme, character, length))
                            }
                        }
                    }
                }
            }
        }
        
        return availableStories
    }
    
    /// 获取离线缓存统计信息
    /// - Returns: 缓存统计信息
    func getOfflineCacheStats() -> (storyCount: Int, speechCount: Int, totalSizeMB: Double) {
        let storyCount = getOfflineAvailableStories().count
        
        // 获取语音缓存文件数量
        var speechCount = 0
        if let cacheDir = try? FileManager.default.contentsOfDirectory(at: cacheManager.cacheDirectories[.speech]!, includingPropertiesForKeys: nil) {
            speechCount = cacheDir.count
        }
        
        // 计算总缓存大小
        let storyCacheSize = cacheManager.cacheSize(type: .story)
        let speechCacheSize = cacheManager.cacheSize(type: .speech)
        let totalSizeMB = Double(storyCacheSize + speechCacheSize) / (1024 * 1024)
        
        return (storyCount, speechCount, totalSizeMB)
    }
    
    // MARK: - 私有方法
    
    /// 处理网络状态变化
    private func handleNetworkStatusChange(_ status: NetworkStatus) {
        // 如果网络恢复连接，可以在这里执行一些操作
        if status == .connected && !networkManager.isOfflineMode {
            logger.info("网络已恢复连接")
            
            // 如果配置了自动下载新故事，可以在这里触发下载
            if configManager.autoDownloadNewStories {
                logger.info("准备自动下载新故事")
                // 这里可以实现自动下载逻辑
            }
        }
    }
    
    /// 生成故事缓存键
    private func generateStoryCacheKey(theme: StoryTheme, characterName: String, length: StoryLength) -> String {
        let key = "\(theme.rawValue)_\(characterName)_\(length.rawValue)"
        return key.replacingOccurrences(of: " ", with: "_")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
} 