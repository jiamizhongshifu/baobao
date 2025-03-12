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
    // 保留单例以便向后兼容，但推荐使用依赖注入方式
    static let shared = ModelManager()
    
    // 公开初始化方法，允许创建多个实例
    init() {}
    
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
                do {
                    try context.save()
                } catch {
                    print("保存新用户设置失败: \(error.localizedDescription)")
                    // 即使保存失败，仍然返回新创建的设置对象
                }
                return newSettings
            }
        } catch {
            print("获取用户设置失败: \(error.localizedDescription)")
            let newSettings = UserSettingsModel()
            context.insert(newSettings)
            do {
                try context.save()
            } catch {
                print("保存新用户设置失败: \(error.localizedDescription)")
                // 即使保存失败，仍然返回新创建的设置对象
            }
            return newSettings
        }
    }
    
    /// 获取故事列表
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - isFavoriteOnly: 是否只获取收藏的故事
    /// - Returns: 故事列表
    func getStories(context: ModelContext, isFavoriteOnly: Bool = false) -> [StoryModel] {
        var descriptor = FetchDescriptor<StoryModel>()
        
        if isFavoriteOnly {
            descriptor.predicate = #Predicate { $0.isFavorite == true }
        }
        
        descriptor.sortBy = [SortDescriptor(\.createdDate, order: .reverse)]
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取故事列表（分页）
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - page: 页码（从0开始）
    ///   - pageSize: 每页大小
    ///   - isFavoriteOnly: 是否只获取收藏的故事
    /// - Returns: 故事列表
    func getStoriesWithPagination(context: ModelContext, page: Int, pageSize: Int, isFavoriteOnly: Bool = false) -> [StoryModel] {
        var descriptor = FetchDescriptor<StoryModel>()
        
        if isFavoriteOnly {
            descriptor.predicate = #Predicate { $0.isFavorite == true }
        }
        
        descriptor.sortBy = [SortDescriptor(\.createdDate, order: .reverse)]
        descriptor.fetchOffset = page * pageSize
        descriptor.fetchLimit = pageSize
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取故事分页失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取故事总数
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - isFavoriteOnly: 是否只获取收藏的故事
    /// - Returns: 故事总数
    func getStoriesCount(context: ModelContext, isFavoriteOnly: Bool = false) -> Int {
        var descriptor = FetchDescriptor<StoryModel>()
        
        if isFavoriteOnly {
            descriptor.predicate = #Predicate { $0.isFavorite == true }
        }
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            print("获取故事总数失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 获取最近的故事
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - limit: 限制数量
    /// - Returns: 故事列表
    func getRecentStories(context: ModelContext, limit: Int) -> [StoryModel] {
        var descriptor = FetchDescriptor<StoryModel>()
        descriptor.sortBy = [SortDescriptor(\.createdDate, order: .reverse)]
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取最近故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取特定主题的故事
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - theme: 故事主题
    /// - Returns: 故事列表
    func getStoriesByTheme(context: ModelContext, theme: SDStoryTheme) -> [StoryModel] {
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { $0.themeString == theme.rawValue },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取特定主题故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取特定角色的故事
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - characterName: 角色名称
    /// - Returns: 故事列表
    func getStoriesByCharacter(context: ModelContext, characterName: String) -> [StoryModel] {
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { $0.characterName == characterName },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取特定角色故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取故事及其关联的语音
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - storyId: 故事ID
    /// - Returns: 故事对象
    func getStoryWithSpeeches(context: ModelContext, storyId: String) -> StoryModel? {
        var descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { $0.id == storyId }
        )
        
        do {
            let stories = try context.fetch(descriptor)
            return stories.first
        } catch {
            print("获取故事及语音失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 搜索故事
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - query: 搜索关键词
    /// - Returns: 故事列表
    func searchStories(context: ModelContext, query: String) -> [StoryModel] {
        // 如果搜索关键词为空，返回空数组
        if query.isEmpty {
            return []
        }
        
        // 构建搜索谓词
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { 
                $0.title.localizedStandardContains(query) ||
                $0.content.localizedStandardContains(query) ||
                $0.characterName.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("搜索故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取缓存记录
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - type: 缓存类型
    /// - Returns: 缓存记录列表
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
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - expiryDays: 过期天数
    /// - Returns: 过期缓存记录列表
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
    /// - Parameter context: 模型上下文
    /// - Returns: 缓存总大小（字节）
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
    
    /// 批量操作
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - batchSize: 批处理大小
    ///   - operation: 批处理操作
    func batchOperation<T>(context: ModelContext, type: T.Type, batchSize: Int = 100, operation: (T) -> Void) where T: PersistentModel {
        var offset = 0
        var hasMore = true
        
        while hasMore {
            var descriptor = FetchDescriptor<T>()
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset
            
            do {
                let batch = try context.fetch(descriptor)
                
                if batch.isEmpty {
                    hasMore = false
                } else {
                    for item in batch {
                        operation(item)
                    }
                    
                    offset += batch.count
                }
            } catch {
                print("批量操作失败: \(error.localizedDescription)")
                hasMore = false
            }
        }
    }
    
    /// 执行批量删除
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - predicate: 删除条件
    func batchDelete<T>(context: ModelContext, type: T.Type, predicate: Predicate<T>) where T: PersistentModel {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        
        do {
            let itemsToDelete = try context.fetch(descriptor)
            
            for item in itemsToDelete {
                context.delete(item)
            }
            
            try context.save()
        } catch {
            print("批量删除失败: \(error.localizedDescription)")
        }
    }
}

/// 模型管理器协议，用于依赖注入和测试
protocol ModelManaging {
    func getUserSettings(context: ModelContext) -> UserSettingsModel
    func getStories(context: ModelContext, isFavoriteOnly: Bool) -> [StoryModel]
    func getStoriesWithPagination(context: ModelContext, page: Int, pageSize: Int, isFavoriteOnly: Bool) -> [StoryModel]
    func getStoriesCount(context: ModelContext, isFavoriteOnly: Bool) -> Int
    func getRecentStories(context: ModelContext, limit: Int) -> [StoryModel]
    func getStoriesByTheme(context: ModelContext, theme: SDStoryTheme) -> [StoryModel]
    func getStoriesByCharacter(context: ModelContext, characterName: String) -> [StoryModel]
    func getStoryWithSpeeches(context: ModelContext, storyId: String) -> StoryModel?
    func searchStories(context: ModelContext, query: String) -> [StoryModel]
    func getCacheRecords(context: ModelContext, type: CacheType?) -> [CacheRecordModel]
    func getExpiredCacheRecords(context: ModelContext, expiryDays: Int) -> [CacheRecordModel]
    func calculateTotalCacheSize(context: ModelContext) -> Int64
    func batchOperation<T>(context: ModelContext, type: T.Type, batchSize: Int, operation: (T) -> Void) where T: PersistentModel
    func batchDelete<T>(context: ModelContext, type: T.Type, predicate: Predicate<T>) where T: PersistentModel
}

// 让ModelManager实现ModelManaging协议
extension ModelManager: ModelManaging {} 