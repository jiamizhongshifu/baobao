import Foundation
import SwiftData

/// 数据管理器，负责SwiftData的初始化和数据访问
class DataManager {
    /// 单例实例
    static let shared = DataManager()
    
    /// SwiftData模型容器
    private(set) var modelContainer: ModelContainer?
    
    /// 私有初始化方法
    private init() {
        setupModelContainer()
    }
    
    /// 设置SwiftData模型容器
    private func setupModelContainer() {
        do {
            // 创建模型容器配置
            let schema = Schema([
                Child.self,
                Story.self,
                CacheRecord.self,
                AppSettings.self
            ])
            
            // 配置选项
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            // 创建模型容器
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // 初始化应用设置
            initializeAppSettings()
            
            print("SwiftData模型容器初始化成功")
        } catch {
            print("SwiftData模型容器初始化失败: \(error.localizedDescription)")
        }
    }
    
    /// 初始化应用设置
    private func initializeAppSettings() {
        guard let modelContainer = modelContainer else { return }
        
        let context = modelContainer.mainContext
        
        // 检查是否已存在应用设置
        let descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.id == "app_settings" }
        )
        
        do {
            let existingSettings = try context.fetch(descriptor)
            
            if existingSettings.isEmpty {
                // 创建默认设置
                let defaultSettings = AppSettings()
                context.insert(defaultSettings)
                try context.save()
                print("已创建默认应用设置")
            }
        } catch {
            print("初始化应用设置失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取主上下文
    var mainContext: ModelContext? {
        return modelContainer?.mainContext
    }
    
    /// 创建新的上下文
    func newContext() -> ModelContext? {
        guard let modelContainer = modelContainer else { return nil }
        return ModelContext(modelContainer)
    }
    
    /// 保存上下文更改
    func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("保存上下文失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 孩子相关方法
    
    /// 获取所有孩子
    func getAllChildren() -> [Child] {
        guard let context = mainContext else { return [] }
        
        let descriptor = FetchDescriptor<Child>(sortBy: [SortDescriptor(\.name)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取孩子列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据ID获取孩子
    func getChild(byId id: String) -> Child? {
        guard let context = mainContext else { return nil }
        
        let descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let children = try context.fetch(descriptor)
            return children.first
        } catch {
            print("获取孩子失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 添加孩子
    func addChild(_ child: Child) {
        guard let context = mainContext else { return }
        
        context.insert(child)
        saveContext(context)
    }
    
    /// 更新孩子
    func updateChild(_ child: Child) {
        guard let context = mainContext else { return }
        
        saveContext(context)
    }
    
    /// 删除孩子
    func deleteChild(_ child: Child) {
        guard let context = mainContext else { return }
        
        context.delete(child)
        saveContext(context)
    }
    
    // MARK: - 故事相关方法
    
    /// 获取所有故事
    func getAllStories() -> [Story] {
        guard let context = mainContext else { return [] }
        
        let descriptor = FetchDescriptor<Story>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取故事列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取孩子的故事
    func getStories(forChildId childId: String) -> [Story] {
        guard let context = mainContext else { return [] }
        
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate { $0.childId == childId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取孩子故事列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取收藏的故事
    func getFavoriteStories() -> [Story] {
        guard let context = mainContext else { return [] }
        
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取收藏故事列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据ID获取故事
    func getStory(byId id: String) -> Story? {
        guard let context = mainContext else { return nil }
        
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let stories = try context.fetch(descriptor)
            return stories.first
        } catch {
            print("获取故事失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 添加故事
    func addStory(_ story: Story) {
        guard let context = mainContext else { return }
        
        context.insert(story)
        saveContext(context)
    }
    
    /// 更新故事
    func updateStory(_ story: Story) {
        guard let context = mainContext else { return }
        
        saveContext(context)
    }
    
    /// 删除故事
    func deleteStory(_ story: Story) {
        guard let context = mainContext else { return }
        
        context.delete(story)
        saveContext(context)
    }
    
    // MARK: - 缓存记录相关方法
    
    /// 获取所有缓存记录
    func getAllCacheRecords() -> [CacheRecord] {
        guard let context = mainContext else { return [] }
        
        let descriptor = FetchDescriptor<CacheRecord>(
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取缓存记录列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据类型获取缓存记录
    func getCacheRecords(ofType type: CacheType) -> [CacheRecord] {
        guard let context = mainContext else { return [] }
        
        let descriptor = FetchDescriptor<CacheRecord>(
            predicate: #Predicate { $0.type == type.rawValue },
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取缓存记录列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据关联ID获取缓存记录
    func getCacheRecord(forRelatedId relatedId: String, type: CacheType) -> CacheRecord? {
        guard let context = mainContext else { return nil }
        
        let descriptor = FetchDescriptor<CacheRecord>(
            predicate: #Predicate { $0.relatedId == relatedId && $0.type == type.rawValue }
        )
        
        do {
            let records = try context.fetch(descriptor)
            return records.first
        } catch {
            print("获取缓存记录失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 添加缓存记录
    func addCacheRecord(_ record: CacheRecord) {
        guard let context = mainContext else { return }
        
        context.insert(record)
        saveContext(context)
    }
    
    /// 更新缓存记录
    func updateCacheRecord(_ record: CacheRecord) {
        guard let context = mainContext else { return }
        
        saveContext(context)
    }
    
    /// 删除缓存记录
    func deleteCacheRecord(_ record: CacheRecord) {
        guard let context = mainContext else { return }
        
        context.delete(record)
        saveContext(context)
    }
    
    /// 删除过期缓存记录
    func deleteExpiredCacheRecords() {
        guard let context = mainContext else { return }
        
        let descriptor = FetchDescriptor<CacheRecord>(
            predicate: #Predicate { $0.expiresAt != nil && $0.expiresAt! < Date() && !$0.isPredownloaded }
        )
        
        do {
            let expiredRecords = try context.fetch(descriptor)
            
            for record in expiredRecords {
                // 删除文件
                if let url = URL(string: record.path) {
                    try? FileManager.default.removeItem(at: url)
                }
                
                // 删除记录
                context.delete(record)
            }
            
            saveContext(context)
            print("已删除\(expiredRecords.count)条过期缓存记录")
        } catch {
            print("删除过期缓存记录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 应用设置相关方法
    
    /// 获取应用设置
    func getAppSettings() -> AppSettings? {
        guard let context = mainContext else { return nil }
        
        let descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.id == "app_settings" }
        )
        
        do {
            let settings = try context.fetch(descriptor)
            return settings.first
        } catch {
            print("获取应用设置失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 更新应用设置
    func updateAppSettings(_ settings: AppSettings) {
        guard let context = mainContext else { return }
        
        settings.updatedAt = Date()
        saveContext(context)
    }
} 