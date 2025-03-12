import Foundation
import os.log

// MARK: - 配置管理器
class BaoBaoConfigurationManager {
    // 单例实例
    static let shared = BaoBaoConfigurationManager()
    
    // 日志记录器
    private let logger = Logger(subsystem: "com.baobao.config", category: "ConfigurationManager")
    
    // 配置字典
    private var configDict: [String: Any] = [:]
    
    // DeepSeek API密钥
    var deepseekApiKey: String {
        return string(forKey: "DEEPSEEK_API_KEY") ?? ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    }
    
    // Azure语音服务密钥
    var azureSpeechKey: String {
        return string(forKey: "AZURE_SPEECH_KEY") ?? ProcessInfo.processInfo.environment["AZURE_SPEECH_KEY"] ?? ""
    }
    
    // Azure语音服务区域
    var azureSpeechRegion: String {
        return string(forKey: "AZURE_SPEECH_REGION") ?? "eastasia"
    }
    
    // 私有初始化方法
    private init() {
        loadConfiguration()
    }
    
    // 重新加载配置
    func reloadConfiguration() {
        loadConfiguration()
    }
    
    // 加载配置
    private func loadConfiguration() {
        // 查找配置文件路径
        guard let configPath = findConfigFile() else {
            logger.error("无法找到配置文件")
            return
        }
        
        // 加载配置文件
        do {
            let configData = try Data(contentsOf: configPath)
            let plist = try PropertyListSerialization.propertyList(from: configData, options: [], format: nil)
            
            if let dict = plist as? [String: Any] {
                configDict = dict
                logger.info("成功加载配置文件: \(configPath.path)")
            } else {
                logger.error("配置文件格式无效")
            }
        } catch {
            logger.error("加载配置文件失败: \(error.localizedDescription)")
        }
    }
    
    // 查找配置文件
    private func findConfigFile() -> URL? {
        // 首先检查应用包中的配置文件
        if let bundlePath = Bundle.main.path(forResource: "Config", ofType: "plist") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // 然后检查文档目录中的配置文件
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsConfigPath = documentsDirectory.appendingPathComponent("Config.plist")
        
        if FileManager.default.fileExists(atPath: documentsConfigPath.path) {
            return documentsConfigPath
        }
        
        // 如果在开发环境中，尝试查找项目根目录中的配置文件
        #if DEBUG
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectConfigPath = currentDirectoryURL.appendingPathComponent("Config.plist")
        
        if FileManager.default.fileExists(atPath: projectConfigPath.path) {
            return projectConfigPath
        }
        
        // 尝试查找用户文档目录下的配置文件
        let userDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let homeConfigPath = userDocumentsDirectory.appendingPathComponent("baobao/Config.plist")
        
        if FileManager.default.fileExists(atPath: homeConfigPath.path) {
            return homeConfigPath
        }
        #endif
        
        return nil
    }
    
    // 获取字符串值
    private func string(forKey key: String) -> String? {
        return configDict[key] as? String
    }
    
    // 获取整数值
    private func integer(forKey key: String) -> Int? {
        return configDict[key] as? Int
    }
    
    // 获取浮点值
    private func double(forKey key: String) -> Double? {
        return configDict[key] as? Double
    }
    
    // 获取布尔值
    private func bool(forKey key: String) -> Bool? {
        return configDict[key] as? Bool
    }
}

// MARK: - 故事服务错误
enum StoryServiceError: Error {
    case generationFailed
    case invalidParameters
    case networkError(Error)
    case apiError(Int, String)
    case rateLimited
    case timeout
    case parseError
    case unknown
    case apiKeyNotConfigured
    
    var localizedDescription: String {
        switch self {
        case .generationFailed:
            return "故事生成失败"
        case .invalidParameters:
            return "参数无效"
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
        case .apiKeyNotConfigured:
            return "DeepSeek API密钥未配置"
        }
    }
}

