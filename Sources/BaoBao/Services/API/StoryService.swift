import Foundation
import os.log

// MARK: - 故事主题
enum StoryTheme: String, CaseIterable {
    case magic = "魔法世界"
    case animals = "动物朋友"
    case space = "太空冒险"
    case princess = "公主王子"
    case ocean = "海底世界"
    case dinosaur = "恐龙时代"
    
    var description: String {
        switch self {
        case .magic:
            return "创造一个充满魔法的奇幻故事"
        case .animals:
            return "与可爱的动物朋友一起冒险"
        case .space:
            return "探索浩瀚宇宙的奇妙旅程"
        case .princess:
            return "童话般的王子公主故事"
        case .ocean:
            return "探索神秘的海底世界"
        case .dinosaur:
            return "穿越时空，与恐龙共舞"
        }
    }
    
    var icon: String {
        switch self {
        case .magic:
            return "dragon"
        case .animals:
            return "paw"
        case .space:
            return "airplane"
        case .princess:
            return "crown"
        case .ocean:
            return "water"
        case .dinosaur:
            return "dinosaur"
        }
    }
}

// MARK: - 故事长度
enum StoryLength: String, CaseIterable {
    case short = "短篇"
    case medium = "中篇"
    case long = "长篇"
    
    var description: String {
        switch self {
        case .short:
            return "约3分钟 · 适合睡前快速阅读"
        case .medium:
            return "约5分钟 · 标准故事长度"
        case .long:
            return "约8分钟 · 详细的冒险故事"
        }
    }
    
    var tokenCount: Int {
        switch self {
        case .short:
            return 500
        case .medium:
            return 800
        case .long:
            return 1200
        }
    }
}

// MARK: - 语音类型
enum VoiceType: String, CaseIterable {
    case female = "萍萍阿姨"
    case male = "大树叔叔"
    case child = "豆豆"
    
    var description: String {
        switch self {
        case .female:
            return "温柔亲切的女声，适合睡前故事"
        case .male:
            return "稳重有力的男声，适合冒险故事"
        case .child:
            return "活泼可爱的儿童声音"
        }
    }
    
    var azureVoiceName: String {
        switch self {
        case .female:
            return "zh-CN-XiaoxiaoNeural"
        case .male:
            return "zh-CN-YunxiNeural"
        case .child:
            return "zh-CN-XiaoyiNeural"
        }
    }
}

// MARK: - 故事模型
struct Story: Codable {
    let id: String
    let title: String
    let content: String
    let theme: String
    let childName: String
    let createdAt: Date
    var audioURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, theme, childName, createdAt, audioURL
    }
    
    init(id: String = UUID().uuidString, 
         title: String, 
         content: String, 
         theme: String, 
         childName: String, 
         createdAt: Date = Date(), 
         audioURL: URL? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.theme = theme
        self.childName = childName
        self.createdAt = createdAt
        self.audioURL = audioURL
    }
}

