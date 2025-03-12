import Foundation
import AVFoundation
import os.log

/// 语音合成错误
enum SpeechSynthesisError: Error {
    case apiKeyMissing
    case requestFailed(Error)
    case invalidResponse
    case audioProcessingFailed
    case fileSaveFailed
    case invalidVoiceType
    case customVoiceTrainingFailed
    case customVoiceNotAllowed
    case custom(String)
    
    var localizedDescription: String {
        switch self {
        case .apiKeyMissing:
            return "缺少Azure语音服务密钥"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的API响应"
        case .audioProcessingFailed:
            return "音频处理失败"
        case .fileSaveFailed:
            return "音频文件保存失败"
        case .invalidVoiceType:
            return "无效的语音类型"
        case .customVoiceTrainingFailed:
            return "自定义语音训练失败"
        case .customVoiceNotAllowed:
            return "当前设置不允许自定义语音训练"
        case .custom(let message):
            return message
        }
    }
}

/// 语音类型
enum VoiceType: String, CaseIterable {
    case female = "zh-CN-XiaoxiaoNeural"     // 女声-小孩
    case male = "zh-CN-YunxiNeural"          // 男声-小孩
    case adult_female = "zh-CN-XiaochenNeural" // 成人女声
    case adult_male = "zh-CN-YunjianNeural"   // 成人男声
    case custom = "custom"                    // 自定义声音
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .female: return "小女孩"
        case .male: return "小男孩"
        case .adult_female: return "成人女声"
        case .adult_male: return "成人男声"
        case .custom: return "自定义声音"
        }
    }
}

/// 语速
enum SpeechRate: String, CaseIterable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .slow: return "慢速"
        case .normal: return "正常"
        case .fast: return "快速"
        }
    }
    
    /// SSML值
    var value: String {
        switch self {
        case .slow: return "0.8"
        case .normal: return "1.0"
        case .fast: return "1.2"
        }
    }
}

