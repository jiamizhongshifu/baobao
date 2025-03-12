import Foundation
import SwiftData

/// 应用设置模型
@Model
final class AppSettings {
    /// 唯一标识符（始终为"app_settings"）
    var id: String
    /// 默认语音类型
    var defaultVoiceType: String
    /// 缓存过期天数
    var cacheExpiryDays: Int
    /// 最大缓存大小（MB）
    var maxCacheSizeMB: Int
    /// 是否使用本地备选方案
    var useLocalFallback: Bool
    /// 是否默认使用本地TTS
    var useLocalTTSByDefault: Bool
    /// 是否自动下载新故事
    var autoDownloadNewStories: Bool
    /// 是否仅在WiFi下同步
    var syncOnWiFiOnly: Bool
    /// 是否启用离线模式
    var offlineModeEnabled: Bool
    /// 最后更新时间
    var updatedAt: Date
    
    init(
        id: String = "app_settings",
        defaultVoiceType: String = VoiceType.xiaoMing.rawValue,
        cacheExpiryDays: Int = 30,
        maxCacheSizeMB: Int = 500,
        useLocalFallback: Bool = true,
        useLocalTTSByDefault: Bool = false,
        autoDownloadNewStories: Bool = false,
        syncOnWiFiOnly: Bool = true,
        offlineModeEnabled: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.defaultVoiceType = defaultVoiceType
        self.cacheExpiryDays = cacheExpiryDays
        self.maxCacheSizeMB = maxCacheSizeMB
        self.useLocalFallback = useLocalFallback
        self.useLocalTTSByDefault = useLocalTTSByDefault
        self.autoDownloadNewStories = autoDownloadNewStories
        self.syncOnWiFiOnly = syncOnWiFiOnly
        self.offlineModeEnabled = offlineModeEnabled
        self.updatedAt = updatedAt
    }
} 