// MARK: - 故事服务
class StoryService {
    // MARK: - 属性
    
    /// 单例实例
    static let shared = StoryService()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.StoryService", category: "StoryService")
    
    // 数据服务
    private let dataService = DataService.shared
    
    // 重试配置
    private let maxRetries = 3
    private let initialRetryDelay: TimeInterval = 2.0
    
    // 私有初始化方法
    private init() {
        logger.info("故事服务初始化完成")
    }
    
    // MARK: - 故事生成
    
    /// 生成故事
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 孩子名字
    ///   - childAge: 孩子年龄
    ///   - childInterests: 孩子兴趣爱好
    ///   - length: 故事长度
    ///   - completion: 完成回调
    func generateStory(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String] = [],
        length: StoryLength,
        completion: @escaping (Result<Story, Error>) -> Void
    ) {
        // 验证参数
        guard !childName.isEmpty, childAge > 0 else {
            completion(.failure(StoryServiceError.invalidParameters))
            return
        }
        
        // 构建提示词
        let prompt = buildPrompt(
            theme: theme,
            childName: childName,
            childAge: childAge,
            childInterests: childInterests,
            length: length
        )
        
        // 调用API生成故事
        generateStoryWithRetry(prompt: prompt, childName: childName, childAge: childAge, retryCount: 0, completion: completion)
    }
    
    /// 构建提示词
    private func buildPrompt(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String],
        length: StoryLength
    ) -> String {
        // 安全指令
        let safetyInstructions = "[严禁暴力][适合\(childAge)岁以下儿童][主角名称：\(childName)]"
        
        // 兴趣爱好
        let interestsText = childInterests.isEmpty ? "" : "，喜欢\(childInterests.joined(separator: "、"))"
        
        // 故事长度
        let wordCount: Int
        switch length {
        case .short:
            wordCount = 300
        case .medium:
            wordCount = 600
        case .long:
            wordCount = 1000
        }
        
        // 构建完整提示词
        return """
        \(safetyInstructions)
        请创作一个适合\(childAge)岁儿童的\(theme.rawValue)主题故事，主角是\(childName)\(interestsText)。
        故事应该有趣、积极向上，包含适当的教育意义，字数约\(wordCount)字。
        请使用简单易懂的语言，适合\(childAge)岁儿童理解。
        故事需要有明确的开始、中间和结尾。
        请以故事标题开始，格式为"## 《故事标题》"。
        """
    }
    
    /// 使用重试机制生成故事
    private func generateStoryWithRetry(
        prompt: String,
        childName: String,
        childAge: Int,
        retryCount: Int = 0,
        completion: @escaping (Result<Story, Error>) -> Void
    ) {
        // 检查API密钥
        let apiKey = BaoBaoConfigurationManager.shared.deepseekApiKey
        guard !apiKey.isEmpty else {
            logger.error("❌ DeepSeek API密钥未配置")
            completion(.failure(StoryServiceError.apiKeyNotConfigured))
            return
        }
        
        let apiBaseURL = "https://api.deepseek.com/v1/chat/completions"
        
        // 创建URL请求
        guard let url = URL(string: apiBaseURL) else {
            logger.error("❌ 无效的API URL")
            completion(.failure(StoryServiceError.invalidParameters))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // 60秒超时
        
        // 设置请求头
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 设置请求体
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2000,
            "temperature": 0.7
        ]
        
        // 序列化请求体
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            logger.error("❌ 序列化请求体失败: \(error.localizedDescription)")
            completion(.failure(StoryServiceError.invalidParameters))
            return
        }
        
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
                        self.generateStoryWithRetry(
                            prompt: prompt,
                            childName: childName,
                            childAge: childAge,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                
                completion(.failure(StoryServiceError.networkError(error)))
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("❌ 无效的HTTP响应")
                completion(.failure(StoryServiceError.unknown))
                return
            }
            
            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200:
                // 成功响应
                guard let data = data else {
                    self.logger.error("❌ 响应数据为空")
                    completion(.failure(StoryServiceError.parseError))
                    return
                }
                
                // 解析响应
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let message = choices.first?["message"] as? [String: Any],
                          let content = message["content"] as? String else {
                        self.logger.error("❌ 解析响应失败")
                        completion(.failure(StoryServiceError.parseError))
                        return
                    }
                    
                    // 提取标题和内容
                    let (title, storyContent) = self.extractTitleAndContent(from: content)
                    
                    // 创建故事对象
                    let story = Story(
                        title: title,
                        content: storyContent,
                        theme: self.extractThemeFromPrompt(prompt),
                        childName: childName,
                        childAge: childAge
                    )
                    
                    self.logger.info("✅ 故事生成成功: \(title)")
                    completion(.success(story))
                    
                } catch {
                    self.logger.error("❌ JSON解析错误: \(error.localizedDescription)")
                    completion(.failure(StoryServiceError.parseError))
                }
                
            case 401:
                self.logger.error("❌ API认证失败 (401)")
                completion(.failure(StoryServiceError.apiError(401, "API密钥无效")))
                
            case 429:
                self.logger.error("❌ API请求频率限制 (429)")
                
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
                        self.generateStoryWithRetry(
                            prompt: prompt,
                            childName: childName,
                            childAge: childAge,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                
                completion(.failure(StoryServiceError.rateLimited))
                
            default:
                // 其他错误
                var errorMessage = "未知错误"
                if let data = data, let message = String(data: data, encoding: .utf8) {
                    errorMessage = message
                }
                
                self.logger.error("❌ API错误 (\(httpResponse.statusCode)): \(errorMessage)")
                completion(.failure(StoryServiceError.apiError(httpResponse.statusCode, errorMessage)))
            }
        }
        
        // 启动任务
        task.resume()
        logger.info("🚀 发送故事生成请求")
    }
    
    // MARK: - 辅助方法
    
    /// 从故事内容中提取标题和正文
    private func extractTitleAndContent(from rawContent: String) -> (String, String) {
        // 尝试提取标题
        let titlePattern = "##\\s*《(.+?)》"
        let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [])
        let titleRange = NSRange(rawContent.startIndex..., in: rawContent)
        
        var title = "未命名故事"
        var content = rawContent
        
        // 如果找到标题，提取并从内容中移除
        if let titleMatch = titleRegex?.firstMatch(in: rawContent, options: [], range: titleRange),
           let titleRange = Range(titleMatch.range(at: 1), in: rawContent) {
            title = String(rawContent[titleRange])
            
            // 移除标题行
            if let fullTitleRange = Range(titleMatch.range, in: rawContent) {
                let afterTitle = rawContent.index(after: rawContent.index(fullTitleRange.upperBound, offsetBy: -1))
                content = String(rawContent[afterTitle...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return (title, content)
    }
    
    /// 从提示词中提取孩子名字
    private func extractChildName(from prompt: String) -> String {
        // 尝试匹配"主角名称：xxx"或"主角是xxx"
        let patterns = [
            "主角名称：([^\\]\\[]+)",
            "主角是([^，。,\\.]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: prompt, options: [], range: NSRange(prompt.startIndex..., in: prompt)),
               let range = Range(match.range(at: 1), in: prompt) {
                return String(prompt[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return "未知主角"
    }
    
    /// 从提示词中提取主题
    private func extractThemeFromPrompt(_ prompt: String) -> String {
        // 尝试匹配"主题：xxx"或"故事是xxx"
        let patterns = [
            "主题：([^\\]\\[]+)",
            "故事是([^，。,\\.]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: prompt, options: [], range: NSRange(prompt.startIndex..., in: prompt)),
               let range = Range(match.range(at: 1), in: prompt) {
                return String(prompt[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return "未知主题"
    }
} 