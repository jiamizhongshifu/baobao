import Foundation
import AVFoundation
import os.log
import Combine

/// 语音类型
enum VoiceType: String, CaseIterable {
    case xiaoMing = "小明哥哥"
    case xiaoHong = "小红姐姐"
    case pingPing = "萍萍阿姨"
    case laoWang = "老王爷爷"
    case robot = "机器人"
    
    /// 对应的Azure语音名称
    var azureVoiceName: String {
        switch self {
        case .xiaoMing:
            return "zh-CN-YunxiNeural" // 年轻男声
        case .xiaoHong:
            return "zh-CN-XiaoxiaoNeural" // 年轻女声
        case .pingPing:
            return "zh-CN-XiaochenNeural" // 成熟女声
        case .laoWang:
            return "zh-CN-YunjianNeural" // 成熟男声
        case .robot:
            return "zh-CN-YunyangNeural" // 机器人风格声音
        }
    }
    
    /// 对应的本地TTS语音
    var localVoiceIdentifier: String {
        switch self {
        case .xiaoMing:
            return "com.apple.voice.compact.zh-CN.Tingting" // 中文男声
        case .xiaoHong, .pingPing:
            return "com.apple.voice.compact.zh-CN.Sinji" // 中文女声
        case .laoWang:
            return "com.apple.voice.compact.zh-CN.Tingting" // 中文男声（重复使用）
        case .robot:
            return "com.apple.voice.compact.zh-CN.Sinji" // 中文女声（重复使用）
        }
    }
    
    /// 语音描述
    var description: String {
        switch self {
        case .xiaoMing:
            return "活泼开朗的小明哥哥，适合讲述冒险故事"
        case .xiaoHong:
            return "温柔甜美的小红姐姐，适合讲述温馨故事"
        case .pingPing:
            return "知识渊博的萍萍阿姨，适合讲述科普故事"
        case .laoWang:
            return "睿智幽默的老王爷爷，适合讲述传统故事"
        case .robot:
            return "有趣的机器人，适合讲述科幻故事"
        }
    }
    
    /// 从字符串创建VoiceType
    static func from(string: String) -> VoiceType? {
        return VoiceType.allCases.first { $0.rawValue == string }
    }
}

/// 语音合成错误类型
enum SpeechServiceError: Error {
    case synthesizeFailed
    case invalidParameters
    case networkError(Error)
    case apiError(Int, String)
    case rateLimited
    case timeout
    case audioError
    case offlineMode
    case noCache
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .synthesizeFailed:
            return "语音合成失败"
        case .invalidParameters:
            return "无效的参数"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误 (\(code)): \(message)"
        case .rateLimited:
            return "API请求频率超限"
        case .timeout:
            return "请求超时"
        case .audioError:
            return "音频处理错误"
        case .offlineMode:
            return "当前处于离线模式"
        case .noCache:
            return "离线模式下无缓存可用"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

/// 语音合成状态
enum SpeechSynthesisStatus {
    case idle
    case synthesizing
    case success(URL)
    case failure(SpeechServiceError)
}

/// 语音服务，负责语音合成和管理
class SpeechService {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = SpeechService()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.speech", category: "SpeechService")
    
    /// 配置管理器
    private let configManager = ConfigurationManager.shared
    
    /// 缓存管理器
    private let cacheManager = CacheManager.shared
    
    /// 网络管理器
    private let networkManager = NetworkManager.shared
    
    /// 设置仓库
    private let settingsRepository = SettingsRepository.shared
    
    /// 孩子仓库
    private let childRepository = ChildRepository.shared
    
    /// 语音合成器
    private let synthesizer = AVSpeechSynthesizer()
    
    /// 语音合成状态
    @Published private(set) var synthesisStatus: SpeechSynthesisStatus = .idle
    
    /// 语音合成状态发布者
    var synthesisStatusPublisher: AnyPublisher<SpeechSynthesisStatus, Never> {
        return $synthesisStatus.eraseToAnyPublisher()
    }
    
