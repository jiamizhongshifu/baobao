import Foundation
import SwiftData

/// 缓存类型
enum CacheType: String, Codable {
    case story = "story"
    case audio = "audio"
    case image = "image"
}

/// 缓存记录模型
@Model
final class CacheRecord {
    /// 唯一标识符
    var id: String
    /// 缓存类型
    var type: String
    /// 关联ID（故事ID、音频ID等）
    var relatedId: String
    /// 缓存路径
    var path: String
    /// 文件大小（字节）
    var size: Int64
    /// 创建时间
    var createdAt: Date
    /// 最后访问时间
    var lastAccessedAt: Date
    /// 访问次数
    var accessCount: Int
    /// 过期时间
    var expiresAt: Date?
    /// 是否为预下载内容
    var isPredownloaded: Bool
    
    init(
        id: String = UUID().uuidString,
        type: CacheType,
        relatedId: String,
        path: String,
        size: Int64,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        accessCount: Int = 0,
        expiresAt: Date? = nil,
        isPredownloaded: Bool = false
    ) {
        self.id = id
        self.type = type.rawValue
        self.relatedId = relatedId
        self.path = path
        self.size = size
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.expiresAt = expiresAt
        self.isPredownloaded = isPredownloaded
    }
    
    /// 更新访问记录
    func updateAccess() {
        self.lastAccessedAt = Date()
        self.accessCount += 1
    }
    
    /// 检查缓存是否过期
    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return Date() > expiresAt
        }
        return false
    }
} 