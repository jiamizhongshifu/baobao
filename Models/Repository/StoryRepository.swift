import Foundation
import SwiftData
import os.log
import Combine

/// 故事仓库，负责处理故事相关的数据操作
class StoryRepository {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = StoryRepository()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.repository", category: "StoryRepository")
    
    /// 数据管理器
    private let dataManager = DataManager.shared
    
    /// 故事变更发布者
    private let storyChangesSubject = PassthroughSubject<Void, Never>()
    
    /// 故事变更发布者
    var storyChangesPublisher: AnyPublisher<Void, Never> {
        return storyChangesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 获取所有故事
    func getAllStories() -> [StoryModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<StoryModel>(sortBy: [StoryModel.sortByCreatedAtDesc])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("获取所有故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取收藏的故事
    func getFavoriteStories() -> [StoryModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: StoryModel.favorited,
            sortBy: [StoryModel.sortByCreatedAtDesc]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("获取收藏故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 按主题获取故事
    func getStories(withTheme theme: String) -> [StoryModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: StoryModel.withTheme(theme),
            sortBy: [StoryModel.sortByCreatedAtDesc]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("获取主题故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 按角色名获取故事
    func getStories(withCharacterName name: String) -> [StoryModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: StoryModel.withCharacterName(name),
            sortBy: [StoryModel.sortByCreatedAtDesc]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("获取角色故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取孩子的故事
    func getStories(forChild childId: String) -> [StoryModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { story in
                story.child?.id == childId
            },
            sortBy: [StoryModel.sortByCreatedAtDesc]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("获取孩子故事失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 按ID获取故事
    func getStory(withId id: String) -> StoryModel? {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<StoryModel>(
            predicate: #Predicate { story in
                story.id == id
            }
        )
        
        do {
            let stories = try context.fetch(descriptor)
            return stories.first
        } catch {
            logger.error("获取故事失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 保存故事
    func saveStory(_ story: StoryModel) {
        let context = dataManager.mainContext
        
        // 检查是否已存在
        if let existingStory = getStory(withId: story.id) {
            // 更新现有故事
            existingStory.title = story.title
            existingStory.content = story.content
            existingStory.theme = story.theme
            existingStory.characterName = story.characterName
            existingStory.audioURL = story.audioURL
            existingStory.audioDuration = story.audioDuration
            existingStory.isFavorite = story.isFavorite
            existingStory.readCount = story.readCount
        } else {
            // 添加新故事
            context.insert(story)
        }
        
        do {
            try context.save()
            storyChangesSubject.send()
            logger.info("保存故事成功: \(story.id)")
        } catch {
            logger.error("保存故事失败: \(error.localizedDescription)")
        }
    }
    
    /// 删除故事
    func deleteStory(_ story: StoryModel) {
        let context = dataManager.mainContext
        context.delete(story)
        
        do {
            try context.save()
            storyChangesSubject.send()
            logger.info("删除故事成功: \(story.id)")
        } catch {
            logger.error("删除故事失败: \(error.localizedDescription)")
        }
    }
    
    /// 切换故事收藏状态
    func toggleFavorite(storyId: String) -> Bool {
        guard let story = getStory(withId: storyId) else {
            logger.error("切换收藏状态失败: 未找到故事 \(storyId)")
            return false
        }
        
        story.isFavorite = !story.isFavorite
        
        do {
            try dataManager.mainContext.save()
            storyChangesSubject.send()
            logger.info("切换收藏状态成功: \(storyId), 新状态: \(story.isFavorite)")
            return true
        } catch {
            logger.error("切换收藏状态失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 更新故事播放位置
    func updatePlayPosition(storyId: String, position: Double) {
        guard let story = getStory(withId: storyId) else {
            logger.error("更新播放位置失败: 未找到故事 \(storyId)")
            return
        }
        
        story.lastPlayPosition = position
        
        do {
            try dataManager.mainContext.save()
            logger.info("更新播放位置成功: \(storyId), 位置: \(position)")
        } catch {
            logger.error("更新播放位置失败: \(error.localizedDescription)")
        }
    }
    
    /// 增加阅读次数
    func incrementReadCount(storyId: String) {
        guard let story = getStory(withId: storyId) else {
            logger.error("增加阅读次数失败: 未找到故事 \(storyId)")
            return
        }
        
        story.readCount += 1
        
        do {
            try dataManager.mainContext.save()
            logger.info("增加阅读次数成功: \(storyId), 新次数: \(story.readCount)")
        } catch {
            logger.error("增加阅读次数失败: \(error.localizedDescription)")
        }
    }
    
    /// 从旧版Story创建并保存StoryModel
    func createFromLegacyStory(_ legacyStory: Story, childId: String? = nil) -> StoryModel? {
        // 如果指定了孩子ID，获取对应的ChildModel
        var childModel: ChildModel? = nil
        if let childId = childId {
            childModel = ChildRepository.shared.getChild(withId: childId)
        }
        
        // 创建新的StoryModel
        let storyModel = StoryModel(from: legacyStory, child: childModel)
        
        // 保存到数据库
        saveStory(storyModel)
        
        return storyModel
    }
} 