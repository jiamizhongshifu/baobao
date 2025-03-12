import Foundation
import os.log
import Combine

/// 故事服务错误类型
enum StoryServiceError: Error {
    case generationFailed
    case invalidParameters
    case networkError(Error)
    case apiError(Int, String)
    case rateLimited
    case timeout
    case parseError
    case offlineMode
    case noCache
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .generationFailed:
            return "故事生成失败"
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
        case .parseError:
            return "解析响应失败"
        case .offlineMode:
            return "当前处于离线模式"
        case .noCache:
            return "离线模式下无缓存可用"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

/// 故事主题
enum StoryTheme: String, CaseIterable {
    case space = "太空冒险"
    case ocean = "海洋探险"
    case forest = "森林奇遇"
    case dinosaur = "恐龙世界"
    case fairy = "童话王国"
    
    var description: String {
        switch self {
        case .space:
            return "在浩瀚的宇宙中探索未知的星球和奇妙的太空生物"
        case .ocean:
            return "潜入深海，探索神秘的海底世界和海洋生物"
        case .forest:
            return "在神秘的森林中遇见会说话的动物和神奇的植物"
        case .dinosaur:
            return "穿越时空，回到恐龙时代，与各种恐龙互动"
        case .fairy:
            return "在充满魔法的童话王国中，遇见王子公主和神奇生物"
        }
    }
}

/// 故事长度
enum StoryLength: String, CaseIterable {
    case short = "短篇"
    case medium = "中篇"
    case long = "长篇"
    
    var wordCount: ClosedRange<Int> {
        switch self {
        case .short:
            return 300...500
        case .medium:
            return 500...800
        case .long:
            return 800...1200
        }
    }
    
    var description: String {
        switch self {
        case .short:
            return "约300-500字，适合3-5分钟的阅读时间"
        case .medium:
            return "约500-800字，适合5-8分钟的阅读时间"
        case .long:
            return "约800-1200字，适合8-12分钟的阅读时间"
        }
    }
}

/// 故事生成状态
enum StoryGenerationStatus {
    case idle
    case generating
    case success(String)
    case failure(StoryServiceError)
}

/// 故事服务
class StoryService {
    // MARK: - 属性
    
    /// 单例实例
    static let shared = StoryService()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.story", category: "StoryService")
    
    /// 配置管理器
    private let configManager = ConfigurationManager.shared
    
    /// 缓存管理器
    private let cacheManager = CacheManager.shared
    
    /// 网络管理器
    private let networkManager = NetworkManager.shared
    
    /// 当前生成状态
    @Published private(set) var generationStatus: StoryGenerationStatus = .idle
    
    /// 生成状态发布者
    var generationStatusPublisher: AnyPublisher<StoryGenerationStatus, Never> {
        return $generationStatus.eraseToAnyPublisher()
    }
    
    /// 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    private init() {
        // 监听网络状态变化
        networkManager.statusPublisher
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
    }
    
    // MARK: - 公共方法
    
