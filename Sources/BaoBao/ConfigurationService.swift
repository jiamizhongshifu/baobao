import Foundation
import os.log

class ConfigurationService {
    static let shared = ConfigurationService()
    private let logger = Logger(subsystem: "com.example.baobao", category: "ConfigurationService")
    
    // MARK: - API Keys
    private(set) var openAIKey: String
    
    // MARK: - 语音合成配置
    struct VoiceConfig {
        let identifier: String
        let name: String
        let language: String
        let gender: String
        let rate: Float
        let pitch: Float
        let volume: Float
    }
    
    let voices: [String: VoiceConfig] = [
        "萍萍阿姨": VoiceConfig(
            identifier: "com.apple.ttsbundle.Ting-Ting-compact",
            name: "萍萍阿姨",
            language: "zh-CN",
            gender: "female",
            rate: 0.5,
            pitch: 1.1,
            volume: 1.0
        ),
        "大卫叔叔": VoiceConfig(
            identifier: "com.apple.ttsbundle.Daniel-compact",
            name: "大卫叔叔",
            language: "en-US",
            gender: "male",
            rate: 0.45,
            pitch: 0.9,
            volume: 1.0
        )
    ]
    
    // MARK: - 故事生成配置
    struct StoryConfig {
        let model: String
        let temperature: Double
        let maxTokens: [String: Int]
        let systemPrompt: String
    }
    
    let storyConfig = StoryConfig(
        model: "gpt-4",
        temperature: 0.7,
        maxTokens: [
            "短篇": 500,
            "中篇": 1000,
            "长篇": 2000
        ],
        systemPrompt: """
        你是一个专业的儿童故事作家，擅长创作有趣且富有教育意义的故事。
        你需要：
        1. 使用适合儿童年龄的简单语言
        2. 创造生动有趣的情节
        3. 融入积极向上的价值观
        4. 根据儿童兴趣定制故事内容
        5. 确保故事具有教育意义
        """
    )
    
    // MARK: - 音频设置
    let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 2,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    private init() {
        // 从配置文件或环境变量加载 API 密钥
        self.openAIKey = loadAPIKey()
        logger.info("🔑 配置服务初始化完成")
    }
    
    private func loadAPIKey() -> String {
        // 1. 首先尝试从配置文件加载
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["OpenAIAPIKey"] as? String {
            return key
        }
        
        // 2. 如果配置文件不存在，尝试从环境变量加载
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return key
        }
        
        // 3. 如果都没有，从钥匙串读取
        if let key = KeychainService.shared.getValue(for: "OpenAIAPIKey") {
            return key
        }
        
        logger.error("❌ 未找到 OpenAI API Key")
        return ""
    }
    
    func updateOpenAIKey(_ key: String) {
        self.openAIKey = key
        // 保存到钥匙串
        KeychainService.shared.setValue(key, for: "OpenAIAPIKey")
        logger.info("✅ OpenAI API Key 已更新")
    }
} 