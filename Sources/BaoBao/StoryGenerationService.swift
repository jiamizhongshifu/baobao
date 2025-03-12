import Foundation
import os.log

/// 故事生成错误类型
enum StoryGenerationError: Error {
    case apiKeyMissing
    case requestFailed(Error)
    case invalidResponse
    case serverOverloaded
    case rateLimited
    case contentFiltered(String)
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .apiKeyMissing:
            return "缺少DeepSeek API密钥"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的API响应"
        case .serverOverloaded:
            return "服务器过载，请稍后再试"
        case .rateLimited:
            return "请求频率过高，请稍后再试"
        case .contentFiltered(let reason):
            return "内容被过滤: \(reason)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

/// 故事生成服务
class StoryGenerationService {
    /// 共享实例
    static let shared = StoryGenerationService()
    
    /// 故事生成响应模型
    struct StoryGenerationResponse: Codable {
        let title: String
        let content: String
    }
    
    /// 服务错误
    enum ServiceError: Error {
        case missingApiKey
        case apiError(statusCode: Int)
        case parsingError
        case emptyResponseData
        case unexpectedResponseType
        case retryLimitExceeded
    }
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "StoryGenerationService")
    
    /// 请求队列
    private let requestQueue = DispatchQueue(label: "com.example.baobao.storygeneration", qos: .userInitiated)
    
    /// 故事缓存
    private var storyCache: [String: StoryGenerationResponse] = [:]
    
    /// 缓存过期时间（秒）
    private var cacheExpiry: TimeInterval {
        return Double(ConfigurationManager.shared.getInt(forKey: "CACHE_EXPIRY_DAYS", defaultValue: 7) * 24 * 60 * 60)
    }
    
    /// 缓存最后更新时间
    private var cacheLastUpdate: [String: Date] = [:]
    
    /// 私有初始化方法
    private init() {
        logger.info("🚀 StoryGenerationService初始化")
    }
    
    /// 生成故事
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 孩子名字
    ///   - preferences: 喜好（可选）
    ///   - useCache: 是否使用缓存
    ///   - completion: 完成回调
    func generateStory(theme: String, childName: String, preferences: [String]? = nil, useCache: Bool = true, completion: @escaping (Result<StoryGenerationResponse, Error>) -> Void) {
        // 生成缓存键
        let cacheKey = "\(theme)_\(childName)_\(preferences?.joined(separator: ",") ?? "")"
        
        // 检查缓存
        if useCache, let cachedStory = storyCache[cacheKey], let lastUpdate = cacheLastUpdate[cacheKey], Date().timeIntervalSince(lastUpdate) < cacheExpiry {
            logger.info("📋 使用缓存的故事，主题: \(theme)")
            completion(.success(cachedStory))
            return
        }
        
        // 异步处理
        requestQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("🖋️ 开始生成故事，主题: \(theme)")
            
            // 最大重试次数
            let maxRetries = ConfigurationManager.shared.getInt(forKey: "MAX_STORY_RETRIES", defaultValue: 3)
            var currentRetry = 0
            
            // 重试逻辑
            func attemptStoryGeneration() {
                currentRetry += 1
                self.logger.info("🔄 尝试生成故事 (尝试 \(currentRetry)/\(maxRetries))")
                
                self.makeStoryGenerationRequest(theme: theme, childName: childName, preferences: preferences) { result in
                    switch result {
                    case .success(let response):
                        // 预处理内容
                        let processedResponse = self.processStoryResponse(response)
                        
                        // 更新缓存
                        self.storyCache[cacheKey] = processedResponse
                        self.cacheLastUpdate[cacheKey] = Date()
                        
                        DispatchQueue.main.async {
                            self.logger.info("✅ 故事生成成功并缓存")
                            completion(.success(processedResponse))
                        }
                        
                    case .failure(let error):
                        self.logger.error("❌ 故事生成失败: \(error.localizedDescription)")
                        
                        // 检查是否应该重试
                        if currentRetry < maxRetries {
                            self.logger.info("🔄 准备重试 (\(currentRetry)/\(maxRetries))")
                            
                            // 延迟后重试，指数退避
                            let delay = Double(pow(2.0, Double(currentRetry - 1))) * 1.0
                            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                                attemptStoryGeneration()
                            }
                        } else {
                            self.logger.error("❌ 超过最大重试次数")
                            
                            // 检查是否使用本地备用方案
                            if ConfigurationManager.shared.getBool(forKey: "USE_LOCAL_FALLBACK", defaultValue: true) {
                                self.logger.info("📚 使用本地备用故事")
                                let fallbackStory = self.getFallbackStory(theme: theme, childName: childName)
                                DispatchQueue.main.async {
                                    completion(.success(fallbackStory))
                                }
                            } else {
                                DispatchQueue.main.async {
                                    completion(.failure(ServiceError.retryLimitExceeded))
                                }
                            }
                        }
                    }
                }
            }
            
