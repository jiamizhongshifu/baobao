import Foundation
import SwiftData

/// 缓存类型枚举
enum CacheType: String, Codable {
    case story = "故事"
    case speech = "语音"
    case image = "图像"
    
    // 获取所有缓存类型
    static var allTypes: [CacheType] {
        return [.story, .speech, .image]
    }
}

/// 缓存优先级枚举
enum CachePriority: Int, Codable {
    case low = 0
    case medium = 1
    case high = 2
    
    // 获取所有优先级
    static var allPriorities: [CachePriority] {
        return [.low, .medium, .high]
    }
}

/// 缓存记录模型
@Model
final class CacheRecordModel {
    // 基本属性
    @Attribute(.unique) var id: String
    var cacheTypeString: String // 存储CacheType的rawValue
    var filePath: String
    var createdDate: Date
    var lastAccessedDate: Date
    var fileSize: Int64 // 文件大小（字节）
    var priorityValue: Int // 存储CachePriority的rawValue
    var relatedItemId: String? // 关联的故事或语音ID
    
    // 计算属性
    var cacheType: CacheType? {
        get { return CacheType(rawValue: cacheTypeString) }
        set { if let newValue = newValue { cacheTypeString = newValue.rawValue } }
    }
    
    var priority: CachePriority {
        get { return CachePriority(rawValue: priorityValue) ?? .medium }
        set { priorityValue = newValue.rawValue }
    }
    
    // 初始化方法
    init(
        id: String = UUID().uuidString,
        cacheType: CacheType,
        filePath: String,
        createdDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        fileSize: Int64 = 0,
        priority: CachePriority = .medium,
        relatedItemId: String? = nil
    ) {
        self.id = id
        self.cacheTypeString = cacheType.rawValue
        self.filePath = filePath
        self.createdDate = createdDate
        self.lastAccessedDate = lastAccessedDate
        self.fileSize = fileSize
        self.priorityValue = priority.rawValue
        self.relatedItemId = relatedItemId
    }
}

// MARK: - 辅助方法
extension CacheRecordModel {
    // 更新最后访问日期
    func updateLastAccessedDate() {
        lastAccessedDate = Date()
    }
    
    // 更新文件大小
    func updateFileSize(_ size: Int64) {
        fileSize = size
    }
    
    // 更新优先级
    func updatePriority(_ newPriority: CachePriority) {
        priority = newPriority
    }
    
    // 格式化文件大小
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }
    
    // 格式化创建日期
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    // 格式化最后访问日期
    var formattedLastAccessedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastAccessedDate)
    }
    
    // 获取缓存年龄（天数）
    var ageInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: createdDate, to: Date())
        return components.day ?? 0
    }
    
    // 获取上次访问距今时间（天数）
    var daysSinceLastAccess: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastAccessedDate, to: Date())
        return components.day ?? 0
    }
}

// MARK: - 预览数据
extension CacheRecordModel {
    static var preview: CacheRecordModel {
        CacheRecordModel(
            cacheType: .story,
            filePath: "stories/story_123.json",
            fileSize: 1024 * 10, // 10KB
            priority: .medium,
            relatedItemId: "story_123"
        )
    }
} 