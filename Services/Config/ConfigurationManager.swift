import Foundation
import os.log

/// 配置管理器，负责加载和管理应用配置
class ConfigurationManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = ConfigurationManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.config", category: "ConfigurationManager")
    
    /// 配置字典
    private var configDict: [String: Any] = [:]
    
    /// DeepSeek API密钥
    var deepseekApiKey: String {
        return string(forKey: "DEEPSEEK_API_KEY") ?? ""
    }
    
    /// Azure语音服务密钥
    var azureSpeechKey: String {
        return string(forKey: "AZURE_SPEECH_KEY") ?? ""
    }
    
    /// Azure语音服务区域
    var azureSpeechRegion: String {
        return string(forKey: "AZURE_SPEECH_REGION") ?? "eastasia"
    }
    
    /// Azure自定义语音ID
    var azureCustomVoiceId: String {
        return string(forKey: "AZURE_CUSTOM_VOICE_ID") ?? ""
    }
    
    /// 应用版本
    var appVersion: String {
        return string(forKey: "APP_VERSION") ?? "1.0.0"
    }
    
    /// 默认语音类型
    var defaultVoiceType: String {
        return string(forKey: "DEFAULT_VOICE_TYPE") ?? "萍萍阿姨"
    }
    
    /// 缓存过期天数
    var cacheExpiryDays: Int {
        return integer(forKey: "CACHE_EXPIRY_DAYS") ?? 7
    }
    
    /// 默认故事长度
    var defaultStoryLength: String {
        return string(forKey: "DEFAULT_STORY_LENGTH") ?? "中篇"
    }
    
    /// 最大故事重试次数
    var maxStoryRetries: Int {
        return integer(forKey: "MAX_STORY_RETRIES") ?? 3
    }
    
    /// 是否启用内容安全检查
    var contentSafetyEnabled: Bool {
        return bool(forKey: "CONTENT_SAFETY_ENABLED") ?? true
    }
    
    /// 是否允许自定义语音训练
    var allowCustomVoiceTraining: Bool {
        return bool(forKey: "ALLOW_CUSTOM_VOICE_TRAINING") ?? false
    }
    
    /// 是否启用CloudKit同步
    var cloudKitSyncEnabled: Bool {
        return bool(forKey: "CLOUDKIT_SYNC_ENABLED") ?? false
    }
    
    /// 是否仅在WiFi下同步
    var syncOnWifiOnly: Bool {
        return bool(forKey: "SYNC_ON_WIFI_ONLY") ?? true
    }
    
    /// 同步频率（小时）
    var syncFrequencyHours: Int {
        return integer(forKey: "SYNC_FREQUENCY_HOURS") ?? 24
    }
    
    /// 是否自动下载新故事
    var autoDownloadNewStories: Bool {
        return bool(forKey: "AUTO_DOWNLOAD_NEW_STORIES") ?? false
    }
    
    /// 是否启用调试日志
    var debugLoggingEnabled: Bool {
        return bool(forKey: "DEBUG_LOGGING_ENABLED") ?? false
    }
    
    /// 是否使用本地备选方案
    var useLocalFallback: Bool {
        return bool(forKey: "USE_LOCAL_FALLBACK") ?? true
    }
    
    /// 是否默认使用本地TTS
    var useLocalTTSByDefault: Bool {
        return bool(forKey: "USE_LOCAL_TTS_BY_DEFAULT") ?? false
    }
    
    /// 故事生成API端点
    var storyGenerationEndpoint: String {
        return string(forKey: "STORY_GENERATION_ENDPOINT") ?? "https://api.deepseek.com/v1/chat/completions"
    }
    
    /// 语音合成API端点
    var speechSynthesisEndpoint: String {
        return string(forKey: "SPEECH_SYNTHESIS_ENDPOINT") ?? "https://eastasia.tts.speech.microsoft.com/cognitiveservices/v1"
    }
    
    /// 默认语音
    var defaultVoice: String {
        return string(forKey: "DEFAULT_VOICE") ?? "zh-CN-XiaoxiaoNeural"
    }
    
    /// 最大缓存大小（MB）
    var maxCacheSizeMB: Int {
        return integer(forKey: "MAX_CACHE_SIZE_MB") ?? 100
    }
    
    /// 最大缓存时间（天）
    var maxCacheAgeDays: Int {
        return integer(forKey: "MAX_CACHE_AGE_DAYS") ?? 7
    }
    
    /// 重试次数
    var retryCount: Int {
        return integer(forKey: "RETRY_COUNT") ?? 3
    }
    
    /// 重试延迟基础秒数
    var retryDelayBaseSeconds: Double {
        return double(forKey: "RETRY_DELAY_BASE_SECONDS") ?? 1.0
    }
    
    // MARK: - 初始化
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - 公共方法
    
    /// 重新加载配置
    func reloadConfiguration() {
        loadConfiguration()
    }
    
    // MARK: - 私有方法
    
    /// 加载配置
    private func loadConfiguration() {
        // 查找配置文件路径
        guard let configPath = findConfigFile() else {
            logger.error("无法找到配置文件")
            return
        }
        
        // 加载配置文件
        do {
            let configData = try Data(contentsOf: configPath)
            let plist = try PropertyListSerialization.propertyList(from: configData, options: [], format: nil)
            
            if let dict = plist as? [String: Any] {
                configDict = dict
                logger.info("成功加载配置文件: \(configPath.path)")
            } else {
                logger.error("配置文件格式无效")
            }
        } catch {
            logger.error("加载配置文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 查找配置文件
    private func findConfigFile() -> URL? {
        // 首先检查应用包中的配置文件
        if let bundlePath = Bundle.main.path(forResource: "Config", ofType: "plist") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // 然后检查文档目录中的配置文件
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsConfigPath = documentsDirectory.appendingPathComponent("Config.plist")
        
        if FileManager.default.fileExists(atPath: documentsConfigPath.path) {
            return documentsConfigPath
        }
        
        // 最后检查应用支持目录中的配置文件
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appSupportConfigPath = appSupportDirectory.appendingPathComponent("Config.plist")
        
        if FileManager.default.fileExists(atPath: appSupportConfigPath.path) {
            return appSupportConfigPath
        }
        
        // 如果在开发环境中，尝试查找项目根目录中的配置文件
        #if DEBUG
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectConfigPath = currentDirectoryURL.appendingPathComponent("Config.plist")
        
        if FileManager.default.fileExists(atPath: projectConfigPath.path) {
            return projectConfigPath
        }
        
        // 尝试查找用户主目录下的配置文件
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let homeConfigPath = homeDirectory.appendingPathComponent("Documents/baobao/Config.plist")
        
        if FileManager.default.fileExists(atPath: homeConfigPath.path) {
            return homeConfigPath
        }
        #endif
        
        return nil
    }
    
    // MARK: - 辅助方法
    
    /// 获取字符串值
    private func string(forKey key: String) -> String? {
        return configDict[key] as? String
    }
    
    /// 获取整数值
    private func integer(forKey key: String) -> Int? {
        return configDict[key] as? Int
    }
    
    /// 获取浮点值
    private func double(forKey key: String) -> Double? {
        return configDict[key] as? Double
    }
    
    /// 获取布尔值
    private func bool(forKey key: String) -> Bool? {
        return configDict[key] as? Bool
    }
} 