            // 开始首次尝试
            attemptStoryGeneration()
        }
    }
    
    /// 预处理故事响应
    /// - Parameter response: 原始响应
    /// - Returns: 处理后的响应
    private func processStoryResponse(_ response: StoryGenerationResponse) -> StoryGenerationResponse {
        // 处理标题，去除"标题："前缀
        var title = response.title
        if title.hasPrefix("标题：") {
            title = String(title.dropFirst(3))
        }
        
        // 处理内容，确保格式统一
        var content = response.content
        
        // 移除潜在的模型添加的额外格式
        if content.contains("```") {
            content = content.replacingOccurrences(of: "```", with: "")
        }
        
        // 移除多余空行
        while content.contains("\n\n\n") {
            content = content.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        // 针对儿童安全的内容过滤
        if ConfigurationManager.shared.getBool(forKey: "CONTENT_SAFETY_ENABLED", defaultValue: true) {
            content = filterInappropriateContent(content)
        }
        
        return StoryGenerationResponse(title: title, content: content)
    }
    
    /// 过滤不适合儿童的内容
    /// - Parameter content: 原始内容
    /// - Returns: 过滤后的内容
    private func filterInappropriateContent(_ content: String) -> String {
        // 不适合儿童的词汇列表
        let inappropriateWords = [
            "死", "亡", "血", "杀", "吓人", "恐怖", "可怕", "鬼", "伤害", "打架", "暴力", 
            "枪", "刀", "武器", "毒药", "自杀", "伤心", "痛苦", "孤独", "绝望"
        ]
        
        // 替换词汇映射
        let replacements = [
            "死": "睡着", "亡": "离开", "血": "汁", "杀": "赶走", "吓人": "惊讶", 
            "恐怖": "奇怪", "可怕": "神奇", "鬼": "精灵", "伤害": "碰到", "打架": "玩耍", 
            "暴力": "热闹", "枪": "棍", "刀": "棒", "武器": "工具", "毒药": "药水", 
            "自杀": "迷路", "伤心": "难过", "痛苦": "不舒服", "孤独": "安静", "绝望": "困难"
        ]
        
        var filtered = content
        
        // 替换不适合的词汇
        for (word, replacement) in replacements {
            filtered = filtered.replacingOccurrences(of: word, with: replacement)
        }
        
        return filtered
    }
    
    /// 获取备用故事
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 孩子名字
    /// - Returns: 备用故事响应
    private func getFallbackStory(theme: String, childName: String) -> StoryGenerationResponse {
        // 根据主题选择不同的备用故事
        var title = "小\(childName)的冒险"
        var content = "从前，有一个叫\(childName)的小朋友，非常喜欢探索世界。"
        
        switch theme.lowercased() {
        case _ where theme.contains("动物") || theme.contains("森林"):
            title = "\(childName)和森林朋友们"
            content = """
            从前，有一个名叫\(childName)的小朋友，非常喜欢小动物。
            
            一天，\(childName)在花园里发现了一只小松鼠。小松鼠看起来很着急，似乎遇到了麻烦。
            
            "你怎么了，小松鼠？"  \(childName)轻声问道。
            
            小松鼠说："我的松果不见了，冬天快到了，我需要松果过冬。"
            
            \(childName)决定帮助小松鼠找回松果。他们一起在森林里寻找，遇到了许多其他动物朋友——友好的兔子、聪明的猫头鹰和勤劳的蜜蜂。
            
            每个动物都给他们提供了线索。最后，他们在一棵大橡树下找到了松果，原来是小刺猬误以为那是自己的食物。
            
            \(childName)帮助大家解释清楚了误会，小刺猬感到很抱歉，并主动帮助小松鼠收集更多的松果。
            
            从那以后，\(childName)和森林里的动物们成为了好朋友，他们经常一起玩耍，分享快乐的时光。
            
            这个故事告诉我们，友谊和互相帮助是多么重要。
            """
            
        case _ where theme.contains("太空") || theme.contains("星星") || theme.contains("宇宙"):
            title = "\(childName)的星际探险"
            content = """
            从前，有一个名叫\(childName)的小朋友，非常喜欢仰望星空。
            
            一天晚上，\(childName)在窗边看星星时，发现一颗星星特别亮。忽然，那颗星星变成了一艘小小的宇宙飞船，降落在了\(childName)的窗台上。
            
            一个友好的星际旅行者从飞船中走出来，他叫星星使者。
            
            "你好，\(childName)，"星星使者微笑着说，"我来自遥远的星星王国，我们正在寻找银河系最友好的小朋友。"
            
            星星使者邀请\(childName)一起乘坐宇宙飞船，去探索宇宙的奥秘。\(childName)兴奋地同意了。
            
            他们一起飞越了彩虹星云，拜访了月球上的兔子家族，还在土星环上滑行。每到一个地方，\(childName)都会学到新的知识，结交新的朋友。
            
            旅行结束时，星星使者送给\(childName)一颗会发光的小星星作为纪念。"只要你看着这颗星星，就能记得我们的友谊，"星星使者说。
            
            \(childName)回到地球后，虽然没人相信这次奇妙的旅行，但每当夜晚来临，窗台上的小星星就会亮起来，提醒\(childName)宇宙中还有许多奇妙的事情等待发现。
            
            这个故事告诉我们，保持好奇心和友善的心态，世界将为我们打开无限可能。
            """
            
        case _ where theme.contains("海洋") || theme.contains("海底"):
            title = "\(childName)的海底历险记"
            content = """
            从前，有一个名叫\(childName)的小朋友，很喜欢海洋和海洋生物。
            
            一天，\(childName)在海边玩耍时，发现了一个闪闪发光的贝壳。当\(childName)捡起贝壳时，一阵神奇的蓝光闪过，\(childName)突然能够在水下呼吸了！
            
            \(childName)惊奇地潜入海底，遇见了一条友好的小丑鱼。
            
            "欢迎来到海底世界！"小丑鱼开心地说，"我叫波波，能带你参观我们的家。"
            
            波波带着\(childName)游览了五彩斑斓的珊瑚礁，拜访了聪明的章鱼博士，还参加了海龟奶奶的100岁生日派对。
            
            但是派对中途，大家突然发现海龟奶奶珍贵的生日礼物——一颗珍珠不见了！海底居民们都很着急。
            
            \(childName)和波波决定帮忙寻找。通过仔细观察和询问，他们发现了一些线索，最终在一群水母的领地找到了珍珠。原来是调皮的水母宝宝误把珍珠当作玩具带走了。
            
            \(childName)帮助海龟奶奶找回了珍珠，所有海底居民都为\(childName)的聪明才智和乐于助人欢呼。
            
            回家的时候，波波送给\(childName)一颗小珍珠作为纪念。虽然\(childName)不能永远待在海底，但这段美妙的友谊将永远保存在心中。
            
            这个故事告诉我们，帮助他人会带来快乐，而友谊能跨越不同的世界。
            """
            
        default:
            title = "\(childName)的奇妙冒险"
            content = """
            从前，有一个名叫\(childName)的小朋友，总是充满好奇心和想象力。
            
            一天，\(childName)在家里的阁楼上发现了一本神奇的书。当\(childName)翻开书页，一阵金色的光芒闪过，\(childName)被带入了书中的奇幻世界！
            
            在这个世界里，树木会说话，河流会唱歌，还有许多神奇的生物。\(childName)遇见了一只会飞的小狐狸，它自我介绍说："我叫闪电，是这个世界的向导。"
            
            闪电告诉\(childName)，这个世界正面临危机：魔法彩虹消失了，导致整个世界失去了色彩和快乐。
            
            "只有纯真的孩子才能找回彩虹，"闪电说，"我们相信你能帮助我们！"
            
            \(childName)和闪电踏上了寻找彩虹的旅程。他们穿越了说谎者森林，那里的树木总是说反话；他们横跨了忘忧湖，湖水能让人忘记烦恼；最后他们到达了静音山谷，那里没有任何声音。
            
            在山谷的中心，\(childName)发现了一面镜子。当\(childName)对着镜子微笑时，镜子反射出的不仅是笑容，还有美丽的彩虹光芒！原来，彩虹一直藏在每个人的笑容里。
            
            \(childName)把这个发现告诉了世界的居民们，他们开始互相微笑，很快，彩虹重新出现在天空中，世界恢复了色彩和欢笑。
            
           作为感谢，闪电送给\(childName)一片魔法羽毛，说："只要你想回来，就握住这片羽毛并闭上眼睛。"
            
            \(childName)回到现实世界后，发现那本神奇的书消失了，但口袋里的魔法羽毛证明了这不是一场梦。从那以后，每当\(childName)微笑，都能在心中看到彩虹。
            
            这个故事告诉我们，微笑和快乐能创造出生活中的彩虹。
            """
        }
        
        return StoryGenerationResponse(title: title, content: content)
    }
    
    /// 生成故事
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 宝宝名称
    ///   - age: 宝宝年龄
    ///   - interests: 宝宝兴趣
    ///   - length: 故事长度（长篇、中篇、短篇）
    /// - Returns: 生成的故事
    func generateStory(theme: String, childName: String, age: Int, interests: [String], length: String) async throws -> Story {
        // 检查API Key
        guard !apiKey.isEmpty else {
            throw StoryGenerationError.apiKeyMissing
        }
        
        // 构建提示词，包含安全指令
        let prompt = buildPrompt(theme: theme, childName: childName, age: age, interests: interests, length: length)
        
        // 准备请求参数
        let parameters: [String: Any] = [
            "prompt": prompt,
            "max_tokens": getMaxTokens(for: length),
            "temperature": 0.7,
            "safety_level": ConfigurationManager.shared.contentSafetyEnabled ? "strict" : "medium"
        ]
        
        // 发送请求，使用指数退避重试机制
        let (data, response) = try await sendRequestWithRetry(parameters: parameters)
        
        // 解析响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoryGenerationError.invalidResponse
        }
        
        // 检查HTTP状态码
        switch httpResponse.statusCode {
        case 200:
            // 成功
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["text"] as? String else {
                throw StoryGenerationError.invalidResponse
            }
            
            // 检查内容是否被过滤
            if ConfigurationManager.shared.contentSafetyEnabled &&
               (content.contains("很抱歉，我无法生成这个故事") || content.contains("内容不适合")) {
                throw StoryGenerationError.contentFiltered("故事内容不符合安全规范")
        }
        
        // 创建故事对象
        return Story(
            id: UUID().uuidString,
            title: "\(childName)的\(theme)冒险",
            content: content,
            theme: theme,
            childName: childName,
            createdAt: Date()
        )
        case 400:
            // 请求错误
            throw StoryGenerationError.invalidResponse
        case 401:
            // 认证错误
            throw StoryGenerationError.apiKeyMissing
        case 429:
            // 请求过多
            throw StoryGenerationError.rateLimited
        case 500, 502, 503, 504:
            // 服务器错误
            throw StoryGenerationError.serverOverloaded
        default:
            // 其他错误
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw StoryGenerationError.unknown(errorMessage)
        }
    }
    
    /// 构建提示词
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 宝宝名称
    ///   - age: 宝宝年龄
    ///   - interests: 宝宝兴趣
    ///   - length: 故事长度
    /// - Returns: 完整的提示词
    private func buildPrompt(theme: String, childName: String, age: Int, interests: [String], length: String) -> String {
        // 安全指令前缀
        let safetyPrefix = "[严禁暴力][适合5岁以下儿童][主角名称：\(childName)]"
        
        // 主要提示词
        let mainPrompt = """
        请为\(age)岁的小朋友写一个关于\(theme)的\(length)故事。
        主角是\(childName)，喜欢\(interests.joined(separator: "、"))。
        故事需要有趣、富有教育意义，适合\(age)岁儿童阅读，并且包含以下元素：
        1. 一个吸引人的开头，引起孩子的好奇心
        2. 一个明确的主题或教育目的
        3. 适当的情节发展，不要太复杂
        4. 一个积极、有教育意义的结局
        5. 如果可能，融入\(childName)的兴趣爱好
        
        故事应该使用简单易懂的语言，适合\(age)岁孩子的理解水平。
        避免任何可能让孩子害怕的内容，保持友好、温暖的语调。
        """
        
        // 完整提示词
        return "\(safetyPrefix)\n\n\(mainPrompt)"
    }
    
    /// 根据故事长度获取最大token数
    /// - Parameter length: 故事长度（长篇、中篇、短篇）
    /// - Returns: 最大token数
    private func getMaxTokens(for length: String) -> Int {
        switch length {
        case "长篇":
            return 2000
        case "中篇":
            return 1000
        case "短篇":
            return 500
        default:
            return 1000 // 默认中篇
        }
    }
    
    /// 发送请求，支持指数退避重试
    /// - Parameter parameters: 请求参数
    /// - Returns: 响应数据和HTTP响应
    private func sendRequestWithRetry(parameters: [String: Any]) async throws -> (Data, URLResponse) {
        var currentRetry = 0
        var currentDelay = initialRetryDelay
        
        while true {
            do {
                // 准备请求
                var request = URLRequest(url: URL(string: baseURL)!)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("strict", forHTTPHeaderField: "X-Safety-Level")
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                
                // 发送请求
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 检查是否需要重试
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 429 || (httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599) {
                    // 需要重试
                    if currentRetry >= maxRetries {
                        // 达到最大重试次数
                        logger.error("❌ 达到最大重试次数，放弃请求")
                        throw StoryGenerationError.rateLimited
                    }
                    
                    // 计算退避时间
                    currentRetry += 1
                    logger.info("⏳ API请求受限，第\(currentRetry)次重试，延迟\(currentDelay)秒")
                    
                    // 等待
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    
                    // 增加退避时间（指数增长）
                    currentDelay *= 2
                    continue
                }
                
                // 成功获取响应
                return (data, response)
            } catch {
                // 检查是否是网络错误，需要重试
                if currentRetry < maxRetries {
                    currentRetry += 1
                    logger.info("⏳ 网络错误，第\(currentRetry)次重试，延迟\(currentDelay)秒: \(error.localizedDescription)")
                    
                    // 等待
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    
                    // 增加退避时间（指数增长）
                    currentDelay *= 2
                    continue
                }
                
                // 达到最大重试次数
                logger.error("❌ 达到最大重试次数，放弃请求: \(error.localizedDescription)")
                throw StoryGenerationError.requestFailed(error)
            }
        }
    }
    
    /// 生成提示词
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 孩子名字
    ///   - preferences: 喜好（可选）
    /// - Returns: 优化的提示词
    private func generatePrompt(theme: String, childName: String, preferences: [String]? = nil) -> String {
        // 获取故事长度配置
        let storyLength: String
        switch ConfigurationManager.shared.getString(forKey: "STORY_LENGTH", defaultValue: "medium") {
        case "short":
            storyLength = "短故事，约300-500字"
        case "long":
            storyLength = "长故事，约1000-1500字"
        default: // medium
            storyLength = "中等长度故事，约600-800字"
        }
        
        // 将用户偏好组合成字符串
        let preferencesText = preferences?.isEmpty == false ? "，特别喜欢" + preferences!.joined(separator: "、") : ""
        
        // 构建优化的提示词
        let prompt = """
        你是一位专业的儿童故事作家，请为一位名叫\(childName)的3-8岁小朋友创作一个有关"\(theme)"的\(storyLength)。
        
        任务要求：
        1. 请先提供一个简短有趣的标题，格式为"标题：xxx"，然后空两行开始正文
        2. 故事中要把\(childName)作为主角\(preferencesText)
        3. 故事应该包含清晰的开头、中间和结尾
        4. 故事应充满想象力、趣味性和教育意义
        5. 在故事结尾融入一个积极的生活小道理
        
        故事结构：
        - 开头：引入主角\(childName)和故事背景
        - 中间：主角遇到问题并尝试解决
        - 结尾：问题得到解决，\(childName)学到了重要的一课
        
        语言要求：
        - 使用简单易懂的中文，适合3-8岁儿童
        - 避免复杂的词汇和句式
        - 使用生动、形象的描述
        - 对话要自然、简短
        - 避免任何可能让儿童感到害怕或不安的内容

        输出格式：
        标题：xxx

        故事正文...
        """
        
        return prompt
    }
    
    /// 发起故事生成请求
    /// - Parameters:
    ///   - theme: 故事主题
    ///   - childName: 孩子名字
    ///   - preferences: 喜好（可选）
    ///   - completion: 完成回调
    private func makeStoryGenerationRequest(theme: String, childName: String, preferences: [String]? = nil, completion: @escaping (Result<StoryGenerationResponse, Error>) -> Void) {
        // 获取API密钥
        guard let apiKey = ConfigurationManager.shared.getString(forKey: "DEEPSEEK_API_KEY", defaultValue: "").nilIfEmpty else {
            logger.error("❌ 缺少DeepSeek API密钥")
            completion(.failure(ServiceError.missingApiKey))
            return
        }
        
        // 构建API URL
        let urlString = "https://api.deepseek.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])))
            return
        }
        
        // 生成优化的提示词
        let prompt = generatePrompt(theme: theme, childName: childName, preferences: preferences)
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "你是一位专业的儿童故事作家，擅长创作适合3-8岁儿童的短篇故事。你的故事总是积极向上，富有想象力，并且包含简单的生活道理。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,  // 控制创造性，0.7提供良好的平衡
            "top_p": 0.9,        // 核采样，保持相对一致性
            "max_tokens": 2000,   // 足够长度的响应
            "presence_penalty": 0.2,  // 轻微鼓励不重复
            "frequency_penalty": 0.3  // 适度降低频繁词语的使用
        ]
        
        // 序列化请求体
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求数据"])))
            return
        }
        
        // 构建HTTP请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // 记录请求开始时间
        let startTime = Date()
        logger.info("🔄 开始API请求...")
        
        // 发起请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // 计算请求耗时
            let requestDuration = Date().timeIntervalSince(startTime)
            self.logger.info("⏱️ API请求耗时: \(String(format: "%.2f", requestDuration))秒")
            
            // 处理网络错误
            if let error = error {
                self.logger.error("❌ 网络错误: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 检查HTTP响应状态
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    self.logger.error("❌ API错误: 状态码 \(httpResponse.statusCode)")
                    completion(.failure(ServiceError.apiError(statusCode: httpResponse.statusCode)))
                    return
                }
            }
            
            // 检查响应数据
            guard let data = data, !data.isEmpty else {
                self.logger.error("❌ 返回空数据")
                completion(.failure(ServiceError.emptyResponseData))
                return
            }
            
            // 响应调试
            if ConfigurationManager.shared.getBool(forKey: "DEBUG_MODE", defaultValue: false) {
                if let responseString = String(data: data, encoding: .utf8) {
                    self.logger.debug("📝 API响应数据: \(responseString)")
                }
            }
            
            // 解析响应
            do {
                // 尝试解析为标准DeepSeek响应格式
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // 从内容中提取标题和正文
                    let components = content.components(separatedBy: "\n\n")
                    var title = "未命名故事"
                    var storyContent = content
                    
                    if components.count > 1 {
                        let titleLine = components[0]
                        if titleLine.lowercased().contains("标题") {
                            title = titleLine.replacingOccurrences(of: "标题：", with: "")
                                            .replacingOccurrences(of: "标题:", with: "")
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            storyContent = components.dropFirst().joined(separator: "\n\n")
                        }
                    }
                    
                    let response = StoryGenerationResponse(title: title, content: storyContent)
                    self.logger.info("✅ 故事生成成功：\(title)")
                    completion(.success(response))
                } else {
                    // 尝试使用Codable解析
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(StoryGenerationResponse.self, from: data)
                    self.logger.info("✅ 故事生成成功：\(response.title)")
                    completion(.success(response))
                }
            } catch {
                self.logger.error("❌ 解析错误: \(error.localizedDescription)")
                
                // 尝试读取API错误信息
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorInfo = errorJson["error"] as? [String: Any],
                   let message = errorInfo["message"] as? String {
                    self.logger.error("📌 API错误详情: \(message)")
                }
                
                completion(.failure(ServiceError.parsingError))
            }
        }
        
        task.resume()
    }
}

