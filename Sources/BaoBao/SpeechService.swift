import Foundation
import AVFoundation
import os.log

class SpeechService {
    static let shared = SpeechService()
    private let logger = Logger(subsystem: "com.example.baobao", category: "SpeechService")
    
    private var audioPlayer: AVAudioPlayer?
    private var synthesizer: AVSpeechSynthesizer
    private var currentSynthesisTask: AVSpeechSynthesisTask?
    private var playbackTimer: Timer?
    private var currentPlaybackTime: TimeInterval = 0
    private var playbackUpdateHandler: ((TimeInterval) -> Void)?
    
    // 音频设置
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 2,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    private init() {
        synthesizer = AVSpeechSynthesizer()
        logger.info("🎙️ SpeechService初始化")
    }
    
    // MARK: - 语音合成
    
    func synthesize(text: String, voiceType: String, completion: @escaping (Result<URL, Error>) -> Void) {
        logger.info("🗣️ 开始语音合成: \(text.prefix(50))...")
        
        // 创建语音合成请求
        let utterance = AVSpeechUtterance(string: text)
        
        // 设置语音类型和参数
        configureUtterance(utterance, voiceType: voiceType)
        
        // 创建持久化存储URL
        let fileName = "speech_\(UUID().uuidString).m4a"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsURL.appendingPathComponent(fileName)
        
        // 设置音频会话
        do {
            try configureAudioSession()
        } catch {
            logger.error("❌ 设置音频会话失败: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // 开始合成
        synthesizer.write(utterance) { [weak self] buffer in
            guard let self = self else { return }
            
            do {
                // 写入音频数据
                try buffer.write(to: audioURL)
                
                self.logger.info("✅ 语音合成完成，保存到: \(audioURL.path)")
                completion(.success(audioURL))
            } catch {
                self.logger.error("❌ 保存音频文件失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 音频播放
    
    func play(url: URL, from position: TimeInterval = 0, progressHandler: ((TimeInterval) -> Void)? = nil, completion: @escaping (Error?) -> Void) {
        logger.info("▶️ 开始播放音频: \(url.lastPathComponent)")
        
        do {
            try configureAudioSession()
            
            // 创建音频播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.currentTime = position
            audioPlayer?.prepareToPlay()
            
            // 设置进度更新处理器
            self.playbackUpdateHandler = progressHandler
            
            // 开始播放
            if audioPlayer?.play() == true {
                startPlaybackTimer()
                logger.info("✅ 音频开始播放，从位置: \(position)秒")
                completion(nil)
            } else {
                let error = NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "播放失败"])
                logger.error("❌ 音频播放失败")
                completion(error)
            }
        } catch {
            logger.error("❌ 创建音频播放器失败: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    func stop() {
        logger.info("⏹️ 停止播放音频")
        stopPlaybackTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        currentPlaybackTime = 0
    }
    
    func pause() {
        logger.info("⏸️ 暂停播放音频")
        stopPlaybackTimer()
        audioPlayer?.pause()
    }
    
    func resume() {
        logger.info("▶️ 恢复播放音频")
        if audioPlayer?.play() == true {
            startPlaybackTimer()
        }
    }
    
    func getCurrentTime() -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    func getDuration() -> TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    // MARK: - 缓存管理
    
    func clearCache() {
        logger.info("🧹 清理音频缓存")
        
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        
        do {
            // 清理临时目录
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory,
                                                             includingPropertiesForKeys: nil,
                                                             options: [])
            
            for file in tempFiles where file.lastPathComponent.hasPrefix("speech_") {
                try fileManager.removeItem(at: file)
            }
            
            // 清理持久化存储中的过期文件（超过7天）
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let documentFiles = try fileManager.contentsOfDirectory(at: documentsURL,
                                                                 includingPropertiesForKeys: [.creationDateKey],
                                                                 options: [])
            
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            for file in documentFiles where file.lastPathComponent.hasPrefix("speech_") {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < sevenDaysAgo {
                    try fileManager.removeItem(at: file)
                }
            }
            
            logger.info("✅ 缓存清理完成")
        } catch {
            logger.error("❌ 清理缓存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 私有辅助方法
    
    private func configureUtterance(_ utterance: AVSpeechUtterance, voiceType: String) {
        // 设置语音类型
        switch voiceType {
        case "萍萍阿姨":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.1
        case "大卫叔叔":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.45
            utterance.pitchMultiplier = 0.9
        default:
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
        }
        
        utterance.volume = 1.0
    }
    
    private func configureAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer,
                  player.isPlaying else {
                return
            }
            
            self.currentPlaybackTime = player.currentTime
            self.playbackUpdateHandler?(self.currentPlaybackTime)
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension SpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("🏁 音频播放结束，成功: \(flag)")
        stopPlaybackTimer()
        audioPlayer = nil
        currentPlaybackTime = 0
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            logger.error("❌ 音频解码错误: \(error.localizedDescription)")
        }
        stopPlaybackTimer()
        audioPlayer = nil
        currentPlaybackTime = 0
    }
} 