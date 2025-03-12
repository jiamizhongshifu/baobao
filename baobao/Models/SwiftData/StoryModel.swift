import Foundation
import SwiftData

/// 故事主题枚举
enum StoryTheme: String, Codable {
    case space = "太空冒险"
    case ocean = "海洋探险"
    case forest = "森林奇遇"
    case dinosaur = "恐龙世界"
    case fairytale = "童话王国"
    
    // 获取所有主题
    static var allThemes: [StoryTheme] {
        return [.space, .ocean, .forest, .dinosaur, .fairytale]
    }
}

/// 故事长度枚举
enum StoryLength: String, Codable {
    case short = "短篇"
    case medium = "中篇"
    case long = "长篇"
    
    // 获取所有长度选项
    static var allLengths: [StoryLength] {
        return [.short, .medium, .long]
    }
}

/// 故事模型
@Model
final class StoryModel {
    // 基本属性
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var createdDate: Date
    var theme: String // 存储StoryTheme的rawValue
    var characterName: String
    var lengthType: String // 存储StoryLength的rawValue
    var isFavorite: Bool
    var readCount: Int
    
    // 关系
    @Relationship(.cascade) var speeches: [SpeechModel]?
    
    // 计算属性
    var storyTheme: StoryTheme? {
        get { return StoryTheme(rawValue: theme) }
        set { if let newValue = newValue { theme = newValue.rawValue } }
    }
    
    var storyLength: StoryLength? {
        get { return StoryLength(rawValue: lengthType) }
        set { if let newValue = newValue { lengthType = newValue.rawValue } }
    }
    
    // 初始化方法
    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        createdDate: Date = Date(),
        theme: StoryTheme,
        characterName: String,
        lengthType: StoryLength,
        isFavorite: Bool = false,
        readCount: Int = 0,
        speeches: [SpeechModel]? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdDate = createdDate
        self.theme = theme.rawValue
        self.characterName = characterName
        self.lengthType = lengthType.rawValue
        self.isFavorite = isFavorite
        self.readCount = readCount
        self.speeches = speeches
    }
}

// MARK: - 辅助方法
extension StoryModel {
    // 增加阅读次数
    func incrementReadCount() {
        readCount += 1
    }
    
    // 切换收藏状态
    func toggleFavorite() {
        isFavorite.toggle()
    }
    
    // 格式化创建日期
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
}

// MARK: - 预览数据
extension StoryModel {
    static var preview: StoryModel {
        StoryModel(
            title: "小明的太空冒险",
            content: "从前有一个叫小明的小男孩，他非常喜欢太空。有一天，他发现了一艘神奇的宇宙飞船...",
            theme: .space,
            characterName: "小明",
            lengthType: .medium
        )
    }
} 