import Foundation
import os.log
import AVFoundation
import UIKit

// MARK: - iOS 特定的语音服务实现
class iOSSpeechService: NSObject, SpeechServiceProtocol, AVAudioPlayerDelegate {
    // 单例模式
    static let shared = iOSSpeechService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "ios-speech-service")
    
    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    // Azure语音服务配置
    private let azureRegion = "eastasia"
    private var azureKey: String {
        // 从配置或环境变量获取API密钥
        return ProcessInfo.processInfo.environment["AZURE_SPEECH_KEY"] ?? ""
    }
    
    // 缓存配置
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7天
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    
    // 重试配置
    private let maxRetries = 3
    private let initialRetryDelay: TimeInterval = 2.0
    
    // 私有初始化方法
    private override init() {
        // 创建缓存目录
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("speech_cache")
        
        // 先完成初始化
        super.init()
        
        // 确保缓存目录存在
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            logger.info("✅ 语音缓存目录创建成功: \(self.cacheDirectory.path)")
        } catch {
            logger.error("❌ 创建语音缓存目录失败: \(error.localizedDescription)")
        }
        
        // 清理过期缓存
        cleanExpiredCache()
        
        logger.info("✅ iOS语音服务初始化完成")
    }
    
    // MARK: - 语音合成
    
    /// 合成语音
    /// - Parameters:
    ///   - text: 要合成的文本
    ///   - voiceType: 语音类型
    ///   - completion: 完成回调
    func synthesizeSpeech(
        text: String,
        voiceType: VoiceType,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 验证参数
        guard !text.isEmpty else {
            logger.error("❌ 合成语音失败: 文本为空")
            completion(.failure(SpeechServiceError.invalidParameters))
            return
        }
        
        // 计算缓存键
        let cacheKey = generateCacheKey(text: text, voiceType: voiceType)
        let cacheFileURL = cacheDirectory.appendingPathComponent("\(cacheKey).mp3")
        
        // 检查缓存
        if FileManager.default.fileExists(atPath: cacheFileURL.path) {
            logger.info("✅ 使用缓存的语音文件: \(cacheFileURL.path)")
            completion(.success(cacheFileURL))
            return
        }
        
        // 使用Azure语音服务
        if !azureKey.isEmpty {
            synthesizeWithAzure(text: text, voiceType: voiceType, cacheFileURL: cacheFileURL, retryCount: 0, completion: completion)
            return
        }
        
        // 使用本地语音合成（备用方案）
        synthesizeWithLocalTTS(text: text, voiceType: voiceType, cacheFileURL: cacheFileURL, completion: completion)
    }
    
    /// 使用Azure语音服务合成语音
    private func synthesizeWithAzure(
        text: String,
        voiceType: VoiceType,
        cacheFileURL: URL,
        retryCount: Int,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 检查API密钥
        guard !azureKey.isEmpty else {
            logger.error("❌ 未配置Azure语音服务密钥")
            // 回退到本地TTS
            synthesizeWithLocalTTS(text: text, voiceType: voiceType, cacheFileURL: cacheFileURL, completion: completion)
            return
        }
        
        // 创建URL请求
        guard let url = URL(string: "https://\(azureRegion).tts.speech.microsoft.com/cognitiveservices/v1") else {
            logger.error("❌ 无效的Azure语音服务URL")
            completion(.failure(SpeechServiceError.invalidParameters))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30 // 30秒超时
        
        // 设置请求头
        request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.addValue(azureKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        
        // 构建SSML
        let ssml = buildSSML(text: text, voiceName: voiceType.azureVoiceName)
        request.httpBody = ssml.data(using: .utf8)
        
        // 创建数据任务
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 处理网络错误
            if let error = error {
                self.logger.error("❌ 网络错误: \(error.localizedDescription)")
                
                // 检查是否需要重试
                if retryCount < self.maxRetries {
                    // 计算退避延迟
                    let delay = self.initialRetryDelay * pow(2.0, Double(retryCount))
                    self.logger.info("⏱️ 重试请求 (\(retryCount + 1)/\(self.maxRetries))，延迟 \(delay) 秒")
                    
                    // 延迟后重试
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.synthesizeWithAzure(
                            text: text,
                            voiceType: voiceType,
                            cacheFileURL: cacheFileURL,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                
                // 重试失败，回退到本地TTS
                self.logger.info("⚠️ Azure语音服务请求失败，回退到本地TTS")
                self.synthesizeWithLocalTTS(text: text, voiceType: voiceType, cacheFileURL: cacheFileURL, completion: completion)
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("❌ 无效的HTTP响应")
                completion(.failure(SpeechServiceError.unknown))
                return
            }
            
            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200:
                // 成功响应
                guard let audioData = data, !audioData.isEmpty else {
                    self.logger.error("❌ 响应数据为空")
                    completion(.failure(SpeechServiceError.synthesizeFailed))
                    return
                }
                
                // 保存到缓存
                do {
                    try audioData.write(to: cacheFileURL)
                    self.logger.info("✅ 语音合成成功，已缓存: \(cacheFileURL.path)")
                    completion(.success(cacheFileURL))
                } catch {
                    self.logger.error("❌ 保存音频文件失败: \(error.localizedDescription)")
                    completion(.failure(SpeechServiceError.fileError))
                }
                
            case 401:
                self.logger.error("❌ Azure语音服务未授权 (401)")
                completion(.failure(SpeechServiceError.apiError(401, "API密钥无效")))
                
            case 429:
                self.logger.error("❌ Azure语音服务请求频率限制 (429)")
                
                // 检查是否需要重试
                if retryCount < self.maxRetries {
                    // 获取重试延迟时间（从响应头或使用默认值）
                    var retryAfter: TimeInterval = 5.0
                    if let retryAfterHeader = httpResponse.allHeaderFields["Retry-After"] as? String,
                       let retryAfterValue = Double(retryAfterHeader) {
                        retryAfter = retryAfterValue
                    }
                    
                    self.logger.info("⏱️ 请求频率限制，\(retryAfter)秒后重试 (\(retryCount + 1)/\(self.maxRetries))")
                    
                    // 延迟后重试
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryAfter) {
                        self.synthesizeWithAzure(
                            text: text,
                            voiceType: voiceType,
                            cacheFileURL: cacheFileURL,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                
                // 重试失败，回退到本地TTS
                self.logger.info("⚠️ Azure语音服务请求频率限制，回退到本地TTS")
                self.synthesizeWithLocalTTS(text: text, voiceType: voiceType, cacheFileURL: cacheFileURL, completion: completion)
                
            default:
                // 其他错误
                var message = "未知错误"
                if let errorData = data, let errorMessage = String(data: errorData, encoding: .utf8) {
                    message = errorMessage
                }
                
                self.logger.error("❌ Azure语音服务错误 (\(httpResponse.statusCode)): \(message)")
                
                // 回退到本地TTS
                self.logger.info("⚠️ Azure语音服务错误，回退到本地TTS")
                self.synthesizeWithLocalTTS(text: text, voiceType: voiceType, cacheFileURL: cacheFileURL, completion: completion)
            }
        }
        
        // 启动任务
        task.resume()
        logger.info("🚀 发送Azure语音合成请求")
    }
    
    /// 使用本地TTS合成语音 (iOS特定实现)
    private func synthesizeWithLocalTTS(
        text: String,
        voiceType: VoiceType,
        cacheFileURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        logger.info("🔊 使用iOS本地TTS合成语音")
        
        // 创建语音合成器
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        
        // 设置语音
        let voiceIdentifier: String
        switch voiceType {
        case .male:
            voiceIdentifier = "com.apple.ttsbundle.Tingchen-compact"
        case .female:
            voiceIdentifier = "com.apple.ttsbundle.Tingting-compact"
        case .child:
            voiceIdentifier = "com.apple.ttsbundle.Tingting-compact" // 模拟童声
        case .robot:
            voiceIdentifier = "com.apple.speech.synthesis.voice.Fred" // 模拟机器人声音
        }
        
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        utterance.rate = 0.5 // 语速
        utterance.pitchMultiplier = 1.0 // 音调
        utterance.volume = 1.0 // 音量
        
        // 使用AVAudioEngine录制语音
        let audioEngine = AVAudioEngine()
        let mixer = audioEngine.mainMixerNode
        
        // 设置录制格式
        let outputFormat = mixer.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: outputFormat.sampleRate,
            channels: 1,
            interleaved: false
        )
        
        // 创建文件
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(
                forWriting: cacheFileURL,
                settings: recordingFormat!.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: false
            )
        } catch {
            logger.error("❌ 创建音频文件失败: \(error.localizedDescription)")
            completion(.failure(SpeechServiceError.fileError))
            return
        }
        
        // 设置录制回调
        let bufferSize = 4096
        audioEngine.connect(mixer, to: audioEngine.outputNode, format: outputFormat)
        mixer.installTap(onBus: 0, bufferSize: UInt32(bufferSize), format: outputFormat) { buffer, time in
            do {
                try audioFile.write(from: buffer)
            } catch {
                self.logger.error("❌ 写入音频文件失败: \(error.localizedDescription)")
            }
        }
        
        // 启动音频引擎
        do {
            // iOS设置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            try audioEngine.start()
        } catch {
            logger.error("❌ 启动音频引擎失败: \(error.localizedDescription)")
            completion(.failure(SpeechServiceError.audioPlayerError))
            return
        }
        
        // 合成完成回调
        var didComplete = false
        
        // 使用SpeechSynthesizerDelegate监听合成完成
        let delegate = SpeechSynthesizerDelegate {
            if !didComplete {
                didComplete = true
                
                // 停止录制
                audioEngine.mainMixerNode.removeTap(onBus: 0)
                audioEngine.stop()
                
                // iOS下需要停用音频会话
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                } catch {
                    self.logger.error("❌ 停用音频会话失败: \(error.localizedDescription)")
                }
                
                // 转换为MP3格式
                self.convertToMP3(fileURL: cacheFileURL, completion: completion)
            }
        }
        
        // 保持对代理的引用
        synthesizer.delegate = delegate
        
        // 开始合成
        synthesizer.speak(utterance)
        
        // 设置超时
        DispatchQueue.global().asyncAfter(deadline: .now() + 60) {
            if !didComplete {
                didComplete = true
                
                // 停止录制
                audioEngine.mainMixerNode.removeTap(onBus: 0)
                audioEngine.stop()
                
                // iOS下需要停用音频会话
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                } catch {
                    self.logger.error("❌ 停用音频会话失败: \(error.localizedDescription)")
                }
                
                self.logger.error("❌ 语音合成超时")
                completion(.failure(SpeechServiceError.timeout))
            }
        }
    }
    
    // MARK: - 音频播放
    
    /// 播放音频文件
    func playAudio(fileURL: URL, completion: @escaping (Bool) -> Void) {
        do {
            // 停止当前播放
            stopAudio()
            
            // 创建新的播放器
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // 设置iOS音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            
            // 开始播放
            if audioPlayer?.play() == true {
                logger.info("✅ 开始播放音频: \(fileURL.lastPathComponent)")
                completion(true)
            } else {
                logger.error("❌ 播放音频失败")
                completion(false)
            }
        } catch {
            logger.error("❌ 创建音频播放器失败: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    /// 停止音频播放
    func stopAudio() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                logger.error("❌ 停用音频会话失败: \(error.localizedDescription)")
            }
            
            logger.info("✅ 停止音频播放")
        }
    }
    
    // MARK: - 缓存管理
    
    /// 生成缓存键
    private func generateCacheKey(text: String, voiceType: VoiceType) -> String {
        // 使用文本和语音类型的哈希值作为缓存键
        let textHash = text.data(using: .utf8)?.hashValue ?? 0
        let voiceHash = voiceType.rawValue.hashValue
        return "\(abs(textHash))_\(abs(voiceHash))"
    }
    
    /// 清理过期缓存
    private func cleanExpiredCache() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            let now = Date()
            
            do {
                // 获取所有缓存文件
                let cacheFiles = try fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: [])
                
                // 计算总缓存大小
                var totalSize: Int = 0
                var fileInfos: [(url: URL, date: Date, size: Int)] = []
                
                for fileURL in cacheFiles {
                    guard fileURL.pathExtension == "mp3" else { continue }
                    
                    let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    if let creationDate = attributes.creationDate,
                       let fileSize = attributes.fileSize {
                        totalSize += fileSize
                        fileInfos.append((fileURL, creationDate, fileSize))
                    }
                }
                
                // 删除过期文件
                for fileInfo in fileInfos {
                    let age = now.timeIntervalSince(fileInfo.date)
                    if age > self.maxCacheAge {
                        try fileManager.removeItem(at: fileInfo.url)
                        self.logger.info("🧹 删除过期缓存文件: \(fileInfo.url.lastPathComponent)")
                        totalSize -= fileInfo.size
                    }
                }
                
                // 如果缓存总大小超过限制，删除最旧的文件
                if totalSize > self.maxCacheSize {
                    // 按创建日期排序
                    let sortedFiles = fileInfos.sorted { $0.date < $1.date }
                    
                    for fileInfo in sortedFiles {
                        if totalSize <= self.maxCacheSize {
                            break
                        }
                        
                        try fileManager.removeItem(at: fileInfo.url)
                        self.logger.info("🧹 删除旧缓存文件以释放空间: \(fileInfo.url.lastPathComponent)")
                        totalSize -= fileInfo.size
                    }
                }
                
                self.logger.info("✅ 缓存清理完成，当前缓存大小: \(totalSize / 1024 / 1024)MB")
            } catch {
                self.logger.error("❌ 清理缓存失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 构建SSML
    private func buildSSML(text: String, voiceName: String) -> String {
        return """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
            <voice name='\(voiceName)'>
                <prosody rate='0.9' pitch='0'>
                    \(text)
                </prosody>
            </voice>
        </speak>
        """
    }
    
    /// 将音频文件转换为MP3格式
    private func convertToMP3(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // 在实际应用中，这里应该使用AVAssetExportSession进行转换
        // 由于这超出了本示例的范围，我们直接返回原始文件
        completion(.success(fileURL))
    }
    
    // MARK: - AVAudioPlayerDelegate 方法
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("✅ 音频播放完成，成功: \(flag)")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            logger.error("❌ 音频解码错误: \(error.localizedDescription)")
        }
    }
    
    // MARK: - iOS平台特定方法
    
    /// iOS平台特定的音频会话设置
    func setupAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true, options: [])
    }
    
    /// iOS平台特定的音频会话关闭
    func deactivateAudioSession() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// 语音合成代理
class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
} 