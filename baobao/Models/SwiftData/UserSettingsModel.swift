import Foundation
import SwiftData

/// 用户设置模型
@Model
final class UserSettingsModel {
    // 基本属性
    @Attribute(.unique) var id: String
    var defaultVoiceTypeString: String // 存储SDVoiceType的rawValue
    var isOfflineModeEnabled: Bool
    var autoDownloadNewStories: Bool
    var syncOnWifiOnly: Bool
    var maxCacheSizeMB: Int
    var cacheExpiryDays: Int
    var lastUsedCharacterName: String?
    var lastUpdated: Date
    
    // 计算属性
    var defaultVoiceType: SDVoiceType? {
        get { return SDVoiceType(rawValue: defaultVoiceTypeString) }
        set { if let newValue = newValue { defaultVoiceTypeString = newValue.rawValue } }
    }
    
    // 初始化方法
    init(
        id: String = "userSettings", // 使用固定ID，确保只有一个设置实例
        defaultVoiceType: SDVoiceType = .xiaoMing,
        isOfflineModeEnabled: Bool = false,
        autoDownloadNewStories: Bool = true,
        syncOnWifiOnly: Bool = true,
        maxCacheSizeMB: Int = 500,
        cacheExpiryDays: Int = 30,
        lastUsedCharacterName: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.defaultVoiceTypeString = defaultVoiceType.rawValue
        self.isOfflineModeEnabled = isOfflineModeEnabled
        self.autoDownloadNewStories = autoDownloadNewStories
        self.syncOnWifiOnly = syncOnWifiOnly
        self.maxCacheSizeMB = maxCacheSizeMB
        self.cacheExpiryDays = cacheExpiryDays
        self.lastUsedCharacterName = lastUsedCharacterName
        self.lastUpdated = lastUpdated
    }
}

// MARK: - 辅助方法
extension UserSettingsModel {
    // 切换离线模式
    func toggleOfflineMode() {
        isOfflineModeEnabled.toggle()
        lastUpdated = Date()
    }
    
    // 更新默认语音类型
    func updateDefaultVoiceType(_ voiceType: SDVoiceType) {
        defaultVoiceTypeString = voiceType.rawValue
        lastUpdated = Date()
    }
    
    // 更新最后使用的角色名称
    func updateLastUsedCharacterName(_ name: String?) {
        lastUsedCharacterName = name
        lastUpdated = Date()
    }
    
    // 更新缓存设置
    func updateCacheSettings(maxSizeMB: Int, expiryDays: Int) {
        maxCacheSizeMB = maxSizeMB
        cacheExpiryDays = expiryDays
        lastUpdated = Date()
    }
    
    // 格式化最后更新日期
    var formattedLastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
}

// MARK: - 预览数据
extension UserSettingsModel {
    static var preview: UserSettingsModel {
        UserSettingsModel(
            defaultVoiceType: .xiaoMing,
            isOfflineModeEnabled: false,
            autoDownloadNewStories: true,
            syncOnWifiOnly: true,
            maxCacheSizeMB: 500,
            cacheExpiryDays: 30,
            lastUsedCharacterName: "小明"
        )
    }
    
    // 获取默认设置
    static var defaultSettings: UserSettingsModel {
        UserSettingsModel()
    }
} 