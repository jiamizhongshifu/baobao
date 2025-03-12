import Foundation

/// 故事主题
public enum StoryTheme: String, Codable, CaseIterable {
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
    
    static var allThemes: [StoryTheme] {
        return StoryTheme.allCases
    }
    
    var icon: String {
        switch self {
        case .space:
            return "rocket"
        case .ocean:
            return "fish"
        case .forest:
            return "leaf"
        case .dinosaur:
            return "fossil"
        case .fairytale:
            return "wand.and.stars"
        case .city:
            return "building.2"
        case .farm:
            return "tortoise"
        case .superhero:
            return "bolt.fill"
        case .school:
            return "book.fill"
        case .family:
            return "house.fill"
        }
    }
}

/// 故事长度
public enum StoryLength: String, Codable, CaseIterable {
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
    
    static var allLengths: [StoryLength] {
        return StoryLength.allCases
    }
} 