    /// 生成故事
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - characterName: 主角名字
    ///   - length: 故事长度
    ///   - forceRefresh: 是否强制刷新（忽略缓存）
    ///   - completion: 完成回调
    func generateStory(theme: StoryTheme, characterName: String, length: StoryLength, forceRefresh: Bool = false, completion: @escaping (Result<String, StoryServiceError>) -> Void) {
        // 更新状态
        generationStatus = .generating
        
        // 验证参数
        guard !characterName.isEmpty else {
            let error = StoryServiceError.invalidParameters
            generationStatus = .failure(error)
            completion(.failure(error))
            return
        }
        
        // 生成缓存键
        let cacheKey = generateCacheKey(theme: theme, characterName: characterName, length: length)
        
        // 检查缓存（如果不强制刷新）
        if !forceRefresh, let cachedStory = retrieveFromCache(cacheKey: cacheKey) {
            logger.info("从缓存中获取故事: \(cacheKey)")
            generationStatus = .success(cachedStory)
            completion(.success(cachedStory))
            return
        }
        
        // 检查网络状态
        if !networkManager.canPerformNetworkRequest() {
            logger.warning("无法生成故事：当前处于离线模式或网络不可用")
            
            // 在离线模式下，尝试从缓存获取（即使请求了强制刷新）
            if let cachedStory = retrieveFromCache(cacheKey: cacheKey) {
                logger.info("离线模式：从缓存中获取故事: \(cacheKey)")
                generationStatus = .success(cachedStory)
                completion(.success(cachedStory))
                return
            }
            
            // 如果没有缓存，返回错误
            let error = StoryServiceError.offlineMode
            generationStatus = .failure(error)
            completion(.failure(error))
            return
        }
        
        // 构建提示词
        let prompt = buildPrompt(theme: theme, characterName: characterName, length: length)
        
        // 使用重试机制生成故事
        generateStoryWithRetry(prompt: prompt, maxRetries: configManager.maxStoryRetries) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let story):
                // 缓存故事
                self.saveToCache(story: story, cacheKey: cacheKey)
                self.generationStatus = .success(story)
                completion(.success(story))
            case .failure(let error):
                self.generationStatus = .failure(error)
                completion(.failure(error))
            }
        }
    }
    
    /// 预生成故事（用于预缓存）
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - characterName: 主角名字
    ///   - length: 故事长度
    func preGenerateStory(theme: StoryTheme, characterName: String, length: StoryLength) {
        // 生成缓存键
        let cacheKey = generateCacheKey(theme: theme, characterName: characterName, length: length)
        
        // 检查缓存是否已存在
        if retrieveFromCache(cacheKey: cacheKey) != nil {
            logger.info("故事已缓存，跳过预生成: \(cacheKey)")
            return
        }
        
        // 检查网络状态
        if !networkManager.canPerformNetworkRequest() {
            logger.warning("无法预生成故事：当前处于离线模式或网络不可用")
            return
        }
        
        // 构建提示词
        let prompt = buildPrompt(theme: theme, characterName: characterName, length: length)
        
        // 使用重试机制生成故事
        generateStoryWithRetry(prompt: prompt, maxRetries: configManager.maxStoryRetries) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let story):
                // 缓存故事
                self.saveToCache(story: story, cacheKey: cacheKey)
                self.logger.info("故事预生成成功: \(cacheKey)")
            case .failure(let error):
                self.logger.error("故事预生成失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 清除故事缓存
    func clearStoryCache() {
        cacheManager.clearCache(type: .story)
        logger.info("故事缓存已清除")
    }
    
    /// 获取故事缓存大小
    /// - Returns: 缓存大小（字节）
    func getStoryCacheSize() -> Int64 {
        return cacheManager.cacheSize(type: .story)
    }
    
    // MARK: - 私有方法
    
    /// 构建提示词
    private func buildPrompt(theme: StoryTheme, characterName: String, length: StoryLength) -> String {
        return """
        请为5岁的孩子创作一个有关\(theme.rawValue)的故事，故事应该：
        1. 主角是一个叫\(characterName)的小孩
        2. 包含一个有趣的问题和解决方案
        3. 长度在\(length.wordCount.lowerBound)-\(length.wordCount.upperBound)字之间
        4. 使用简单的语言，适合5岁孩子理解
        5. 包含一些有趣的声音效果
        6. 有一个积极向上的结局
        7. 故事开头请直接写上标题
        
        请直接给出故事内容，不要包含任何前言或说明。
        """
    }
    
    /// 生成缓存键
    private func generateCacheKey(theme: StoryTheme, characterName: String, length: StoryLength) -> String {
        let key = "\(theme.rawValue)_\(characterName)_\(length.rawValue)"
        return key.replacingOccurrences(of: " ", with: "_")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
    
    /// 从缓存中获取故事
    private func retrieveFromCache(cacheKey: String) -> String? {
        return cacheManager.textFromCache(forKey: cacheKey, type: .story)
    }
    
    /// 保存故事到缓存
    private func saveToCache(story: String, cacheKey: String) {
        _ = cacheManager.saveTextToCache(text: story, forKey: cacheKey, type: .story)
    }
    
    /// 使用重试机制生成故事
    private func generateStoryWithRetry(prompt: String, maxRetries: Int, attempt: Int = 0, completion: @escaping (Result<String, StoryServiceError>) -> Void) {
        // 构建请求URL
        guard let url = URL(string: configManager.storyGenerationEndpoint) else {
            completion(.failure(.invalidParameters))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置请求头
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(configManager.deepseekApiKey)", forHTTPHeaderField: "Authorization")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "你是一个专业的儿童故事作家，擅长创作适合幼儿的有趣故事。请确保故事内容安全、积极、有教育意义。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        // 转换为JSON数据
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(.invalidParameters))
            return
        }
        
        request.httpBody = jsonData
        
        // 设置超时时间
        request.timeoutInterval = 30.0
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 处理网络错误
            if let error = error {
                self.logger.error("网络错误: \(error.localizedDescription)")
                
                // 检查是否需要重试
                if attempt < maxRetries {
                    // 计算延迟时间（指数退避）
                    let delay = pow(Double(self.configManager.retryDelayBaseSeconds), Double(attempt + 1))
                    
                    self.logger.info("重试生成故事 (尝试 \(attempt + 1)/\(maxRetries))，延迟 \(delay) 秒")
                    
                    // 延迟后重试
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.generateStoryWithRetry(prompt: prompt, maxRetries: maxRetries, attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                
                completion(.failure(.networkError(error)))
                return
            }
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown(NSError(domain: "StoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"]))))
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
                
                // 检查是否需要重试
                if attempt < maxRetries {
                    // 计算延迟时间（指数退避）
                    let delay = pow(Double(self.configManager.retryDelayBaseSeconds), Double(attempt + 1)) * 2.0
                    
                    self.logger.info("重试生成故事 (尝试 \(attempt + 1)/\(maxRetries))，延迟 \(delay) 秒")
                    
                    // 延迟后重试
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.generateStoryWithRetry(prompt: prompt, maxRetries: maxRetries, attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                
                completion(.failure(.rateLimited))
                return
            case 500, 502, 503, 504:
                self.logger.error("服务器错误: \(httpResponse.statusCode)")
                
                // 检查是否需要重试
                if attempt < maxRetries {
                    // 计算延迟时间（指数退避）
                    let delay = pow(Double(self.configManager.retryDelayBaseSeconds), Double(attempt + 1)) * 2.0
                    
                    self.logger.info("重试生成故事 (尝试 \(attempt + 1)/\(maxRetries))，延迟 \(delay) 秒")
                    
                    // 延迟后重试
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.generateStoryWithRetry(prompt: prompt, maxRetries: maxRetries, attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                
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
            
            // 解析响应
            guard let data = data else {
                completion(.failure(.parseError))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // 提取故事内容
                    let story = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    self.logger.info("故事生成成功，字数: \(story.count)")
                    completion(.success(story))
                } else {
                    self.logger.error("无法解析API响应")
                    completion(.failure(.parseError))
                }
            } catch {
                self.logger.error("解析API响应失败: \(error.localizedDescription)")
                completion(.failure(.parseError))
            }
        }
        
        task.resume()
    }
}

/// 配置管理器（占位实现，实际项目中应该有完整的实现）
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    var deepseekApiKey: String {
        return ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }
    
    var storyGenerationEndpoint: String {
        return ProcessInfo.processInfo.environment["STORY_GENERATION_ENDPOINT"] ?? "https://api.deepseek.com/v1/chat/completions"
    }
    
    var maxStoryRetries: Int {
        return Int(ProcessInfo.processInfo.environment["MAX_STORY_RETRIES"] ?? "3") ?? 3
    }
    
    var retryDelayBaseSeconds: Int {
        return Int(ProcessInfo.processInfo.environment["RETRY_DELAY_BASE_SECONDS"] ?? "1") ?? 1
    }
    
    private init() {}
} 