import Foundation
import SwiftData

/// 故事模型 - SwiftData兼容
@Model
final class StoryModel {
    // MARK: - 属性
    
    /// 唯一标识符
    var id: String
    
    /// 故事标题
    var title: String
    
    /// 故事内容
    var content: String
    
    /// 故事主题
    var theme: String
    
    /// 主角名字
    var characterName: String
    
    /// 创建时间
    var createdAt: Date
    
    /// 音频文件URL
    var audioURL: String?
    
    /// 音频时长（秒）
    var audioDuration: Double?
    
    /// 上次播放位置（秒）
    var lastPlayPosition: Double?
    
    /// 是否收藏
    var isFavorite: Bool
    
    /// 阅读次数
    var readCount: Int
    
    /// 关联的孩子（可选）
    @Relationship(deleteRule: .cascade, inverse: \ChildModel.stories)
    var child: ChildModel?
    
    // MARK: - 初始化方法
    
    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        theme: String,
        characterName: String,
        createdAt: Date = Date(),
        audioURL: String? = nil,
        audioDuration: Double? = nil,
        lastPlayPosition: Double? = nil,
        isFavorite: Bool = false,
        readCount: Int = 0,
        child: ChildModel? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.characterName = characterName
        self.createdAt = createdAt
        self.audioURL = audioURL
        self.audioDuration = audioDuration
        self.lastPlayPosition = lastPlayPosition
        self.isFavorite = isFavorite
        self.readCount = readCount
        self.child = child
    }
    
    // MARK: - 转换方法
    
    /// 从旧版Story模型创建
    convenience init(from story: Story, child: ChildModel? = nil) {
        self.init(
            id: story.id,
            title: story.title,
            content: story.content,
            theme: story.theme,
            characterName: story.childName,
            createdAt: story.createdAt,
            audioURL: story.audioURL,
            audioDuration: story.audioDuration,
            lastPlayPosition: story.lastPlayPosition,
            child: child
        )
    }
    
    /// 转换为旧版Story模型
    func toStory() -> Story {
        return Story(
            id: id,
            title: title,
            content: content,
            theme: theme,
            childName: characterName,
            createdAt: createdAt,
            audioURL: audioURL,
            audioDuration: audioDuration,
            lastPlayPosition: lastPlayPosition
        )
    }
}

// MARK: - 查询扩展

extension StoryModel {
    /// 获取收藏的故事
    static var favorited: Predicate<StoryModel> {
        #Predicate { story in
            story.isFavorite == true
        }
    }
    
    /// 按主题筛选故事
    static func withTheme(_ theme: String) -> Predicate<StoryModel> {
        #Predicate { story in
            story.theme == theme
        }
    }
    
    /// 按角色名筛选故事
    static func withCharacterName(_ name: String) -> Predicate<StoryModel> {
        #Predicate { story in
            story.characterName == name
        }
    }
    
    /// 按创建时间排序（最新的在前）
    static var sortByCreatedAtDesc: SortDescriptor<StoryModel> {
        SortDescriptor(\.createdAt, order: .reverse)
    }
} 