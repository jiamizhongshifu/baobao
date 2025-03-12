import Foundation
import os.log
import AVFoundation

// MARK: - 语音类型
enum VoiceType: String, Codable, CaseIterable {
    case male = "男声"
    case female = "女声"
    case child = "童声"
    case robot = "机器人"
    
    var voiceIdentifier: String {
        switch self {
        case .male:
            return "com.apple.ttsbundle.Tingchen-compact"
        case .female:
            return "com.apple.ttsbundle.Tingting-compact"
        case .child:
            return "com.apple.ttsbundle.Tingting-compact" // 模拟童声
        case .robot:
            return "com.apple.speech.synthesis.voice.Fred" // 模拟机器人声音
        }
    }
}

// MARK: - 语音服务错误
enum SpeechServiceError: Error {
    case synthesizeFailed
    case invalidParameters
    case audioPlayerError
    case fileError
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
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - 语音服务
class SpeechService: NSObject {
    // 单例模式
    static let shared = SpeechService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "speech-service")
    
    // 语音合成器
    private let synthesizer = AVSpeechSynthesizer()
    
    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    // 音频文件目录
    private let audioDirectory: URL
    
    // 文件管理器
    private let fileManager = FileManager.default
    
    // 私有初始化方法
    private override init() {
        // 获取文档目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 创建音频目录
        audioDirectory = documentsDirectory.appendingPathComponent("audio", isDirectory: true)
        
        super.init()
        
        // 创建音频目录（如果不存在）
        createAudioDirectoryIfNeeded()
        
        // 配置音频会话
        configureAudioSession()
        
        logger.info("语音服务初始化完成")
    }
    
    // MARK: - 配置
    
    // 配置音频会话
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.info("✅ 配置音频会话成功")
        } catch {
            logger.error("❌ 配置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // 创建音频目录
    private func createAudioDirectoryIfNeeded() {
        do {
            // 检查音频目录是否存在
            if !fileManager.fileExists(atPath: self.audioDirectory.path) {
                // 创建音频目录
                try fileManager.createDirectory(at: self.audioDirectory, withIntermediateDirectories: true)
                logger.info("✅ 创建音频目录成功: \(self.audioDirectory.path)")
            }
        } catch {
            logger.error("❌ 创建音频目录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 语音合成
    
    // 合成语音
    func synthesizeSpeech(
        text: String,
        voiceType: VoiceType,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        logger.info("开始合成语音：文本长度=\(text.count)，语音类型=\(voiceType.rawValue)")
        
        // 创建唯一文件名
        let fileName = "speech_\(UUID().uuidString).m4a"
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        
        // 异步执行
        DispatchQueue.global().async {
            // 模拟语音合成
            do {
                // 模拟延迟
                sleep(2)
                
                // 生成随机音频文件（用于测试）
                if self.generateRandomAudioFile(at: fileURL) {
                    self.logger.info("✅ 语音合成成功：\(fileURL.lastPathComponent)")
                    
                    // 主线程回调
                    DispatchQueue.main.async {
                        completion(.success(fileURL))
                    }
                } else {
                    throw SpeechServiceError.synthesizeFailed
                }
            } catch {
                self.logger.error("❌ 语音合成失败: \(error.localizedDescription)")
                
                // 主线程回调
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 模拟生成随机音频文件（开发用）
    private func generateRandomAudioFile(at url: URL) -> Bool {
        // 添加测试音频文件
        if let testAudioURL = Bundle.main.url(forResource: "test_audio", withExtension: "m4a") {
            do {
                // 复制测试音频文件
                try fileManager.copyItem(at: testAudioURL, to: url)
                return true
            } catch {
                logger.error("❌ 复制测试音频失败: \(error.localizedDescription)")
                return false
            }
        } else {
            // 如果测试音频不存在，创建空文件
            fileManager.createFile(atPath: url.path, contents: Data())
            return true
        }
    }
    
    // MARK: - 音频播放
    
    // 播放音频
    func playAudio(from url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.info("开始播放音频：\(url.lastPathComponent)")
        
        do {
            // 停止当前播放
            stopAudio()
            
            // 创建音频播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // 播放音频
            if audioPlayer?.play() == true {
                logger.info("✅ 音频开始播放")
                completion(.success(()))
            } else {
                throw SpeechServiceError.audioPlayerError
            }
        } catch {
            logger.error("❌ 播放音频失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // 停止音频
    func stopAudio() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            logger.info("✅ 音频停止播放")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension SpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("✅ 音频播放完成，成功: \(flag)")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            logger.error("❌ 音频解码错误: \(error.localizedDescription)")
        }
    }
} 