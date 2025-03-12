import Foundation
import SwiftData
import os.log
import Combine

/// 设置仓库，负责处理应用设置相关的数据操作
class SettingsRepository {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = SettingsRepository()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.repository", category: "SettingsRepository")
    
    /// 数据管理器
    private let dataManager = DataManager.shared
    
    /// 设置变更发布者
    private let settingsChangesSubject = PassthroughSubject<AppSettingsModel, Never>()
    
    /// 设置变更发布者
    var settingsChangesPublisher: AnyPublisher<AppSettingsModel, Never> {
        return settingsChangesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 获取应用设置
    func getAppSettings() -> AppSettingsModel {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<AppSettingsModel>(predicate: AppSettingsModel.current)
        
        do {
            let settings = try context.fetch(descriptor)
            
            if let appSettings = settings.first {
                return appSettings
            } else {
                // 如果没有找到设置，创建默认设置
                let defaultSettings = AppSettingsModel.createDefault()
                context.insert(defaultSettings)
                try context.save()
                logger.info("创建了默认应用设置")
                return defaultSettings
            }
        } catch {
            logger.error("获取应用设置失败: \(error.localizedDescription)")
            
            // 返回内存中的默认设置（不保存到数据库）
            return AppSettingsModel.createDefault()
        }
    }
    
    /// 更新应用设置
    func updateAppSettings(_ settings: AppSettingsModel) {
        let context = dataManager.mainContext
        
        do {
            settings.updatedAt = Date()
            try context.save()
            settingsChangesSubject.send(settings)
            logger.info("更新应用设置成功")
        } catch {
            logger.error("更新应用设置失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置离线模式
    func setOfflineMode(enabled: Bool) {
        let settings = getAppSettings()
        settings.offlineModeEnabled = enabled
        settings.updatedAt = Date()
        
        do {
            try dataManager.mainContext.save()
            settingsChangesSubject.send(settings)
            logger.info("设置离线模式: \(enabled)")
        } catch {
            logger.error("设置离线模式失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置WiFi同步选项
    func setSyncOnWifiOnly(enabled: Bool) {
        let settings = getAppSettings()
        settings.syncOnWifiOnly = enabled
        settings.updatedAt = Date()
        
        do {
            try dataManager.mainContext.save()
            settingsChangesSubject.send(settings)
            logger.info("设置WiFi同步: \(enabled)")
        } catch {
            logger.error("设置WiFi同步失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置自动下载新故事选项
    func setAutoDownloadNewStories(enabled: Bool) {
        let settings = getAppSettings()
        settings.autoDownloadNewStories = enabled
        settings.updatedAt = Date()
        
        do {
            try dataManager.mainContext.save()
            settingsChangesSubject.send(settings)
            logger.info("设置自动下载新故事: \(enabled)")
        } catch {
            logger.error("设置自动下载新故事失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置默认使用本地TTS选项
    func setUseLocalTTSByDefault(enabled: Bool) {
        let settings = getAppSettings()
        settings.useLocalTTSByDefault = enabled
        settings.updatedAt = Date()
        
        do {
            try dataManager.mainContext.save()
            settingsChangesSubject.send(settings)
            logger.info("设置默认使用本地TTS: \(enabled)")
        } catch {
            logger.error("设置默认使用本地TTS失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置最大缓存大小
    func setMaxCacheSize(sizeMB: Int) {
        let settings = getAppSettings()
        settings.maxCacheSizeMB = sizeMB
        settings.updatedAt = Date()
        
        do {
            try dataManager.mainContext.save()
            settingsChangesSubject.send(settings)
            logger.info("设置最大缓存大小: \(sizeMB)MB")
        } catch {
            logger.error("设置最大缓存大小失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置缓存过期天数
    func setCacheExpiryDays(days: Int) {
        let settings = getAppSettings()
        settings.cacheExpiryDays = days
        settings.updatedAt = Date()
        
        do {
            try dataManager.mainContext.save()
            settingsChangesSubject.send(settings)
            logger.info("设置缓存过期天数: \(days)天")
        } catch {
            logger.error("设置缓存过期天数失败: \(error.localizedDescription)")
        }
    }
    
    /// 重置为默认设置
    func resetToDefaults() {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<AppSettingsModel>(predicate: AppSettingsModel.current)
        
        do {
            let settings = try context.fetch(descriptor)
            
            if let appSettings = settings.first {
                // 删除现有设置
                context.delete(appSettings)
                try context.save()
            }
            
            // 创建新的默认设置
            let defaultSettings = AppSettingsModel.createDefault()
            context.insert(defaultSettings)
            try context.save()
            
            settingsChangesSubject.send(defaultSettings)
            logger.info("重置为默认设置")
        } catch {
            logger.error("重置为默认设置失败: \(error.localizedDescription)")
        }
    }
} 