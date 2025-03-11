import Foundation

class StoryGenerationService {
    static let shared = StoryGenerationService()
    private let logger = Logger(subsystem: "com.example.baobao", category: "StoryGenerationService")
    
    // OpenAI API 配置
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4"
    
    private init() {
        // 从环境变量或配置文件读取 API Key
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    
    func generateStory(theme: String, childName: String, age: Int, interests: [String], length: String) async throws -> Story {
        // 构建提示词
        let prompt = """
        请为一个\(age)岁的小朋友写一个关于\(theme)的\(length)故事。
        这个小朋友叫\(childName)，喜欢\(interests.joined(separator: "、"))。
        故事要有趣、富有教育意义，适合\(age)岁儿童阅读。
        故事需要包含以下元素：
        1. 一个吸引人的开头
        2. 一个明确的主题
        3. 适当的情节发展
        4. 一个有教育意义的结局
        请用中文写作，使用简单的语言。
        """
        
        // 准备请求
        let parameters: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "你是一个专业的儿童故事作家，擅长创作有趣且富有教育意义的故事。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": length == "长篇" ? 2000 : (length == "中篇" ? 1000 : 500)
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.example.baobao",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "故事生成失败"])
        }
        
        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "com.example.baobao",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "响应解析失败"])
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
    }
} 