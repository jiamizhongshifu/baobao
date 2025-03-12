import Foundation

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
struct Story: Codable {
    let id: String
    let title: String
    let content: String
    let theme: String
    let childName: String
    let childAge: Int
    let audioURL: String?
    let imageURL: String?
    let createdAt: Date
    let lastPlayedAt: Date?
    
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         theme: String,
         childName: String,
         childAge: Int,
         audioURL: String? = nil,
         imageURL: String? = nil,
         createdAt: Date = Date(),
         lastPlayedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.childName = childName
        self.childAge = childAge
        self.audioURL = audioURL
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.lastPlayedAt = lastPlayedAt
    }
} 