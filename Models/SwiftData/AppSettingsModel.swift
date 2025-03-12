import Foundation
import SwiftData

/// 应用设置模型
@Model
final class AppSettingsModel {
    // MARK: - 属性
    
    /// 唯一标识符（始终为"app_settings"）
    var id: String
    
    /// 是否启用离线模式
    var offlineModeEnabled: Bool
    
    /// 是否仅在WiFi下同步
    var syncOnWifiOnly: Bool
    
    /// 是否自动下载新故事
    var autoDownloadNewStories: Bool
    
    /// 是否默认使用本地TTS
    var useLocalTTSByDefault: Bool
    
    /// 最大缓存大小（MB）
    var maxCacheSizeMB: Int
    
    /// 缓存过期天数
    var cacheExpiryDays: Int
    
    /// 最后修改时间
    var updatedAt: Date
    
    // MARK: - 初始化方法
    
    init(
        id: String = "app_settings",
        offlineModeEnabled: Bool = false,
        syncOnWifiOnly: Bool = true,
        autoDownloadNewStories: Bool = false,
        useLocalTTSByDefault: Bool = false,
        maxCacheSizeMB: Int = 500,
        cacheExpiryDays: Int = 30,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.offlineModeEnabled = offlineModeEnabled
        self.syncOnWifiOnly = syncOnWifiOnly
        self.autoDownloadNewStories = autoDownloadNewStories
        self.useLocalTTSByDefault = useLocalTTSByDefault
        self.maxCacheSizeMB = maxCacheSizeMB
        self.cacheExpiryDays = cacheExpiryDays
        self.updatedAt = updatedAt
    }
    
    /// 创建默认应用设置
    static func createDefault() -> AppSettingsModel {
        return AppSettingsModel()
    }
}

// MARK: - 查询扩展

extension AppSettingsModel {
    /// 获取应用设置（应该只有一个实例）
    static var current: Predicate<AppSettingsModel> {
        #Predicate { settings in
            settings.id == "app_settings"
        }
    }
} 