/// 语音合成服务
class SpeechService {
    /// 共享实例
    static let shared = SpeechService()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "SpeechService")
    
    /// 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    /// 本地合成器（备用）
    private var localSynthesizer: AVSpeechSynthesizer
    
    /// 本地当前合成任务
    private var currentSynthesisTask: AVSpeechSynthesisTask?
    
    /// 播放计时器
    private var playbackTimer: Timer?
    
    /// 当前播放时间
    private var currentPlaybackTime: TimeInterval = 0
    
    /// 播放更新处理器
    private var playbackUpdateHandler: ((TimeInterval) -> Void)?
    
    /// Azure API密钥
    private let azureApiKey: String
    
    /// Azure区域
    private let azureRegion: String
    
    /// 自定义语音ID
    private var customVoiceId: String?
    
    /// 是否使用本地备用方案
    private let useLocalFallback: Bool
    
    /// 缓存过期天数
    private let cacheExpiryDays: Int
    
    /// 语音缓存
    private var audioCache = NSCache<NSString, NSData>()
    
    /// 并发队列
    private let synthesisQueue = DispatchQueue(label: "com.example.baobao.speechsynthesis", attributes: .concurrent)
    
    /// 语音合成进度通知
    static let speechSynthesisProgressNotification = Notification.Name("SpeechSynthesisProgressNotification")
    
    // 常量
    private let azureBaseUrl = "https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    private let azureCustomVoiceUrl = "https://{region}.voice.speech.microsoft.com/api/v1/endpoints/custom"
    
    // 音频设置
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 2,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    /// 初始化
    private init() {
        localSynthesizer = AVSpeechSynthesizer()
        
        // 从配置管理器获取配置
        let config = ConfigurationManager.shared
        self.azureApiKey = config.azureSpeechKey
        self.azureRegion = config.azureSpeechRegion
        self.customVoiceId = config.azureCustomVoiceId
        self.useLocalFallback = config.useLocalFallback
        self.cacheExpiryDays = config.cacheExpiryDays
        
        // 记录初始化信息
        if azureApiKey.isEmpty {
            logger.info("🎙️ SpeechService初始化，未配置Azure语音服务，将使用本地语音")
        } else {
            logger.info("🎙️ SpeechService初始化，使用Azure语音服务，区域: \(azureRegion)")
        }
        
        if let customVoiceId = customVoiceId {
            logger.info("🎙️ 自定义语音ID已配置: \(customVoiceId)")
        }
        
        // 设置缓存限制
        audioCache.countLimit = 50
        audioCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 设置音频会话
        setupAudioSession()
    }
    
    /// 设置音频会话
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.info("✅ 音频会话设置成功")
        } catch {
            logger.error("❌ 音频会话设置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 语音合成
    
    /// 合成语音
    /// - Parameters:
    ///   - text: 要合成的文本
    ///   - voiceType: 语音类型，默认为萍萍阿姨
    ///   - speechRate: 语速
    ///   - useCache: 是否使用缓存
    ///   - completion: 完成回调，返回音频文件URL或错误
    func synthesize(text: String, voiceType: VoiceType = .female, speechRate: SpeechRate = .normal, useCache: Bool = true, completion: @escaping (Result<URL, Error>) -> Void) {
        // 检查文本是否为空
        guard !text.isEmpty else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "文本为空"])))
            return
        }
        
        // 生成缓存键
        let cacheKey = "\(text)_\(voiceType.rawValue)_\(speechRate.rawValue)" as NSString
        
        // 检查缓存
        if useCache, let cachedData = audioCache.object(forKey: cacheKey) as Data? {
            logger.info("📋 使用缓存的语音")
            
            // 将缓存的数据保存到临时文件
            do {
                let tempURL = try saveToTempFile(data: cachedData)
                completion(.success(tempURL))
            } catch {
                logger.error("❌ 无法从缓存保存音频: \(error.localizedDescription)")
                completion(.failure(error))
            }
            return
        }
        
        // 取消当前的合成任务（如果有）
        currentSynthesisTask?.cancel()
        
        // 在后台队列中进行语音合成
        synthesisQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("🔊 开始合成语音，文本长度: \(text.count)字")
            
            // 分段处理长文本
            if text.count > 1000 {
                self.synthesizeLongSpeech(text: text, voiceType: voiceType, speechRate: speechRate, cacheKey: cacheKey, completion: completion)
                return
            }
            
            // 生成SSML
            let ssml = self.generateSSML(for: text, voiceType: voiceType, speechRate: speechRate)
            
            // 发送API请求
            self.makeAzureSpeechRequest(ssml: ssml) { result in
                switch result {
                case .success(let data):
                    // 保存到缓存
                    self.audioCache.setObject(data as NSData, forKey: cacheKey)
                    
                    // 保存到临时文件
                    do {
                        let tempURL = try self.saveToTempFile(data: data)
                        DispatchQueue.main.async {
                            self.logger.info("✅ 语音合成成功")
                            completion(.success(tempURL))
                        }
        } catch {
                        DispatchQueue.main.async {
                            self.logger.error("❌ 无法保存音频文件: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.logger.error("❌ 语音合成失败: \(error.localizedDescription)")
            completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// 合成长文本语音
    /// - Parameters:
    ///   - text: 长文本
    ///   - voiceType: 语音类型
    ///   - speechRate: 语速
    ///   - cacheKey: 缓存键
    ///   - completion: 完成回调
    private func synthesizeLongSpeech(text: String, 
                                     voiceType: VoiceType, 
                                     speechRate: SpeechRate,
                                     cacheKey: NSString,
                                     completion: @escaping (Result<URL, Error>) -> Void) {
        logger.info("📃 开始处理长文本，分段合成")
        
        // 分段
        let segments = splitTextIntoNaturalSegments(text)
        let totalSegments = segments.count
        
        logger.info("🔢 文本已分为\(totalSegments)段")
        
        // 用于存储所有音频数据
        var audioDataParts: [Data] = []
        var completedSegments = 0
        
        // 创建一个调度组来同步所有分段的处理
        let dispatchGroup = DispatchGroup()
        
        // 顺序处理所有分段
        for (index, segment) in segments.enumerated() {
            // 进入调度组
            dispatchGroup.enter()
            
            // 生成该分段的SSML
            let ssml = generateSSML(for: segment, voiceType: voiceType, speechRate: speechRate)
            
            // 合成该分段
            makeAzureSpeechRequest(ssml: ssml) { [weak self] result in
                guard let self = self else {
                    dispatchGroup.leave()
            return
                }
                
                switch result {
                case .success(let data):
                    // 添加到结果列表
                    audioDataParts.append(data)
                    
                    // 更新进度
                    completedSegments += 1
                    
                    // 通知进度更新
                    let progress = Float(completedSegments) / Float(totalSegments)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: SpeechService.speechSynthesisProgressNotification,
                            object: nil,
                            userInfo: ["progress": progress]
                        )
                    }
                    
                    self.logger.info("✅ 完成分段 \(index + 1)/\(totalSegments) - 进度: \(Int(progress * 100))%")
                    
                case .failure(let error):
                    self.logger.error("❌ 分段 \(index + 1) 合成失败: \(error.localizedDescription)")
                    // 我们继续处理其他分段，但记录错误
                }
                
                // 离开调度组
                dispatchGroup.leave()
            }
            
            // 为了不超过API速率限制，在分段请求之间添加小延迟
            if index < segments.count - 1 {
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        
        // 所有分段完成后
        dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
            
            // 检查是否有足够的音频数据
            guard !audioDataParts.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "所有分段合成都失败了"])))
                }
                return
            }
            
            // 合并所有音频数据
            do {
                let combinedData = try self.mergeAudioData(audioDataParts)
                
                // 保存到缓存
                self.audioCache.setObject(combinedData as NSData, forKey: cacheKey)
                
                // 保存到临时文件
                let tempURL = try self.saveToTempFile(data: combinedData)
                
                DispatchQueue.main.async {
                    self.logger.info("✅ 长文本语音合成成功")
                    completion(.success(tempURL))
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.error("❌ 合并音频失败: \(error.localizedDescription)")
                completion(.failure(error))
                }
            }
        }
    }
    
    /// 将文本分割成自然段落
    /// - Parameter text: 要分割的文本
    /// - Returns: 分割后的段落数组
    private func splitTextIntoNaturalSegments(_ text: String) -> [String] {
        // 首先按段落分割
        var paragraphs = text.components(separatedBy: "\n\n")
        
        // 如果没有段落，则按句子分割
        if paragraphs.count <= 1 {
            paragraphs = text.components(separatedBy: "。").filter { !$0.isEmpty }.map { $0 + "。" }
        }
        
        // 确保每个段落不超过1000字符
        var segments: [String] = []
        
        for paragraph in paragraphs {
            if paragraph.count <= 1000 {
                segments.append(paragraph)
            } else {
                // 按句子分割长段落
                let sentences = paragraph.components(separatedBy: "。").filter { !$0.isEmpty }.map { $0 + "。" }
                var currentSegment = ""
                
                for sentence in sentences {
                    if currentSegment.count + sentence.count <= 1000 {
                        currentSegment += sentence
                    } else {
                        if !currentSegment.isEmpty {
                            segments.append(currentSegment)
                        }
                        currentSegment = sentence
                    }
                }
                
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
            }
        }
        
        return segments
    }
    
    /// 合并多个音频数据
    /// - Parameter audioParts: 音频数据数组
    /// - Returns: 合并后的音频数据
    private func mergeAudioData(_ audioParts: [Data]) throws -> Data {
        guard !audioParts.isEmpty else {
            throw NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有音频数据可合并"])
        }
        
        // 如果只有一部分，直接返回
        if audioParts.count == 1 {
            return audioParts[0]
        }
        
        // 创建临时文件URLs
        var tempURLs: [URL] = []
        for (index, data) in audioParts.enumerated() {
            let filename = "part_\(index).mp3"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url)
            tempURLs.append(url)
        }
        
        // 使用AVAssetExportSession合并音频
        let composition = AVMutableComposition()
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var currentTime = CMTime.zero
        
        for url in tempURLs {
            let asset = AVAsset(url: url)
            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            
            do {
                try audioTrack?.insertTimeRange(timeRange, of: asset.tracks(withMediaType: .audio)[0], at: currentTime)
                currentTime = CMTimeAdd(currentTime, asset.duration)
            } catch {
                logger.error("❌ 合并音频时出错: \(error.localizedDescription)")
                throw error
            }
        }
        
        // 导出合并后的音频
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("combined.mp3")
        
        // 删除可能存在的旧文件
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else {
            throw NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp3
        
        // 等待导出完成
        let exportSemaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            exportSemaphore.signal()
        }
        exportSemaphore.wait()
        
        // 检查导出状态
        if exportSession.status == .completed {
            // 读取合并的音频数据
            let data = try Data(contentsOf: outputURL)
            
            // 清理临时文件
            for url in tempURLs {
                try? FileManager.default.removeItem(at: url)
            }
            try? FileManager.default.removeItem(at: outputURL)
            
            return data
        } else {
            throw NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "导出失败: \(exportSession.error?.localizedDescription ?? "未知错误")"])
        }
    }
    
    /// 生成SSML标记
    /// - Parameters:
    ///   - text: 文本内容
    ///   - voiceType: 语音类型
    ///   - speechRate: 语速
    /// - Returns: SSML标记字符串
    private func generateSSML(for text: String, voiceType: VoiceType, speechRate: SpeechRate) -> String {
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        
        // 获取实际的声音ID
        var voiceID = voiceType.rawValue
        if voiceType == .custom, let customVoiceID = ConfigurationManager.shared.getString(forKey: "CUSTOM_VOICE_ID", defaultValue: "").nilIfEmpty {
            voiceID = customVoiceID
        }
        
        // 检查是否需要使用自定义发音
        let enableCustomPronunciation = ConfigurationManager.shared.getBool(forKey: "ENABLE_CUSTOM_PRONUNCIATION", defaultValue: true)
        
        // SSML模板
        var ssml = """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="zh-CN">
            <voice name="\(voiceID)">
                <prosody rate="\(speechRate.value)">
        """
        
        // 增强表现力
        if ConfigurationManager.shared.getBool(forKey: "ENHANCE_EXPRESSIVENESS", defaultValue: true) {
            ssml = ssml.replacingOccurrences(of: "<prosody rate", with: "<mstts:express-as style=\"cheerful\"><prosody rate")
        }
        
        // 处理文本添加标点、停顿等
        if enableCustomPronunciation {
            ssml += enhanceTextWithPronunciation(escapedText)
        } else {
            ssml += escapedText
        }
        
        // 关闭标签
        if ConfigurationManager.shared.getBool(forKey: "ENHANCE_EXPRESSIVENESS", defaultValue: true) {
            ssml += """
                    </prosody>
                </mstts:express-as>
            </voice>
        </speak>
        """
        } else {
            ssml += """
                    </prosody>
                </voice>
            </speak>
            """
        }
        
        return ssml
    }
    
    /// 增强文本的发音，添加停顿和语调变化
    /// - Parameter text: 原始文本
    /// - Returns: 增强后的文本
    private func enhanceTextWithPronunciation(_ text: String) -> String {
        var enhancedText = text
        
        // 在问号后添加小停顿
        enhancedText = enhancedText.replacingOccurrences(of: "？", with: "？<break time=\"300ms\"/>")
        
        // 在感叹号后添加中等停顿
        enhancedText = enhancedText.replacingOccurrences(of: "！", with: "！<break time=\"400ms\"/>")
        
        // 在句号后添加小停顿
        enhancedText = enhancedText.replacingOccurrences(of: "。", with: "。<break time=\"250ms\"/>")
        
        // 在逗号后添加极小停顿
        enhancedText = enhancedText.replacingOccurrences(of: "，", with: "，<break time=\"150ms\"/>")
        
        // 在分号后添加小停顿
        enhancedText = enhancedText.replacingOccurrences(of: "；", with: "；<break time=\"200ms\"/>")
        
        // 在冒号后添加小停顿
        enhancedText = enhancedText.replacingOccurrences(of: "：", with: "：<break time=\"200ms\"/>")
        
        // 处理引号中的文本，增加语调变化（表示对话）
        var components = enhancedText.components(separatedBy: """)
        if components.count > 1 {
            for i in 1..<components.count {
                if let endQuoteIndex = components[i].firstIndex(of: """) {
                    let dialogText = String(components[i][..<endQuoteIndex])
                    let wrappedDialog = "<prosody pitch=\"+10%\">\(dialogText)</prosody>"
                    
                    let afterQuote = String(components[i][endQuoteIndex...])
                    components[i] = wrappedDialog + afterQuote
                }
            }
            enhancedText = components.joined(separator: """)
        }
        
        return enhancedText
    }
    
    /// 发送Azure语音合成请求
    /// - Parameters:
    ///   - ssml: SSML标记
    ///   - completion: 完成回调
    private func makeAzureSpeechRequest(ssml: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // 获取API配置
        guard let subscriptionKey = ConfigurationManager.shared.getString(forKey: "AZURE_SPEECH_KEY", defaultValue: "").nilIfEmpty,
              let region = ConfigurationManager.shared.getString(forKey: "AZURE_SPEECH_REGION", defaultValue: "eastasia").nilIfEmpty else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "Azure语音配置缺失"])))
            return
        }
        
        // 构建API URL
        let urlString = "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的Azure API URL"])))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.addValue(UUID().uuidString, forHTTPHeaderField: "X-RequestId")
        request.httpBody = ssml.data(using: .utf8)
        
        // 记录开始时间
        let startTime = Date()
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 计算请求时间
            let requestTime = Date().timeIntervalSince(startTime)
            self.logger.info("⏱️ 语音合成请求耗时: \(String(format: "%.2f", requestTime))秒")
            
            // 处理错误
            if let error = error {
                self.logger.error("❌ 网络错误: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])))
                return
            }
            
            // 检查状态码
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "未知错误"
                self.logger.error("❌ Azure API错误 (\(httpResponse.statusCode)): \(errorMessage)")
                completion(.failure(NSError(domain: "com.example.baobao", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Azure服务错误: \(errorMessage)"])))
                return
            }
            
            // 检查数据
            guard let data = data, !data.isEmpty else {
                completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "返回数据为空"])))
                return
            }
            
            // 记录音频大小
            self.logger.info("📊 合成的音频大小: \(String(format: "%.2f", Double(data.count) / 1024.0))KB")
            
            // 返回成功结果
            completion(.success(data))
        }
        
        // 保存任务引用
        currentSynthesisTask = task
        
        // 启动任务
        task.resume()
    }
    
    /// 保存音频数据到临时文件
    /// - Parameter data: 音频数据
    /// - Returns: 临时文件URL
    private func saveToTempFile(data: Data) throws -> URL {
        // 创建唯一文件名
        let fileName = "speech_\(UUID().uuidString).mp3"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // 保存数据
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    // MARK: - 音频播放
    
    /// 播放音频
    /// - Parameters:
    ///   - url: 音频文件URL
    ///   - position: 起始位置（秒）
    ///   - progressHandler: 播放进度处理器
    ///   - completion: 完成回调，返回可能的错误
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
    
    /// 停止播放
    func stop() {
        logger.info("⏹️ 停止播放音频")
        stopPlaybackTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        currentPlaybackTime = 0
    }
    
    /// 暂停播放
    func pause() {
        logger.info("⏸️ 暂停播放音频")
        stopPlaybackTimer()
        audioPlayer?.pause()
    }
    
    /// 恢复播放
    func resume() {
        logger.info("▶️ 恢复播放音频")
        if audioPlayer?.play() == true {
            startPlaybackTimer()
        }
    }
    
    /// 获取当前播放时间
    /// - Returns: 当前播放时间（秒）
    func getCurrentTime() -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    /// 获取音频总时长
    /// - Returns: 音频总时长（秒）
    func getDuration() -> TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    // MARK: - 缓存管理
    
    /// 清理语音缓存
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
            
            // 清理持久化存储中的过期文件
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let documentFiles = try fileManager.contentsOfDirectory(at: documentsURL,
                                                                 includingPropertiesForKeys: [.creationDateKey],
                                                                 options: [])
            
            // 使用配置的缓存过期天数
            let expiryDate = Date().addingTimeInterval(-Double(cacheExpiryDays) * 24 * 60 * 60)
            
            for file in documentFiles where file.lastPathComponent.hasPrefix("speech_") {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < expiryDate {
                    try fileManager.removeItem(at: file)
                }
            }
            
            logger.info("✅ 缓存清理完成")
        } catch {
            logger.error("❌ 清理缓存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助方法
    
    /// 配置本地语音参数
    /// - Parameters:
    ///   - utterance: 语音合成请求
    ///   - voiceType: 语音类型
    private func configureLocalUtterance(_ utterance: AVSpeechUtterance, voiceType: String) {
        // 根据显示名称设置语音参数
        switch voiceType {
        case "萍萍阿姨":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.1
        case "大卫叔叔":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.45
            utterance.pitchMultiplier = 0.9
        case "故事爷爷":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.4
            utterance.pitchMultiplier = 0.85
        case "甜甜姐姐":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.2
        case "活泼童声":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.55
            utterance.pitchMultiplier = 1.3
        default:
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
        }
        
        utterance.volume = 1.0
    }
    
    /// 配置音频会话
    /// - Throws: 配置音频会话时的错误
    private func configureAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    /// 开始播放计时器
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
    
    /// 停止播放计时器
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

// MARK: - 字符串扩展
extension String {
    /// 如果字符串为空则返回nil
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
} 