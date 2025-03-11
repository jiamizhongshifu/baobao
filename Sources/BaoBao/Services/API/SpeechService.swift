import Foundation
import AVFoundation
import os.log

// MARK: - 语音合成服务
class SpeechService: NSObject {
    // 单例模式
    static let shared = SpeechService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "speech-service")
    
    // API服务
    private let apiService = APIService.shared
    
    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    // Azure语音服务配置
    private let azureRegion = "eastasia"
    private var azureKey: String? {
        // 从环境变量或配置文件中获取API密钥
        return ProcessInfo.processInfo.environment["AZURE_SPEECH_KEY"]
    }
    
    // 私有初始化方法
    private override init() {
        super.init()
        logger.info("语音合成服务初始化完成")
        setupAudioSession()
    }
    
    // MARK: - 语音合成
    func synthesizeSpeech(
        text: String,
        voiceType: VoiceType,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        logger.info("开始语音合成，文本长度: \(text.count)，语音类型: \(voiceType.rawValue)")
        
        // 检查API密钥
        guard let azureKey = azureKey else {
            logger.error("❌ 未配置Azure语音服务密钥")
            completion(.failure(.invalidURL))
            return
        }
        
        // 构建请求URL
        let urlString = "https://\(azureRegion).tts.speech.microsoft.com/cognitiveservices/v1"
        guard let url = URL(string: urlString) else {
            logger.error("❌ 无效的Azure语音服务URL")
            completion(.failure(.invalidURL))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 添加请求头
        request.addValue(azureKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.addValue(UUID().uuidString, forHTTPHeaderField: "X-RequestId")
        
        // 构建SSML
        let ssml = buildSSML(text: text, voiceName: voiceType.azureVoiceName)
        request.httpBody = ssml.data(using: .utf8)
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 处理错误
            if let error = error {
                self.logger.error("❌ 语音合成请求失败: \(error.localizedDescription)")
                completion(.failure(.requestFailed(error)))
                return
            }
            
            // 检查响应
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("❌ 无效的响应")
                completion(.failure(.invalidResponse))
                return
            }
            
            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200...299:
                // 成功响应
                guard let data = data, !data.isEmpty else {
                    self.logger.error("❌ 响应数据为空")
                    completion(.failure(.invalidResponse))
                    return
                }
                
                // 保存音频文件
                do {
                    let audioURL = try self.saveAudioData(data)
                    self.logger.info("✅ 语音合成成功，保存到: \(audioURL.path)")
                    completion(.success(audioURL))
                } catch {
                    self.logger.error("❌ 保存音频文件失败: \(error.localizedDescription)")
                    completion(.failure(.requestFailed(error)))
                }
                
            case 401:
                // 未授权
                self.logger.error("❌ Azure语音服务未授权 (401)")
                completion(.failure(.serverError(httpResponse.statusCode, "未授权，请检查API密钥")))
                
            case 429:
                // 请求频率限制
                self.logger.error("⚠️ 请求频率超限 (429)")
                completion(.failure(.rateLimited))
                
            default:
                // 其他错误
                let message = String(data: data ?? Data(), encoding: .utf8) ?? "未知错误"
                self.logger.error("❌ Azure语音服务错误 (\(httpResponse.statusCode)): \(message)")
                completion(.failure(.serverError(httpResponse.statusCode, message)))
            }
        }
        
        // 启动任务
        task.resume()
    }
    
    // MARK: - 异步语音合成
    @available(iOS 13.0, *)
    func synthesizeSpeech(
        text: String,
        voiceType: VoiceType
    ) async -> Result<URL, APIError> {
        return await withCheckedContinuation { continuation in
            synthesizeSpeech(text: text, voiceType: voiceType) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 音频播放
    func playAudio(from url: URL, completion: @escaping (Bool) -> Void) {
        logger.info("开始播放音频: \(url.lastPathComponent)")
        
        do {
            // 停止当前播放
            stopAudio()
            
            // 创建新的播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // 设置完成回调
            self.playbackCompletion = completion
            
            // 开始播放
            if audioPlayer?.play() == true {
                logger.info("✅ 音频播放开始")
            } else {
                logger.error("❌ 音频播放失败")
                completion(false)
            }
        } catch {
            logger.error("❌ 创建音频播放器失败: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // 停止音频播放
    func stopAudio() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            logger.info("⏹️ 音频播放停止")
        }
        audioPlayer = nil
        playbackCompletion = nil
    }
    
    // MARK: - 辅助方法
    
    // 播放完成回调
    private var playbackCompletion: ((Bool) -> Void)?
    
    // 设置音频会话
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            logger.info("✅ 音频会话设置成功")
        } catch {
            logger.error("❌ 设置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // 构建SSML
    private func buildSSML(text: String, voiceName: String) -> String {
        // 转义特殊字符
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        
        // 构建SSML
        let ssml = """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN">
            <voice name="\(voiceName)">
                <prosody rate="0.9" pitch="0">
                    \(escapedText)
                </prosody>
            </voice>
        </speak>
        """
        
        return ssml
    }
    
    // 保存音频数据
    private func saveAudioData(_ data: Data) throws -> URL {
        // 创建文件名
        let fileName = "speech_\(UUID().uuidString).mp3"
        
        // 获取缓存目录
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let audioDirectory = cacheDirectory.appendingPathComponent("audio", isDirectory: true)
        
        // 创建音频目录（如果不存在）
        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }
        
        // 创建文件URL
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        
        // 写入数据
        try data.write(to: fileURL)
        
        return fileURL
    }
}

// MARK: - AVAudioPlayerDelegate
extension SpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("🎵 音频播放完成，成功: \(flag)")
        
        // 调用完成回调
        DispatchQueue.main.async { [weak self] in
            self?.playbackCompletion?(flag)
            self?.playbackCompletion = nil
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            logger.error("❌ 音频解码错误: \(error.localizedDescription)")
        } else {
            logger.error("❌ 未知音频解码错误")
        }
        
        // 调用完成回调
        DispatchQueue.main.async { [weak self] in
            self?.playbackCompletion?(false)
            self?.playbackCompletion = nil
        }
    }
} 