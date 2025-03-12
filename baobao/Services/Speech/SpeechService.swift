import Foundation
import os.log
import AVFoundation

// 创建专用的日志记录器
fileprivate let logger = Logger(subsystem: "com.baobao.app", category: "speech-service")

// MARK: - 语音服务
/// 这个类仅作为兼容层，实际实现由平台特定的类处理
class SpeechService {
    /// 共享实例 - 自动选择对应平台的实现
    static let shared: SpeechServiceProtocol = {
        logger.info("初始化SpeechService门面类，选择平台实现")
        return SpeechServiceFactory.createSpeechService()
    }()
    
    private init() {
        // 私有初始化方法，防止直接实例化
    }
}
