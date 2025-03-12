import Foundation
import SwiftData

/// SwiftData模型容器配置
struct ModelContainerSetup {
    /// 获取应用的模型容器
    static func getModelContainer() -> ModelContainer {
        let schema = Schema([
            StoryModel.self,
            SpeechModel.self,
            UserSettingsModel.self,
            CacheRecordModel.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// 获取预览用的模型容器（内存存储）
    static func getPreviewModelContainer() -> ModelContainer {
        let schema = Schema([
            StoryModel.self,
            SpeechModel.self,
            UserSettingsModel.self,
            CacheRecordModel.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // 添加预览数据
            Task { @MainActor in
                // 添加用户设置
                let settings = UserSettingsModel.preview
                container.mainContext.insert(settings)
                
                // 添加故事
                let story = StoryModel.preview
                container.mainContext.insert(story)
                
                // 添加语音
                let speech = SpeechModel.preview
                speech.story = story
                container.mainContext.insert(speech)
                
                // 添加缓存记录
                let cacheRecord = CacheRecordModel.preview
                container.mainContext.insert(cacheRecord)
                
                try container.mainContext.save()
            }
            
            return container
        } catch {
            fatalError("无法创建预览ModelContainer: \(error.localizedDescription)")
        }
    }
}

/// 模型管理器，提供对模型的访问和操作
class ModelManager {
    static let shared = ModelManager()
    
    private init() {}
    
    /// 获取或创建用户设置
    func getUserSettings(context: ModelContext) -> UserSettingsModel {
        let descriptor = FetchDescriptor<UserSettingsModel>(
            predicate: #Predicate { $0.id == "userSettings" }
        )
        
        do {
            let settings = try context.fetch(descriptor)
            if let existingSettings = settings.first {
                return existingSettings
            } else {
                let newSettings = UserSettingsModel()
                context.insert(newSettings)
                try context.save()
                return newSettings
            }
        } catch {
            print("获取用户设置失败: \(error.localizedDescription)")
            let newSettings = UserSettingsModel()
            context.insert(newSettings)
            try? context.save()
            return newSettings
        }
    }
    
    /// 获取故事列表
    func getStories(context: ModelContext, isFavoriteOnly: Bool = false) -> [StoryModel] {
        var descriptor = FetchDescriptor<StoryModel>()
        
        if isFavoriteOnly {
            descriptor.predicate = #Predicate { $0.isFavorite == true }
        }
        
        descriptor.sortBy = [SortDescriptor(\.createdDate, order: .reverse)]
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取故事列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取特定主题的故事
    func getStoriesByTheme(context: ModelContext, theme: StoryTheme) -> [StoryModel] {
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { $0.theme == theme.rawValue },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取主题故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取特定角色的故事
    func getStoriesByCharacter(context: ModelContext, characterName: String) -> [StoryModel] {
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { $0.characterName == characterName },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取角色故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取缓存记录
    func getCacheRecords(context: ModelContext, type: CacheType? = nil) -> [CacheRecordModel] {
        var descriptor = FetchDescriptor<CacheRecordModel>()
        
        if let type = type {
            descriptor.predicate = #Predicate { $0.cacheTypeString == type.rawValue }
        }
        
        descriptor.sortBy = [SortDescriptor(\.lastAccessedDate, order: .reverse)]
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取缓存记录失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取过期缓存记录
    func getExpiredCacheRecords(context: ModelContext, expiryDays: Int) -> [CacheRecordModel] {
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: -expiryDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<CacheRecordModel>(
            predicate: #Predicate { $0.lastAccessedDate < expiryDate },
            sortBy: [SortDescriptor(\.lastAccessedDate)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取过期缓存记录失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 计算缓存总大小
    func calculateTotalCacheSize(context: ModelContext) -> Int64 {
        let descriptor = FetchDescriptor<CacheRecordModel>()
        
        do {
            let records = try context.fetch(descriptor)
            return records.reduce(0) { $0 + $1.fileSize }
        } catch {
            print("计算缓存大小失败: \(error.localizedDescription)")
            return 0
        }
    }
} 