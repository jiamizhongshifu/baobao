import Foundation
import os.log

/// 数据迁移工具，负责将现有的缓存数据迁移到SwiftData
class DataMigrationTool {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = DataMigrationTool()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.migration", category: "DataMigrationTool")
    
    /// 故事仓库
    private let storyRepository = StoryRepository.shared
    
    /// 孩子仓库
    private let childRepository = ChildRepository.shared
    
    /// 设置仓库
    private let settingsRepository = SettingsRepository.shared
    
    /// 缓存管理器
    private let cacheManager = CacheManager.shared
    
    /// 配置管理器
    private let configManager = ConfigurationManager.shared
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 执行数据迁移
    func performMigration(completion: @escaping (Bool) -> Void) {
        logger.info("开始数据迁移")
        
        // 迁移应用设置
        migrateAppSettings()
        
        // 迁移孩子数据
        migrateChildren { [weak self] childrenSuccess in
            guard let self = self else { return }
            
            // 迁移故事数据
            self.migrateStories { storiesSuccess in
                let success = childrenSuccess && storiesSuccess
                self.logger.info("数据迁移\(success ? "成功" : "失败")")
                completion(success)
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 迁移应用设置
    private func migrateAppSettings() {
        logger.info("迁移应用设置")
        
        let settings = settingsRepository.getAppSettings()
        
        // 从ConfigurationManager获取设置
        settings.offlineModeEnabled = false // 默认禁用离线模式
        settings.syncOnWifiOnly = configManager.syncOnWifiOnly
        settings.autoDownloadNewStories = configManager.autoDownloadNewStories
        settings.useLocalTTSByDefault = configManager.useLocalTTSByDefault
        settings.maxCacheSizeMB = configManager.maxCacheSizeMB
        settings.cacheExpiryDays = configManager.cacheExpiryDays
        
        settingsRepository.updateAppSettings(settings)
        
        logger.info("应用设置迁移完成")
    }
    
    /// 迁移孩子数据
    private func migrateChildren(completion: @escaping (Bool) -> Void) {
        logger.info("迁移孩子数据")
        
        // 从文件系统或UserDefaults加载孩子数据
        loadLegacyChildren { [weak self] children in
            guard let self = self else { return completion(false) }
            
            var success = true
            
            for child in children {
                let childModel = self.childRepository.createFromLegacyChild(child)
                
                // 创建默认语音偏好
                if childModel.voicePreference == nil {
                    let voicePreference = VoicePreferenceModel.createDefault(for: childModel)
                    childModel.voicePreference = voicePreference
                    
                    do {
                        try DataManager.shared.mainContext.save()
                    } catch {
                        self.logger.error("保存语音偏好失败: \(error.localizedDescription)")
                        success = false
                    }
                }
            }
            
            self.logger.info("孩子数据迁移完成，共迁移\(children.count)个孩子")
            completion(success)
        }
    }
    
    /// 迁移故事数据
    private func migrateStories(completion: @escaping (Bool) -> Void) {
        logger.info("迁移故事数据")
        
        // 从文件系统或UserDefaults加载故事数据
        loadLegacyStories { [weak self] stories in
            guard let self = self else { return completion(false) }
            
            var success = true
            var migratedCount = 0
            
            for story in stories {
                // 尝试找到对应的孩子
                let children = self.childRepository.searchChildren(byName: story.childName)
                let childModel = children.first
                
                // 创建故事模型
                if let storyModel = self.storyRepository.createFromLegacyStory(story, childId: childModel?.id) {
                    migratedCount += 1
                } else {
                    success = false
                }
            }
            
            self.logger.info("故事数据迁移完成，共迁移\(migratedCount)/\(stories.count)个故事")
            completion(success)
        }
    }
    
    /// 从文件系统或UserDefaults加载旧版孩子数据
    private func loadLegacyChildren(completion: @escaping ([Child]) -> Void) {
        // 这里应该实现从文件系统或UserDefaults加载旧版孩子数据的逻辑
        // 由于我们没有实际的旧版数据，这里返回一个空数组
        completion([])
    }
    
    /// 从文件系统或UserDefaults加载旧版故事数据
    private func loadLegacyStories(completion: @escaping ([Story]) -> Void) {
        // 这里应该实现从文件系统或UserDefaults加载旧版故事数据的逻辑
        // 由于我们没有实际的旧版数据，这里返回一个空数组
        completion([])
    }
} 