// 故事生成响应扩展 - 便于解析API结果
extension StoryGenerationService.StoryGenerationResponse {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            // 尝试直接解析
            if let choices = try? container.nestedContainer(keyedBy: ChoicesKeys.self, forKey: .choices),
               var content = try? choices.decode(String.self, forKey: .content) {
                
                // 从内容中提取标题和正文
                if content.contains("标题：") {
                    let components = content.components(separatedBy: "\n\n")
                    if components.count > 1 {
                        let titleLine = components[0]
                        title = titleLine.replacingOccurrences(of: "标题：", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        content = components.dropFirst().joined(separator: "\n\n")
                    } else {
                        title = "未命名故事"
                    }
                } else {
                    title = "未命名故事"
                }
                
                self.title = title
                self.content = content
                return
            }
            
            // 尝试从choices.message.content解析
            if let choices = try? container.nestedContainer(keyedBy: ChoicesKeys.self, forKey: .choices),
               let message = try? choices.nestedContainer(keyedBy: MessageKeys.self, forKey: .message),
               var content = try? message.decode(String.self, forKey: .content) {
                
                // 从内容中提取标题和正文
                if content.contains("标题：") {
                    let components = content.components(separatedBy: "\n\n")
                    if components.count > 1 {
                        let titleLine = components[0]
                        title = titleLine.replacingOccurrences(of: "标题：", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        content = components.dropFirst().joined(separator: "\n\n")
                    } else {
                        title = "未命名故事"
                    }
                } else {
                    title = "未命名故事"
                }
                
                self.title = title
                self.content = content
                return
            }
            
            // 如果上述方法都失败，则尝试从完整结构解析
            let choices = try container.nestedContainer(keyedBy: ChoicesKeys.self, forKey: .choices)
            let choicesArray = try choices.decode([Choice].self, forKey: .choicesArray)
            
            if let firstChoice = choicesArray.first,
               let message = firstChoice.message,
               var content = message.content {
                
                // 从内容中提取标题和正文
                if content.contains("标题：") {
                    let components = content.components(separatedBy: "\n\n")
                    if components.count > 1 {
                        let titleLine = components[0]
                        title = titleLine.replacingOccurrences(of: "标题：", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        content = components.dropFirst().joined(separator: "\n\n")
                    } else {
                        title = "未命名故事"
                    }
                } else {
                    title = "未命名故事"
                }
                
                self.title = title
                self.content = content
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Unable to decode story content from any known format"
                    )
                )
            }
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Failed to decode story response: \(error.localizedDescription)"
                )
            )
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case choices
    }
    
    enum ChoicesKeys: String, CodingKey {
        case content
        case message
        case choicesArray = "choices"
    }
    
    enum MessageKeys: String, CodingKey {
        case content
    }
    
    struct Choice: Codable {
        let message: Message?
    }
    
    struct Message: Codable {
        let content: String?
    }
} 