// MARK: - DeepSeek API响应模型
struct DeepSeekResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - 故事服务
class StoryService {
    // 单例模式
    static let shared = StoryService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "story-service")
    
    // API服务
    private let apiService = APIService.shared
    
    // 私有初始化方法
    private init() {
        logger.info("故事服务初始化完成")
    }
    
    // MARK: - 生成故事
    func generateStory(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String],
        length: StoryLength,
        completion: @escaping (Result<Story, APIError>) -> Void
    ) {
        logger.info("开始生成故事，主题: \(theme.rawValue)，主角: \(childName)，年龄: \(childAge)")
        
        // 构建提示词
        let prompt = buildPrompt(
            theme: theme,
            childName: childName,
            childAge: childAge,
            childInterests: childInterests,
            length: length
        )
        
        // 构建请求参数
        let parameters: [String: Any] = [
            "prompt": prompt,
            "max_tokens": length.tokenCount,
            "temperature": 0.7,
            "top_p": 0.9,
            "frequency_penalty": 0.5,
            "presence_penalty": 0.5
        ]
        
        // 发送请求
        apiService.request(
            endpoint: "story/generate",
            method: "POST",
            parameters: parameters
        ) { [weak self] (result: Result<DeepSeekResponse, APIError>) in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                // 处理响应
                if let content = response.choices.first?.message.content {
                    // 解析故事内容
                    let (title, storyContent) = self.parseStoryContent(content)
                    
                    // 创建故事对象
                    let story = Story(
                        title: title,
                        content: storyContent,
                        theme: theme.rawValue,
                        childName: childName
                    )
                    
                    self.logger.info("✅ 故事生成成功: \(title)")
                    completion(.success(story))
                } else {
                    self.logger.error("❌ 故事内容为空")
                    completion(.failure(.invalidResponse))
                }
                
            case .failure(let error):
                self.logger.error("❌ 故事生成失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 异步生成故事
    @available(iOS 13.0, *)
    func generateStory(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String],
        length: StoryLength
    ) async -> Result<Story, APIError> {
        // 使用指数退避重试
        return await apiService.retryWithExponentialBackoff { [weak self] in
            guard let self = self else {
                return .failure(.unknown)
            }
            
            // 构建提示词
            let prompt = self.buildPrompt(
                theme: theme,
                childName: childName,
                childAge: childAge,
                childInterests: childInterests,
                length: length
            )
            
            // 构建请求参数
            let parameters: [String: Any] = [
                "prompt": prompt,
                "max_tokens": length.tokenCount,
                "temperature": 0.7,
                "top_p": 0.9,
                "frequency_penalty": 0.5,
                "presence_penalty": 0.5
            ]
            
            // 发送请求
            let result: Result<DeepSeekResponse, APIError> = await self.apiService.request(
                endpoint: "story/generate",
                method: "POST",
                parameters: parameters
            )
            
            switch result {
            case .success(let response):
                // 处理响应
                if let content = response.choices.first?.message.content {
                    // 解析故事内容
                    let (title, storyContent) = self.parseStoryContent(content)
                    
                    // 创建故事对象
                    let story = Story(
                        title: title,
                        content: storyContent,
                        theme: theme.rawValue,
                        childName: childName
                    )
                    
                    self.logger.info("✅ 故事生成成功: \(title)")
                    return .success(story)
                } else {
                    self.logger.error("❌ 故事内容为空")
                    return .failure(.invalidResponse)
                }
                
            case .failure(let error):
                self.logger.error("❌ 故事生成失败: \(error.localizedDescription)")
                return .failure(error)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 构建提示词
    private func buildPrompt(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String],
        length: StoryLength
    ) -> String {
        // 安全指令
        let safetyInstructions = "[严禁暴力][适合5岁以下儿童][主角名称：\(childName)]"
        
        // 兴趣爱好
        let interestsText = childInterests.isEmpty ? "" : "，爱好：\(childInterests.joined(separator: "、"))"
        
        // 构建完整提示词
        let prompt = """
        \(safetyInstructions)
        生成以{\(childName)}为主角的童话，题材：\(theme.rawValue)，年龄：\(childAge)岁\(interestsText)
        
        要求：
        1. 故事必须有一个明确的标题，格式为"# 标题"
        2. 故事内容必须适合\(childAge)岁儿童阅读，使用简单易懂的语言
        3. 故事应该有教育意义，传递积极向上的价值观
        4. 故事长度应为\(length.rawValue)（约\(length.tokenCount)字）
        5. 故事中的主角名字必须是\(childName)
        6. 故事情节要生动有趣，有起承转合
        7. 故事结尾必须圆满、温馨
        """
        
        logger.debug("📝 生成的提示词: \(prompt)")
        return prompt
    }
    
    // 解析故事内容
    private func parseStoryContent(_ content: String) -> (title: String, content: String) {
        // 尝试提取标题
        let titlePattern = "# (.*?)\\n"
        let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [])
        let contentRange = NSRange(content.startIndex..., in: content)
        
        var title = "未命名故事"
        var storyContent = content
        
        // 提取标题
        if let match = titleRegex?.firstMatch(in: content, options: [], range: contentRange),
           let titleRange = Range(match.range(at: 1), in: content) {
            title = String(content[titleRange])
            
            // 从内容中移除标题行
            if let fullTitleRange = Range(match.range, in: content) {
                storyContent = String(content.replacingCharacters(in: fullTitleRange, with: ""))
            }
        }
        
        // 清理内容
        storyContent = storyContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (title, storyContent)
    }
} 