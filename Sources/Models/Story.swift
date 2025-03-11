import Foundation

struct Story: Codable {
    let id: String
    let title: String
    let content: String
    let theme: String
    let childName: String
    let createdAt: Date
    var audioURL: String?
    var audioDuration: TimeInterval?
    var lastPlayPosition: TimeInterval?
    var isFavorite: Bool
    
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         theme: String,
         childName: String,
         createdAt: Date = Date(),
         audioURL: String? = nil,
         audioDuration: TimeInterval? = nil,
         lastPlayPosition: TimeInterval? = nil,
         isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.childName = childName
        self.createdAt = createdAt
        self.audioURL = audioURL
        self.audioDuration = audioDuration
        self.lastPlayPosition = lastPlayPosition
        self.isFavorite = isFavorite
    }
    
    // 从字典创建Story对象
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let title = dictionary["title"] as? String,
              let content = dictionary["content"] as? String,
              let theme = dictionary["theme"] as? String,
              let childName = dictionary["childName"] as? String,
              let createdAtString = dictionary["createdAt"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.childName = childName
        self.createdAt = createdAt
        self.audioURL = dictionary["audioURL"] as? String
        self.audioDuration = dictionary["audioDuration"] as? TimeInterval
        self.lastPlayPosition = dictionary["lastPlayPosition"] as? TimeInterval
        self.isFavorite = dictionary["isFavorite"] as? Bool ?? false
    }
    
    // 转换为字典
    func toDictionary() -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "content": content,
            "theme": theme,
            "childName": childName,
            "createdAt": dateFormatter.string(from: createdAt),
            "isFavorite": isFavorite
        ]
        
        if let audioURL = audioURL {
            dict["audioURL"] = audioURL
        }
        if let audioDuration = audioDuration {
            dict["audioDuration"] = audioDuration
        }
        if let lastPlayPosition = lastPlayPosition {
            dict["lastPlayPosition"] = lastPlayPosition
        }
        
        return dict
    }
    
    // 更新音频信息
    func updateAudioInfo(url: String?, duration: TimeInterval?) -> Story {
        return Story(
            id: self.id,
            title: self.title,
            content: self.content,
            theme: self.theme,
            childName: self.childName,
            createdAt: self.createdAt,
            audioURL: url,
            audioDuration: duration,
            lastPlayPosition: nil,
            isFavorite: self.isFavorite
        )
    }
    
    // 更新播放位置
    func updatePlayPosition(_ position: TimeInterval) -> Story {
        return Story(
            id: self.id,
            title: self.title,
            content: self.content,
            theme: self.theme,
            childName: self.childName,
            createdAt: self.createdAt,
            audioURL: self.audioURL,
            audioDuration: self.audioDuration,
            lastPlayPosition: position,
            isFavorite: self.isFavorite
        )
    }
    
    // 更新收藏状态
    func updateFavoriteStatus(_ isFavorite: Bool) -> Story {
        return Story(
            id: self.id,
            title: self.title,
            content: self.content,
            theme: self.theme,
            childName: self.childName,
            createdAt: self.createdAt,
            audioURL: self.audioURL,
            audioDuration: self.audioDuration,
            lastPlayPosition: self.lastPlayPosition,
            isFavorite: isFavorite
        )
    }
} 