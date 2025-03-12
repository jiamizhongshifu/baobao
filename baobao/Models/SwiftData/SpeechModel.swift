import Foundation
import SwiftData

/// 语音类型枚举
enum SDVoiceType: String, Codable {
    case xiaoMing = "小明哥哥"
    case xiaoHong = "小红姐姐"
    case pingPing = "萍萍阿姨"
    case laoWang = "老王爷爷"
    case robot = "机器人"
    
    // 获取所有语音类型
    static var allVoiceTypes: [SDVoiceType] {
        return [.xiaoMing, .xiaoHong, .pingPing, .laoWang, .robot]
    }
    
    // 添加CaseIterable支持
    static var allCases: [SDVoiceType] {
        return allVoiceTypes
    }
}

/// 语音模型
@Model
final class SpeechModel {
    // 基本属性
    @Attribute(.unique) var id: String
    var fileURL: String
    var voiceTypeString: String // 存储SDVoiceType的rawValue
    var createdDate: Date
    var fileSize: Int64 // 文件大小（字节）
    var duration: Double // 持续时间（秒）
    var isLocalTTS: Bool // 是否为本地TTS生成
    
    // 关系 - 移除@Relationship属性，改为普通属性
    var story: StoryModel?
    
    // 计算属性
    var voiceType: SDVoiceType? {
        get { return SDVoiceType(rawValue: voiceTypeString) }
        set { if let newValue = newValue { voiceTypeString = newValue.rawValue } }
    }
    
    // 初始化方法
    init(
        id: String = UUID().uuidString,
        fileURL: String,
        voiceType: SDVoiceType,
        createdDate: Date = Date(),
        fileSize: Int64 = 0,
        duration: Double = 0,
        isLocalTTS: Bool = false,
        story: StoryModel? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.voiceTypeString = voiceType.rawValue
        self.createdDate = createdDate
        self.fileSize = fileSize
        self.duration = duration
        self.isLocalTTS = isLocalTTS
        self.story = story
    }
}

// MARK: - 辅助方法
extension SpeechModel {
    // 格式化文件大小
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }
    
    // 格式化持续时间
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 格式化创建日期
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    // 获取本地文件URL
    var localURL: URL? {
        return URL(string: fileURL)
    }
}

// MARK: - 预览数据
extension SpeechModel {
    static var preview: SpeechModel {
        SpeechModel(
            fileURL: "file:///path/to/speech.mp3",
            voiceType: .xiaoMing,
            fileSize: 1024 * 1024, // 1MB
            duration: 120 // 2分钟
        )
    }
} 