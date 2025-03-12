import Foundation
import SwiftData
import os.log

/// 数据管理器，负责管理SwiftData的访问
class DataManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = DataManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.data", category: "DataManager")
    
    /// 模型容器
    private(set) var modelContainer: ModelContainer
    
    /// 主上下文
    private(set) var mainContext: ModelContext
    
    /// 后台上下文
    private var backgroundContext: ModelContext {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = true
        return context
    }
    
    // MARK: - 初始化
    
    private init() {
        do {
            // 创建模型容器
            let schema = Schema([
                StoryModel.self,
                ChildModel.self,
                VoicePreferenceModel.self,
                AppSettingsModel.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // 创建主上下文
            mainContext = ModelContext(modelContainer)
            mainContext.autosaveEnabled = true
            
            // 初始化应用设置
            initializeAppSettings()
            
            logger.info("数据管理器初始化成功")
        } catch {
            fatalError("无法初始化SwiftData: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 私有方法
    
    /// 初始化应用设置
    private func initializeAppSettings() {
        let fetchDescriptor = FetchDescriptor<AppSettingsModel>(predicate: AppSettingsModel.current)
        
        do {
            let settings = try mainContext.fetch(fetchDescriptor)
            
            if settings.isEmpty {
                // 创建默认设置
                let defaultSettings = AppSettingsModel.createDefault()
                mainContext.insert(defaultSettings)
                try mainContext.save()
                logger.info("创建了默认应用设置")
            }
        } catch {
            logger.error("初始化应用设置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 公共方法
    
    /// 获取应用设置
    func getAppSettings() -> AppSettingsModel? {
        let fetchDescriptor = FetchDescriptor<AppSettingsModel>(predicate: AppSettingsModel.current)
        
        do {
            let settings = try mainContext.fetch(fetchDescriptor)
            return settings.first
        } catch {
            logger.error("获取应用设置失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 在后台上下文执行任务
    func performBackgroundTask(_ task: @escaping (ModelContext) -> Void) {
        let context = backgroundContext
        Task {
            task(context)
        }
    }
    
    /// 在后台上下文执行异步任务
    func performBackgroundTask<T>(_ task: @escaping (ModelContext) async throws -> T) async throws -> T {
        let context = backgroundContext
        return try await task(context)
    }
    
    /// 迁移旧数据
    func migrateOldData() {
        // TODO: 实现从旧数据格式到SwiftData的迁移
        logger.info("开始迁移旧数据")
        
        // 迁移故事数据
        // migrateStories()
        
        // 迁移孩子数据
        // migrateChildren()
        
        logger.info("旧数据迁移完成")
    }
} 