    /// 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    private init() {
        // 监听网络状态变化
        networkManager.networkStatusPublisher
            .sink { [weak self] status in
                self?.logger.info("网络状态变化: \(status)")
            }
            .store(in: &cancellables)
        
        // 监听离线模式变化
        networkManager.offlineModePublisher
            .sink { [weak self] isOffline in
                self?.logger.info("离线模式变化: \(isOffline ? "启用" : "禁用")")
            }
            .store(in: &cancellables)
            
        // 监听设置变更
        settingsRepository.settingsChangesPublisher
            .sink { [weak self] settings in
                self?.logger.info("应用设置变更: useLocalTTSByDefault=\(settings.useLocalTTSByDefault)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /// 合成语音
    /// - Parameters:
    ///   - text: 要合成的文本
    ///   - voiceType: 语音类型
    ///   - childId: 孩子ID（可选，用于获取语音偏好）
    ///   - forceRefresh: 是否强制刷新（忽略缓存）
    ///   - completion: 完成回调
    func synthesizeSpeech(text: String, voiceType: VoiceType? = nil, childId: String? = nil, forceRefresh: Bool = false, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        // 更新状态
        synthesisStatus = .synthesizing
        
        // 验证参数
        guard !text.isEmpty else {
            let error = SpeechServiceError.invalidParameters
            synthesisStatus = .failure(error)
            completion(.failure(error))
            return
        }
        
        // 确定使用的语音类型
        let finalVoiceType = determineVoiceType(voiceType: voiceType, childId: childId)
        
        // 获取语音偏好设置
        let voicePreference = getVoicePreference(childId: childId)
        
        // 生成缓存键
        let cacheKey = generateCacheKey(text: text, voiceType: finalVoiceType)
        
        // 检查缓存（如果不强制刷新）
        if !forceRefresh, let cachedFileURL = cacheManager.fileURLFromCache(forKey: cacheKey, type: .speech) {
            logger.info("从缓存中获取语音: \(cacheKey)")
            synthesisStatus = .success(cachedFileURL)
            completion(.success(cachedFileURL))
            return
        }
        
        // 检查网络状态和配置
        let useLocalTTS = voicePreference?.useLocalTTS ?? settingsRepository.getAppSettings().useLocalTTSByDefault || !networkManager.canPerformNetworkRequest()
        
        if useLocalTTS {
            // 使用本地TTS
            synthesizeWithLocalTTS(text: text, voiceType: finalVoiceType, speechRate: voicePreference?.speechRate ?? 1.0, volume: voicePreference?.volume ?? 1.0, cacheKey: cacheKey) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let fileURL):
                    self.synthesisStatus = .success(fileURL)
                    completion(.success(fileURL))
                case .failure(let error):
                    self.synthesisStatus = .failure(error)
                    completion(.failure(error))
                }
            }
        } else {
            // 使用Azure TTS
            synthesizeWithAzureTTS(text: text, voiceType: finalVoiceType, speechRate: voicePreference?.speechRate ?? 1.0, volume: voicePreference?.volume ?? 1.0, cacheKey: cacheKey) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let fileURL):
                    self.synthesisStatus = .success(fileURL)
                    completion(.success(fileURL))
                case .failure(let error):
                    // 如果Azure TTS失败，尝试使用本地TTS作为备选
                    if self.configManager.useLocalFallback {
                        self.logger.info("Azure TTS失败，尝试使用本地TTS作为备选")
                        self.synthesizeWithLocalTTS(text: text, voiceType: finalVoiceType, speechRate: voicePreference?.speechRate ?? 1.0, volume: voicePreference?.volume ?? 1.0, cacheKey: cacheKey, completion: { fallbackResult in
                            switch fallbackResult {
                            case .success(let fileURL):
                                self.synthesisStatus = .success(fileURL)
                                completion(.success(fileURL))
                            case .failure(let fallbackError):
                                self.synthesisStatus = .failure(fallbackError)
                                completion(.failure(fallbackError))
                            }
                        })
                    } else {
                        self.synthesisStatus = .failure(error)
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// 获取所有可用的语音类型
    func getAllVoiceTypes() -> [VoiceType] {
        return VoiceType.allCases
    }
    
    /// 获取孩子的语音偏好
    func getVoicePreference(childId: String?) -> VoicePreferenceModel? {
        guard let childId = childId else { return nil }
        
        if let child = childRepository.getChild(withId: childId) {
            return child.voicePreference
        }
        
        return nil
    }
    
    /// 更新孩子的语音偏好
    func updateVoicePreference(childId: String, voiceType: VoiceType, speechRate: Double = 1.0, volume: Double = 1.0, useLocalTTS: Bool = false) {
        childRepository.updateVoicePreference(
            childId: childId,
            voiceType: voiceType.rawValue,
            speechRate: speechRate,
            volume: volume,
            useLocalTTS: useLocalTTS
        )
    }
    
    // MARK: - 私有方法
    
    /// 确定使用的语音类型
    private func determineVoiceType(voiceType: VoiceType?, childId: String?) -> VoiceType {
        // 如果指定了语音类型，直接使用
        if let voiceType = voiceType {
            return voiceType
        }
        
        // 如果指定了孩子ID，尝试获取孩子的语音偏好
        if let childId = childId, let child = childRepository.getChild(withId: childId), let voicePreference = child.voicePreference {
            if let preferredVoiceType = VoiceType.from(string: voicePreference.preferredVoiceType) {
                return preferredVoiceType
            }
        }
        
        // 使用默认语音类型
        let defaultVoiceTypeString = configManager.defaultVoiceType
        return VoiceType.from(string: defaultVoiceTypeString) ?? .pingPing
    }
    
    /// 生成缓存键
    private func generateCacheKey(text: String, voiceType: VoiceType) -> String {
        // 使用文本的哈希值和语音类型生成缓存键
        let textHash = text.hash
        return "speech_\(voiceType.rawValue)_\(textHash)".replacingOccurrences(of: " ", with: "_")
    }
    
    /// 使用Azure语音服务合成语音
    private func synthesizeWithAzureTTS(text: String, voiceType: VoiceType, speechRate: Double, volume: Double, cacheKey: String, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        // 构建请求URL
        guard let url = URL(string: configManager.speechSynthesisEndpoint) else {
            completion(.failure(.invalidParameters))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置请求头
        request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.addValue(configManager.azureSpeechKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        
        // 构建SSML
        let ssml = """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
            <voice name='\(voiceType.azureVoiceName)'>
                \(text)
            </voice>
        </speak>
        """
        
        // 设置请求体
        request.httpBody = ssml.data(using: .utf8)
        
        // 设置超时时间
        request.timeoutInterval = 60.0
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 处理网络错误
            if let error = error {
                self.logger.error("网络错误: \(error.localizedDescription)")
                completion(.failure(.networkError(error)))
                return
            }
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown(NSError(domain: "SpeechService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"]))))
                return
            }
            
