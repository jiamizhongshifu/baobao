import Foundation
import os.log

/// 配置管理器，负责加载、管理和提供应用配置
class ConfigurationManager {
    /// 共享实例
    static let shared = ConfigurationManager()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "ConfigurationManager")
    
    /// 配置文件URL
    private let configURL: URL
    
    /// 配置数据
    private var config: [String: Any]
    
    /// 初始化
    private init() {
        // 获取文档目录
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        configURL = documentsDirectory.appendingPathComponent("Config.plist")
        
        // 尝试加载配置文件
        if FileManager.default.fileExists(atPath: configURL.path) {
            if let plistData = try? Data(contentsOf: configURL),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                config = plist
                logger.info("🔧 从文件加载配置成功")
            } else {
                logger.error("❌ 加载配置文件失败，使用默认配置")
                config = getDefaultConfig()
                saveConfig()
            }
        } else {
            // 如果配置文件不存在，创建默认配置
            logger.info("🔧 配置文件不存在，创建默认配置")
            config = getDefaultConfig()
            saveConfig()
        }
    }
    
    /// 获取配置中的字符串值
    /// - Parameter key: 配置键
    /// - Returns: 字符串值，如果找不到或类型不匹配则返回空字符串
    func string(forKey key: String) -> String {
        return config[key] as? String ?? ""
    }
    
    /// 获取配置中的数值
    /// - Parameter key: 配置键
    /// - Returns: 数值，如果找不到或类型不匹配则返回0
    func integer(forKey key: String) -> Int {
        return config[key] as? Int ?? 0
    }
    
    /// 获取配置中的布尔值
    /// - Parameter key: 配置键
    /// - Returns: 布尔值，如果找不到或类型不匹配则返回false
    func boolean(forKey key: String) -> Bool {
        return config[key] as? Bool ?? false
    }
    
    /// 更新配置值
    /// - Parameters:
    ///   - value: 新值
    ///   - key: 配置键
    /// - Returns: 是否更新成功
    @discardableResult
    func update(value: Any, forKey key: String) -> Bool {
        config[key] = value
        
        // 尝试将更新写入配置文件
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSMutableDictionary(contentsOfFile: path) else {
            logger.error("❌ 无法更新配置文件")
            return false
        }
        
        config[key] = value
        
        if config.write(toFile: path, atomically: true) {
            logger.info("✅ 配置已更新: \(key)")
            return true
        } else {
            logger.error("❌ 无法保存配置更新: \(key)")
            return false
        }
    }
    
    // MARK: - 便捷访问方法
    
    /// DeepSeek API密钥
    var deepseekApiKey: String {
        return string(forKey: "DEEPSEEK_API_KEY")
    }
    
    /// Azure语音服务密钥
    var azureSpeechKey: String {
        return string(forKey: "AZURE_SPEECH_KEY")
    }
    
    /// Azure语音服务区域
    var azureSpeechRegion: String {
        return string(forKey: "AZURE_SPEECH_REGION")
    }
    
    /// 自定义语音ID
    var azureCustomVoiceId: String? {
        let id = string(forKey: "AZURE_CUSTOM_VOICE_ID")
        return id.isEmpty ? nil : id
    }
    
    /// 设置自定义语音ID
    /// - Parameter voiceId: 新的语音ID
    func setCustomVoiceId(_ voiceId: String) {
        update(value: voiceId, forKey: "AZURE_CUSTOM_VOICE_ID")
    }
    
    /// 默认语音类型
    var defaultVoiceType: String {
        return string(forKey: "DEFAULT_VOICE_TYPE")
    }
    
    /// 缓存过期天数
    var cacheExpiryDays: Int {
        return integer(forKey: "CACHE_EXPIRY_DAYS")
    }
    
    /// 默认故事长度
    var defaultStoryLength: String {
        return string(forKey: "DEFAULT_STORY_LENGTH")
    }
    
    /// 最大重试次数
    var maxStoryRetries: Int {
        return integer(forKey: "MAX_STORY_RETRIES")
    }
    
    /// 是否启用内容安全检查
    var contentSafetyEnabled: Bool {
        return boolean(forKey: "CONTENT_SAFETY_ENABLED")
    }
    
    /// 是否允许自定义语音训练
    var allowCustomVoiceTraining: Bool {
        return boolean(forKey: "ALLOW_CUSTOM_VOICE_TRAINING")
    }
    
    /// 是否启用调试日志
    var debugLoggingEnabled: Bool {
        return boolean(forKey: "DEBUG_LOGGING_ENABLED")
    }
    
    /// 是否使用本地备用方案
    var useLocalFallback: Bool {
        return boolean(forKey: "USE_LOCAL_FALLBACK")
    }
    
    /// 是否启用CloudKit同步
    var cloudKitSyncEnabled: Bool {
        let enabled = getBool(forKey: "CLOUDKIT_SYNC_ENABLED", defaultValue: true)
        logger.info("🔍 读取CloudKit同步配置: \(enabled)")
        return enabled
    }
    
    /// 设置CloudKit同步状态
    /// - Parameter enabled: 是否启用
    func setCloudKitSyncEnabled(_ enabled: Bool) {
        logger.info("🔧 设置CloudKit同步为: \(enabled)")
        set(enabled, forKey: "CLOUDKIT_SYNC_ENABLED")
    }
    
    /// 是否在Wi-Fi下自动同步
    var syncOnWifiOnly: Bool {
        return getBool(forKey: "SYNC_ON_WIFI_ONLY", defaultValue: true)
    }
    
    /// 同步频率（小时）
    var syncFrequencyHours: Int {
        return getInt(forKey: "SYNC_FREQUENCY_HOURS", defaultValue: 24)
    }
    
    /// 是否自动下载新故事
    var autoDownloadNewStories: Bool {
        return getBool(forKey: "AUTO_DOWNLOAD_NEW_STORIES", defaultValue: true)
    }
    
    // MARK: - 公共方法
    
    /// 获取字符串配置
    /// - Parameters:
    ///   - key: 配置键
    ///   - defaultValue: 默认值
    /// - Returns: 配置值
    func getString(forKey key: String, defaultValue: String = "") -> String {
        return config[key] as? String ?? defaultValue
    }
    
    /// 获取整数配置
    /// - Parameters:
    ///   - key: 配置键
    ///   - defaultValue: 默认值
    /// - Returns: 配置值
    func getInt(forKey key: String, defaultValue: Int = 0) -> Int {
        return config[key] as? Int ?? defaultValue
    }
    
    /// 获取布尔配置
    /// - Parameters:
    ///   - key: 配置键
    ///   - defaultValue: 默认值
    /// - Returns: 配置值
    func getBool(forKey key: String, defaultValue: Bool = false) -> Bool {
        return config[key] as? Bool ?? defaultValue
    }
    
    /// 设置配置项
    /// - Parameters:
    ///   - value: 配置值
    ///   - key: 配置键
    func set(_ value: Any, forKey key: String) {
        config[key] = value
        saveConfig()
    }
    
    /// 删除配置项
    /// - Parameter key: 配置键
    func removeValue(forKey key: String) {
        config.removeValue(forKey: key)
        saveConfig()
    }
    
    /// 重置为默认配置
    func resetToDefault() {
        config = getDefaultConfig()
        saveConfig()
    }
    
    // MARK: - 私有方法
    
    /// 获取默认配置
    /// - Returns: 默认配置字典
    private func getDefaultConfig() -> [String: Any] {
        return [
            "DEEPSEEK_API_KEY": "",
            "AZURE_SPEECH_KEY": "",
            "AZURE_SPEECH_REGION": "eastasia",
            "AZURE_CUSTOM_VOICE_ID": "",
            "APP_VERSION": "1.0.0",
            "DEFAULT_VOICE_TYPE": "萍萍阿姨",
            "DEFAULT_STORY_LENGTH": "中篇",
            "CACHE_EXPIRY_DAYS": 7,
            "MAX_STORY_RETRIES": 5,
            "CONTENT_SAFETY_ENABLED": true,
            "ALLOW_CUSTOM_VOICE_TRAINING": true,
            "DEBUG_LOGGING_ENABLED": true,
            "USE_LOCAL_FALLBACK": true,
            "CLOUDKIT_SYNC_ENABLED": true,
            "SYNC_ON_WIFI_ONLY": true,
            "SYNC_FREQUENCY_HOURS": 24,
            "AUTO_DOWNLOAD_NEW_STORIES": true
        ]
    }
    
    /// 保存配置到文件
    private func saveConfig() {
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0)
            try plistData.write(to: configURL)
            logger.info("✅ 配置已保存到文件")
        } catch {
            logger.error("❌ 保存配置失败: \(error.localizedDescription)")
        }
    }
} 