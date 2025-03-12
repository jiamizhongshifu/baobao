import Foundation
import SwiftData

/// 故事模型
@Model
public class Story: Codable {
    /// 故事ID
    public var id: String
    
    /// 故事标题
    var title: String
    
    /// 故事内容
    var content: String
    
    /// 故事主题
    var theme: String
    
    /// 故事长度类型
    var lengthType: String
    
    /// 故事创建时间
    var createdAt: Date
    
    /// 是否收藏
    var isFavorite: Bool
    
    /// 阅读次数
    var readCount: Int
    
    /// 最后阅读时间
    var lastReadAt: Date?
    
    /// 故事封面图片URL
    var coverImageURL: String?
    
    /// 故事音频URL
    var audioURL: String?
    
    /// 初始化方法
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         theme: StoryTheme,
         lengthType: StoryLength,
         createdAt: Date = Date(),
         isFavorite: Bool = false,
         readCount: Int = 0,
         lastReadAt: Date? = nil,
         coverImageURL: String? = nil,
         audioURL: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme.rawValue
        self.lengthType = lengthType.rawValue
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.readCount = readCount
        self.lastReadAt = lastReadAt
        self.coverImageURL = coverImageURL
        self.audioURL = audioURL
    }
    
    // MARK: - Codable
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        theme = try container.decode(String.self, forKey: .theme)
        lengthType = try container.decode(String.self, forKey: .lengthType)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        readCount = try container.decode(Int.self, forKey: .readCount)
        lastReadAt = try container.decodeIfPresent(Date.self, forKey: .lastReadAt)
        coverImageURL = try container.decodeIfPresent(String.self, forKey: .coverImageURL)
        audioURL = try container.decodeIfPresent(String.self, forKey: .audioURL)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(theme, forKey: .theme)
        try container.encode(lengthType, forKey: .lengthType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(readCount, forKey: .readCount)
        try container.encodeIfPresent(lastReadAt, forKey: .lastReadAt)
        try container.encodeIfPresent(coverImageURL, forKey: .coverImageURL)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, content, theme, lengthType, createdAt, isFavorite, readCount, lastReadAt, coverImageURL, audioURL
    }
    
    /// 获取故事主题枚举
    var themeEnum: StoryTheme? {
        return StoryTheme(rawValue: theme)
    }
    
    /// 获取故事长度枚举
    var lengthEnum: StoryLength? {
        return StoryLength(rawValue: lengthType)
    }
    
    /// 增加阅读次数
    func incrementReadCount() {
        readCount += 1
        lastReadAt = Date()
    }
    
    /// 切换收藏状态
    func toggleFavorite() {
        isFavorite.toggle()
    }
    
    /// 获取故事摘要（前100个字符）
    var summary: String {
        if content.count <= 100 {
            return content
        }
        return String(content.prefix(100)) + "..."
    }
    
    /// 获取格式化的创建时间
    var formattedCreatedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }
}
