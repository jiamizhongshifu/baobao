import Foundation

/// 故事模型
struct Story: Codable, Identifiable {
    /// 故事ID
    let id: String
    
    /// 故事标题
    let title: String
    
    /// 故事内容
    let content: String
    
    /// 故事主题
    let theme: String
    
    /// 宝宝名字
    let childName: String
    
    /// 创建时间
    let createdAt: Date
    
    /// 音频文件URL
    var audioURL: String?
    
    /// 音频时长
    var audioDuration: TimeInterval?
    
    /// 上次播放位置
    var lastPlayPosition: TimeInterval?
    
    /// 初始化新故事
    /// - Parameters:
    ///   - id: 故事ID，默认自动生成
    ///   - title: 故事标题
    ///   - content: 故事内容
    ///   - theme: 故事主题
    ///   - childName: 宝宝名字
    ///   - createdAt: 创建时间，默认为当前时间
    ///   - audioURL: 音频文件URL，可选
    ///   - audioDuration: 音频时长，可选
    ///   - lastPlayPosition: 上次播放位置，可选
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         theme: String,
         childName: String,
         createdAt: Date = Date(),
         audioURL: String? = nil,
         audioDuration: TimeInterval? = nil,
         lastPlayPosition: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.childName = childName
        self.createdAt = createdAt
        self.audioURL = audioURL
        self.audioDuration = audioDuration
        self.lastPlayPosition = lastPlayPosition
    }
    
    /// 更新故事
    /// - Parameters:
    ///   - audioURL: 新的音频URL
    ///   - audioDuration: 新的音频时长
    /// - Returns: 更新后的故事对象
    func withAudio(url: String, duration: TimeInterval) -> Story {
        var updatedStory = self
        updatedStory.audioURL = url
        updatedStory.audioDuration = duration
        return updatedStory
    }
    
    /// 更新播放位置
    /// - Parameter position: 新的播放位置
    /// - Returns: 更新后的故事对象
    func withPlayPosition(_ position: TimeInterval) -> Story {
        var updatedStory = self
        updatedStory.lastPlayPosition = position
        return updatedStory
    }
} 