            // 处理HTTP错误
            switch httpResponse.statusCode {
            case 200:
                // 成功，继续处理
                break
            case 401:
                self.logger.error("API密钥无效")
                completion(.failure(.apiError(httpResponse.statusCode, "API密钥无效")))
                return
            case 429:
                self.logger.error("API请求频率超限")
                completion(.failure(.rateLimited))
                return
            case 500, 502, 503, 504:
                self.logger.error("服务器错误: \(httpResponse.statusCode)")
                completion(.failure(.apiError(httpResponse.statusCode, "服务器错误")))
                return
            default:
                self.logger.error("API错误: \(httpResponse.statusCode)")
                
                if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                    self.logger.error("错误信息: \(errorMessage)")
                    completion(.failure(.apiError(httpResponse.statusCode, errorMessage)))
                } else {
                    completion(.failure(.apiError(httpResponse.statusCode, "未知错误")))
                }
                return
            }
            
            // 处理响应数据
            guard let audioData = data, !audioData.isEmpty else {
                self.logger.error("返回的音频数据为空")
                completion(.failure(.synthesizeFailed))
                return
            }
            
            // 保存到缓存
            if let fileURL = self.cacheManager.saveToCache(data: audioData, forKey: cacheKey, type: .speech) {
                self.logger.info("语音合成成功，大小: \(audioData.count) 字节")
                completion(.success(fileURL))
            } else {
                self.logger.error("保存音频文件失败")
                completion(.failure(.fileError))
            }
        }
        
        task.resume()
    }
    
    /// 使用本地TTS合成语音
    private func synthesizeWithLocalTTS(text: String, voiceType: VoiceType, speechRate: Double, volume: Double, cacheKey: String, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        // 创建临时文件URL
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
        
        // 创建音频引擎
        let audioEngine = AVAudioEngine()
        let mixer = audioEngine.mainMixerNode
        let outputFormat = mixer.outputFormat(forBus: 0)
        
        // 创建音频文件
        guard let audioFile = try? AVAudioFile(forWriting: tempFileURL, settings: outputFormat.settings) else {
            self.logger.error("创建音频文件失败")
            completion(.failure(.fileError))
            return
        }
        
        // 创建语音合成请求
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceType.localVoiceIdentifier)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0 // 音调
        utterance.volume = volume
        
        // 设置音频缓冲区
        let inputNode = audioEngine.inputNode
        let bus = 0
        
        // 安装音频缓冲区
        inputNode.installTap(onBus: bus, bufferSize: 4096, format: outputFormat) { buffer, time in
            try? audioFile.write(from: buffer)
        }
        
        do {
            // 启动音频引擎
            try audioEngine.start()
            
            // 开始合成
            synthesizer.speak(utterance)
            
            // 等待合成完成
            synthesizer.delegate = nil
            
            // 使用信号量等待合成完成
            let semaphore = DispatchSemaphore(value: 0)
            
            synthesizer.delegate = SpeechSynthesizerDelegate(onFinish: {
                // 停止音频引擎
                audioEngine.stop()
                inputNode.removeTap(onBus: bus)
                
                // 保存到缓存
                do {
                    let audioData = try Data(contentsOf: tempFileURL)
                    
                    if let fileURL = self.cacheManager.saveToCache(data: audioData, forKey: cacheKey, type: .speech) {
                        self.logger.info("本地TTS合成成功，大小: \(audioData.count) 字节")
                        completion(.success(fileURL))
                    } else {
                        self.logger.error("保存音频文件失败")
                        completion(.failure(.fileError))
                    }
                    
                    // 删除临时文件
                    try FileManager.default.removeItem(at: tempFileURL)
                } catch {
                    self.logger.error("处理音频文件失败: \(error.localizedDescription)")
                    completion(.failure(.fileError))
                }
                
                semaphore.signal()
            })
            
            // 在后台线程等待合成完成
            DispatchQueue.global().async {
                _ = semaphore.wait(timeout: .now() + 300) // 最多等待5分钟
            }
        } catch {
            self.logger.error("启动音频引擎失败: \(error.localizedDescription)")
            completion(.failure(.synthesizeFailed))
        }
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

/// 配置管理器（占位实现，实际项目中应该有完整的实现）
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    var azureSpeechKey: String {
        return ProcessInfo.processInfo.environment["AZURE_SPEECH_KEY"] ?? "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }
    
    var azureSpeechRegion: String {
        return ProcessInfo.processInfo.environment["AZURE_SPEECH_REGION"] ?? "eastasia"
    }
    
    var speechSynthesisEndpoint: String {
        return "https://\(azureSpeechRegion).tts.speech.microsoft.com/cognitiveservices/v1"
    }
    
    var useLocalTTSByDefault: Bool = true
    var useLocalFallback: Bool = true
    
    private init() {}
} 