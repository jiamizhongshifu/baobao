import Foundation
import os.log
import AVFoundation

// MARK: - 语音类型
enum VoiceType: String, Codable, CaseIterable {
    case male = "男声"
    case female = "女声"
    case child = "童声"
    case robot = "机器人"
    
    var azureVoiceName: String {
        switch self {
        case .male:
            return "zh-CN-YunxiNeural"
        case .female:
            return "zh-CN-XiaoxiaoNeural"
        case .child:
            return "zh-CN-XiaoyiNeural" // 童声
        case .robot:
            return "zh-CN-YunyangNeural" // 机器人声音
        }
    }
}

// MARK: - 语音服务错误
enum SpeechServiceError: Error {
    case synthesizeFailed
    case invalidParameters
    case audioPlayerError
    case fileError
    case networkError(Error)
    case apiError(Int, String)
    case rateLimited
    case timeout
    case parseError
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .synthesizeFailed:
            return "语音合成失败"
        case .invalidParameters:
            return "参数无效"
        case .audioPlayerError:
            return "音频播放器错误"
        case .fileError:
            return "文件操作错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误(\(code)): \(message)"
        case .rateLimited:
            return "请求频率超限，请稍后再试"
        case .timeout:
            return "请求超时，请检查网络连接"
        case .parseError:
            return "解析响应数据失败"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - 语音服务协议
protocol SpeechServiceProtocol {
    // 合成语音
    func synthesizeSpeech(
        text: String,
        voiceType: VoiceType,
        completion: @escaping (Result<URL, Error>) -> Void
    )
    
    // 播放音频
    func playAudio(fileURL: URL, completion: @escaping (Bool) -> Void)
    
    // 停止音频
    func stopAudio()
}

// 平台特定的可选方法扩展
extension SpeechServiceProtocol {
    // iOS平台特定的音频会话设置（默认空实现）
    func setupAudioSession() throws {
        // 默认空实现
    }
    
    // iOS平台特定的音频会话关闭（默认空实现）
    func deactivateAudioSession() throws {
        // 默认空实现
    }
}

// MARK: - 语音服务工厂
class SpeechServiceFactory {
    static func createSpeechService() -> SpeechServiceProtocol {
        #if os(iOS)
        return iOSSpeechService.shared
        #elseif os(macOS)
        return MacOSSpeechService.shared
        #else
        fatalError("不支持的平台")
        #endif
    }
} 