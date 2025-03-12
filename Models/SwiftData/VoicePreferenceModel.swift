import Foundation
import SwiftData

/// 语音偏好设置模型
@Model
final class VoicePreferenceModel {
    // MARK: - 属性
    
    /// 唯一标识符
    var id: String
    
    /// 首选语音类型
    var preferredVoiceType: String
    
    /// 语速（0.5-2.0，1.0为正常速度）
    var speechRate: Double
    
    /// 音量（0.0-1.0）
    var volume: Double
    
    /// 是否使用本地TTS
    var useLocalTTS: Bool
    
    /// 创建时间
    var createdAt: Date
    
    /// 最后修改时间
    var updatedAt: Date
    
    /// 关联的孩子
    @Relationship(deleteRule: .cascade, inverse: \ChildModel.voicePreference)
    var child: ChildModel?
    
    // MARK: - 初始化方法
    
    init(
        id: String = UUID().uuidString,
        preferredVoiceType: String,
        speechRate: Double = 1.0,
        volume: Double = 1.0,
        useLocalTTS: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        child: ChildModel? = nil
    ) {
        self.id = id
        self.preferredVoiceType = preferredVoiceType
        self.speechRate = speechRate
        self.volume = volume
        self.useLocalTTS = useLocalTTS
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.child = child
    }
    
    /// 创建默认语音偏好设置
    static func createDefault(for child: ChildModel? = nil) -> VoicePreferenceModel {
        return VoicePreferenceModel(
            preferredVoiceType: "萍萍阿姨", // 默认使用萍萍阿姨的声音
            child: child
        )
    }
} 