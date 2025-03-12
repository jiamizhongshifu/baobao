import Foundation
import os.log

// MARK: - 故事服务错误
enum StoryServiceError: Error {
    case generationFailed
    case invalidParameters
    case networkError
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .generationFailed:
            return "故事生成失败"
        case .invalidParameters:
            return "参数无效"
        case .networkError:
            return "网络错误"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - 故事服务
class StoryService {
    // 单例模式
    static let shared = StoryService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "story-service")
    
    // 数据服务
    private let dataService = DataService.shared
    
    // 私有初始化方法
    private init() {
        logger.info("故事服务初始化完成")
    }
    
    // MARK: - 故事生成
    
    // 生成故事
    func generateStory(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String] = [],
        length: StoryLength,
        completion: @escaping (Result<Story, Error>) -> Void
    ) {
        logger.info("开始生成故事：主题=\(theme.rawValue)，宝宝=\(childName)，年龄=\(childAge)，长度=\(length.rawValue)")
        
        // 异步执行
        DispatchQueue.global().async {
            // 模拟网络延迟
            sleep(2)
            
            // 生成故事
            let story = self.mockGenerateStory(
                theme: theme,
                childName: childName,
                childAge: childAge,
                childInterests: childInterests,
                length: length
            )
            
            // 主线程回调
            DispatchQueue.main.async {
                // 保存故事
                self.dataService.addStory(story)
                
                self.logger.info("✅ 故事生成成功：\(story.title)")
                completion(.success(story))
            }
        }
    }
    
    // MARK: - 模拟故事生成（开发用）
    
    // 模拟生成故事
    private func mockGenerateStory(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String],
        length: StoryLength
    ) -> Story {
        // 根据主题和兴趣生成故事标题
        let title = generateStoryTitle(theme: theme, childInterests: childInterests)
        
        // 根据主题、宝宝名称和年龄生成故事内容
        let content = generateStoryContent(
            theme: theme,
            childName: childName,
            childAge: childAge,
            childInterests: childInterests,
            length: length
        )
        
        // 创建故事对象
        return Story(
            title: title,
            content: content,
            theme: theme.rawValue,
            childName: childName,
            childAge: childAge
        )
    }
    
    // 生成故事标题
    private func generateStoryTitle(theme: StoryTheme, childInterests: [String]) -> String {
        // 根据主题选择标题模板
        let templates: [String]
        
        switch theme {
        case .space:
            templates = [
                "太空冒险：寻找星星的旅程",
                "银河历险记",
                "宇宙奇遇",
                "月球上的秘密"
            ]
        case .fairy:
            templates = [
                "魔法森林的秘密",
                "小精灵的礼物",
                "童话王国历险记",
                "魔法城堡的宝藏"
            ]
        case .animal:
            templates = [
                "动物王国历险记",
                "森林里的朋友们",
                "小狮子的勇气",
                "温柔的大象"
            ]
        case .dinosaur:
            templates = [
                "恐龙世界历险记",
                "霸王龙的秘密",
                "迷失在恐龙时代",
                "小三角龙的勇气"
            ]
        case .ocean:
            templates = [
                "海底探险",
                "寻找神秘的海洋宝藏",
                "美人鱼的秘密",
                "深海历险记"
            ]
        case .fantasy:
            templates = [
                "魔法世界历险记",
                "神秘王国的勇士",
                "龙与魔法师",
                "奇幻森林的秘密"
            ]
        }
        
        // 随机选择标题
        return templates.randomElement() ?? "奇妙冒险"
    }
    
    // 生成故事内容
    private func generateStoryContent(
        theme: StoryTheme,
        childName: String,
        childAge: Int,
        childInterests: [String],
        length: StoryLength
    ) -> String {
        // 根据主题选择故事开头
        var content = ""
        
        // 添加故事开头
        switch theme {
        case .space:
            content += "很久很久以前，在一个遥远的星球上，有一个名叫\(childName)的小朋友。\(childName)今年\(childAge)岁了，非常喜欢探索宇宙的奥秘。"
        case .fairy:
            content += "从前，在一个美丽的童话王国里，住着一个名叫\(childName)的小朋友。\(childName)今年\(childAge)岁了，拥有一颗善良的心。"
        case .animal:
            content += "在一片神奇的森林里，有一个名叫\(childName)的小朋友。\(childName)今年\(childAge)岁了，非常喜欢各种小动物。"
        case .dinosaur:
            content += "很久以前，在恐龙生活的时代，有一个名叫\(childName)的小朋友。\(childName)今年\(childAge)岁了，对恐龙充满了好奇。"
        case .ocean:
            content += "在蔚蓝的大海深处，有一个名叫\(childName)的小朋友。\(childName)今年\(childAge)岁了，喜欢探索海洋的秘密。"
        case .fantasy:
            content += "在一个充满魔法的世界里，有一个名叫\(childName)的小朋友。\(childName)今年\(childAge)岁了，拥有非凡的勇气和智慧。"
        }
        
        // 根据兴趣添加故事细节
        if !childInterests.isEmpty {
            let interest = childInterests.randomElement() ?? "冒险"
            content += "\n\n\(childName)特别喜欢\(interest)。每天，\(childName)都会花时间研究关于\(interest)的知识。"
        }
        
        // 添加故事主体
        content += "\n\n有一天，\(childName)决定开始一次新的冒险。"
        
        // 根据长度添加更多内容
        switch length {
        case .short:
            content += "\n\n在冒险的过程中，\(childName)遇到了很多有趣的事情。\(childName)学会了勇敢面对困难，也交到了新朋友。这次冒险让\(childName)成长了不少。"
        case .medium, .long:
            content += """
            
            
            冒险开始了，\(childName)充满了期待。途中，\(childName)遇到了一些困难，但是凭借着聪明才智和勇气，\(childName)一一克服了这些困难。
            
            在冒险的过程中，\(childName)还交到了新朋友。他们一起合作，互相帮助，共同完成了这次冒险。
            
            这次冒险让\(childName)明白了友情和勇气的重要性。\(childName)变得更加勇敢和自信，也学会了如何与他人合作。
            """
        }
        
        // 添加更多内容（仅限中长篇）
        if length == .long {
            content += """
            
            
            冒险结束后，\(childName)回到了家中。\(childName)把冒险的经历告诉了家人和朋友，大家都对\(childName)的勇气和智慧感到惊讶和佩服。
            
            这次冒险不仅让\(childName)学到了很多知识，还让\(childName)明白了生活中最重要的是什么。\(childName)决定，以后要继续探索更多未知的领域，创造更多美好的回忆。
            """
        }
        
        // 添加故事结尾
        content += "\n\n这是一个美好的故事，\(childName)期待着下一次冒险的到来。"
        
        return content
    }
} 