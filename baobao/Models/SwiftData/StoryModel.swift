import Foundation
import SwiftData

/// 故事主题
enum SDStoryTheme: String, Codable, CaseIterable {
    case space = "太空冒险"
    case ocean = "海洋探险"
    case forest = "森林奇遇"
    case dinosaur = "恐龙世界"
    case fairytale = "童话王国"
    case city = "城市探索"
    case farm = "农场生活"
    case superhero = "超级英雄"
    case school = "校园故事"
    case family = "家庭温情"
    
    static var allThemes: [SDStoryTheme] {
        return SDStoryTheme.allCases
    }
}

/// 故事长度
enum SDStoryLength: String, Codable, CaseIterable {
    case short = "短篇"
    case medium = "中篇"
    case long = "长篇"
    
    var wordCount: ClosedRange<Int> {
        switch self {
        case .short:
            return 300...500
        case .medium:
            return 500...1000
        case .long:
            return 1000...2000
        }
    }
    
    static var allLengths: [SDStoryLength] {
        return SDStoryLength.allCases
    }
}

/// 故事模型
@Model
final class StoryModel {
    /// 唯一标识符
    @Attribute(.unique) var id: String
    
    /// 故事标题
    var title: String
    
    /// 故事内容
    var content: String
    
    /// 创建日期
    var createdDate: Date
    
    /// 故事主题
    var themeString: String
    
    /// 角色名称
    var characterName: String
    
    /// 故事长度类型
    var lengthTypeString: String
    
    /// 是否收藏
    var isFavorite: Bool
    
    /// 阅读次数
    var readCount: Int
    
    /// 关联的语音列表
    var speeches: [SpeechModel]?
    
    /// 故事主题（计算属性）
    var storyTheme: SDStoryTheme? {
        get {
            return SDStoryTheme(rawValue: themeString)
        }
        set {
            themeString = newValue?.rawValue ?? ""
        }
    }
    
    /// 故事长度类型（计算属性）
    var storyLengthType: SDStoryLength? {
        get {
            return SDStoryLength(rawValue: lengthTypeString)
        }
        set {
            lengthTypeString = newValue?.rawValue ?? ""
        }
    }
    
    /// 格式化的创建日期
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    /// 初始化方法
    init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        theme: SDStoryTheme,
        characterName: String,
        lengthType: SDStoryLength,
        createdDate: Date = Date(),
        isFavorite: Bool = false,
        readCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.themeString = theme.rawValue
        self.characterName = characterName
        self.lengthTypeString = lengthType.rawValue
        self.createdDate = createdDate
        self.isFavorite = isFavorite
        self.readCount = readCount
    }
    
    /// 增加阅读次数
    func incrementReadCount() {
        readCount += 1
    }
    
    /// 切换收藏状态
    func toggleFavorite() {
        isFavorite.toggle()
    }
}

/// 预览用的示例故事
extension StoryModel {
    static var preview: StoryModel {
        return StoryModel(
            id: UUID().uuidString,
            title: "小明的太空冒险",
            content: "从前，有一个叫小明的男孩非常喜欢看星星。有一天晚上，他正在院子里用望远镜观察夜空，突然看到一颗流星划过天际。小明许下了一个愿望：我希望能去太空旅行！\n\n就在这时，一道神秘的光芒笼罩了小明，他感到自己的身体变得轻飘飘的，慢慢地离开了地面。当他回过神来，发现自己已经置身于一艘宇宙飞船中！\n\n欢迎来到银河特快列车！一个友好的机器人向他打招呼，我是你的导游，可以带你去参观太阳系。\n\n小明兴奋极了，他跟着机器人参观了巨大的木星、美丽的土星环，甚至还在火星上留下了自己的脚印。在返回地球的路上，他们遇到了一场小行星雨。机器人迅速启动了飞船的防护罩，保护他们安全通过。\n\n当小明回到家中，发现只过去了一个小时。他把这次奇妙的太空之旅画成了一本画册，带到学校与同学们分享。从那以后，小明决定长大后要成为一名宇航员，探索更多宇宙的奥秘。",
            theme: .space,
            characterName: "小明",
            lengthType: .medium,
            createdDate: Date(),
            isFavorite: true,
            readCount: 3
        )
    }
} 