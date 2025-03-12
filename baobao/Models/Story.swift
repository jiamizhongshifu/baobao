import Foundation
import SwiftData

// MARK: - 故事主题
enum StoryTheme: String, Codable, CaseIterable {
    case space = "太空冒险"
    case fairy = "童话故事"
    case animal = "动物世界"
    case dinosaur = "恐龙时代"
    case ocean = "海洋探险"
    case fantasy = "奇幻冒险"
    
    var icon: String {
        switch self {
        case .space:
            return "rocket"
        case .fairy:
            return "wand.and.stars"
        case .animal:
            return "tortoise"
        case .dinosaur:
            return "fossil"
        case .ocean:
            return "fish"
        case .fantasy:
            return "wand.and.rays"
        }
    }
}

// MARK: - 故事长度
enum StoryLength: String, Codable, CaseIterable {
    case short = "短篇"
    case medium = "中篇"
    case long = "长篇"
    
    var wordCount: ClosedRange<Int> {
        switch self {
        case .short:
            return 300...500
        case .medium:
            return 500...800
        case .long:
            return 800...1200
        }
    }
}

// MARK: - 故事模型
@Model
final class Story {
    /// 唯一标识符
    var id: String
    /// 故事标题
    var title: String
    /// 故事内容
    var content: String
    /// 故事主题
    var theme: String
    /// 故事长度
    var length: String
    /// 关联的孩子ID
    var childId: String
    /// 关联的孩子名称（冗余存储，方便查询）
    var childName: String
    /// 孩子年龄（冗余存储，方便生成适龄内容）
    var childAge: Int
    /// 音频文件URL
    var audioURL: String?
    /// 故事配图URL
    var imageURL: String?
    /// 创建时间
    var createdAt: Date
    /// 最后播放时间
    var lastPlayedAt: Date?
    /// 是否收藏
    var isFavorite: Bool
    /// 播放次数
    var playCount: Int
    /// 使用的语音类型
    var voiceType: String?
    /// 是否已缓存
    var isCached: Bool
    /// 缓存路径
    var cachePath: String?
    
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         theme: String,
         length: String = StoryLength.medium.rawValue,
         childId: String,
         childName: String,
         childAge: Int,
         audioURL: String? = nil,
         imageURL: String? = nil,
         createdAt: Date = Date(),
         lastPlayedAt: Date? = nil,
         isFavorite: Bool = false,
         playCount: Int = 0,
         voiceType: String? = nil,
         isCached: Bool = false,
         cachePath: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.length = length
        self.childId = childId
        self.childName = childName
        self.childAge = childAge
        self.audioURL = audioURL
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.lastPlayedAt = lastPlayedAt
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.voiceType = voiceType
        self.isCached = isCached
        self.cachePath = cachePath
    }
} 