import Foundation
import os.log

/// 数据初始化工具，负责在应用启动时初始化数据
class DataInitializer {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = DataInitializer()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.data", category: "DataInitializer")
    
    /// 数据管理器
    private let dataManager = DataManager.shared
    
    /// 故事仓库
    private let storyRepository = StoryRepository.shared
    
    /// 孩子仓库
    private let childRepository = ChildRepository.shared
    
    /// 设置仓库
    private let settingsRepository = SettingsRepository.shared
    
    /// 数据迁移工具
    private let migrationTool = DataMigrationTool.shared
    
    /// 是否已初始化
    private var isInitialized = false
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 初始化数据
    func initializeData(completion: @escaping (Bool) -> Void) {
        guard !isInitialized else {
            logger.info("数据已初始化，跳过")
            completion(true)
            return
        }
        
        logger.info("开始初始化数据")
        
        // 检查是否需要迁移数据
        if needsMigration() {
            logger.info("需要迁移数据")
            
            // 执行数据迁移
            migrationTool.performMigration { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.logger.info("数据迁移成功")
                    self.createSampleDataIfNeeded { sampleSuccess in
                        self.isInitialized = true
                        completion(sampleSuccess)
                    }
                } else {
                    self.logger.error("数据迁移失败")
                    completion(false)
                }
            }
        } else {
            logger.info("不需要迁移数据")
            
            // 创建示例数据（如果需要）
            createSampleDataIfNeeded { [weak self] success in
                guard let self = self else { return }
                
                self.isInitialized = true
                completion(success)
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 检查是否需要迁移数据
    private func needsMigration() -> Bool {
        // 这里应该实现检查是否存在旧版数据的逻辑
        // 由于我们没有实际的旧版数据，这里返回false
        return false
    }
    
    /// 创建示例数据（如果需要）
    private func createSampleDataIfNeeded(completion: @escaping (Bool) -> Void) {
        // 检查是否已有数据
        let children = childRepository.getAllChildren()
        let stories = storyRepository.getAllStories()
        
        if children.isEmpty && stories.isEmpty {
            logger.info("没有现有数据，创建示例数据")
            createSampleData(completion: completion)
        } else {
            logger.info("已有数据，跳过创建示例数据")
            completion(true)
        }
    }
    
    /// 创建示例数据
    private func createSampleData(completion: @escaping (Bool) -> Void) {
        // 创建示例孩子
        let child = ChildModel(
            name: "小明",
            age: 5,
            gender: "男",
            interests: ["恐龙", "太空", "海洋"]
        )
        
        childRepository.saveChild(child)
        
        // 创建示例故事
        let spaceStory = StoryModel(
            title: "小明的太空冒险",
            content: "从前，有一个叫小明的小男孩，他非常喜欢太空。有一天，他在后院玩耍时，发现了一艘小小的宇宙飞船。飞船的门突然打开了，小明好奇地走了进去。飞船立刻启动，带着小明飞向了太空。\n\n在太空中，小明看到了美丽的星星、行星和彗星。他甚至遇到了一群友好的外星人，他们邀请小明一起玩耍。小明和外星朋友们一起探索了月球，在那里他们跳得比地球上高多了。\n\n玩累了之后，外星朋友们送小明回到了地球。小明回到家，迫不及待地告诉爸爸妈妈他的太空冒险。爸爸妈妈笑着听完，以为这只是小明编的故事。但小明知道，这是真实发生的奇妙冒险。\n\n从那以后，每当小明仰望星空，他都会想起他的外星朋友们，期待着下一次太空冒险。",
            theme: "太空冒险",
            characterName: "小明",
            isFavorite: true,
            readCount: 3,
            child: child
        )
        
        let oceanStory = StoryModel(
            title: "小明的海底探险",
            content: "小明最喜欢的地方是海洋馆，他总是趴在大水族箱前，看着五彩斑斓的鱼儿游来游去。有一天，小明在海洋馆参观时，一条会说话的小丑鱼游到了玻璃前。\n\n"嘿，小明，想不想来海底世界玩一玩？"小丑鱼问道。小明惊讶地点点头。小丑鱼吹出一个泡泡，泡泡包住了小明，带着他潜入了海底世界。\n\n在海底，小明变成了一条小鱼，他可以自由地在水中游动。小丑鱼带着小明参观了美丽的珊瑚礁，那里有各种各样的海洋生物。他们和海龟赛跑，和海豚跳舞，还参观了章鱼老师的海底学校。\n\n天色渐晚，小丑鱼送小明回到了海洋馆。泡泡一破，小明又变回了人类。"下次再来玩哦！"小丑鱼说完，就消失在鱼群中。小明开心地向爸爸妈妈跑去，迫不及待地想告诉他们自己的海底冒险。",
            theme: "海洋探险",
            characterName: "小明",
            isFavorite: false,
            readCount: 1,
            child: child
        )
        
        storyRepository.saveStory(spaceStory)
        storyRepository.saveStory(oceanStory)
        
        logger.info("示例数据创建成功")
        completion(true)
    }
} 