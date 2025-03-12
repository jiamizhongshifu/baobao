import Foundation
import os.log
import CoreData

// MARK: - API数据服务
class APIDataService {
    // 单例模式
    static let shared = APIDataService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "APIDataService")
    
    // 文件管理器
    private let fileManager = FileManager.default
    
    // 数据目录
    private let dataDirectory: URL
    
    // 宝宝数据文件
    private let childrenFile: URL
    
    // 故事数据文件
    private let storiesFile: URL
    
    // 宝宝数据
    private(set) var children: [Child] = []
    
    // 故事数据
    private(set) var stories: [Story] = []
    
    // 私有初始化方法
    private init() {
        // 获取文档目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 创建数据目录
        dataDirectory = documentsDirectory.appendingPathComponent("data", isDirectory: true)
        
        // 设置数据文件路径
        childrenFile = dataDirectory.appendingPathComponent("children.json")
        storiesFile = dataDirectory.appendingPathComponent("stories.json")
        
        // 创建数据目录（如果不存在）
        createDataDirectoryIfNeeded()
        
        // 加载数据
        loadData()
        
        logger.info("数据服务初始化完成")
    }
    
    // MARK: - 宝宝管理
    
    // 添加宝宝
    func addChild(_ child: Child) {
        // 检查是否已存在同名宝宝
        if children.contains(where: { $0.name == child.name }) {
            logger.warning("⚠️ 已存在同名宝宝: \(child.name)")
            return
        }
        
        // 添加宝宝
        children.append(child)
        
        // 保存数据
        saveChildren()
        
        logger.info("✅ 添加宝宝成功: \(child.name)")
    }
    
    // 更新宝宝
    func updateChild(_ child: Child) {
        // 查找宝宝索引
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            // 更新宝宝
            children[index] = child
            
            // 保存数据
            saveChildren()
            
            logger.info("✅ 更新宝宝成功: \(child.name)")
        } else {
            logger.warning("⚠️ 未找到要更新的宝宝: \(child.id)")
        }
    }
    
    // 删除宝宝
    func deleteChild(withId id: String) {
        // 查找宝宝索引
        if let index = children.firstIndex(where: { $0.id == id }) {
            let childName = children[index].name
            
            // 删除宝宝
            children.remove(at: index)
            
            // 保存数据
            saveChildren()
            
            logger.info("✅ 删除宝宝成功: \(childName)")
        } else {
            logger.warning("⚠️ 未找到要删除的宝宝: \(id)")
        }
    }
    
    // 获取宝宝
    func getChild(withId id: String) -> Child? {
        return children.first(where: { $0.id == id })
    }
    
    // 获取所有宝宝
    func getAllChildren() -> [Child] {
        return children
    }
    
    // MARK: - 故事管理
    
    // 添加故事
    func addStory(_ story: Story) {
        // 添加故事
        stories.append(story)
        
        // 保存数据
        saveStories()
        
        logger.info("✅ 添加故事成功: \(story.title)")
    }
    
    // 更新故事
    func updateStory(_ story: Story) {
        // 查找故事索引
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            // 更新故事
            stories[index] = story
            
            // 保存数据
            saveStories()
            
            logger.info("✅ 更新故事成功: \(story.title)")
        } else {
            logger.warning("⚠️ 未找到要更新的故事: \(story.id)")
        }
    }
    
    // 删除故事
    func deleteStory(withId id: String) {
        // 查找故事索引
        if let index = stories.firstIndex(where: { $0.id == id }) {
            let storyTitle = stories[index].title
            
            // 删除故事
            stories.remove(at: index)
            
            // 保存数据
            saveStories()
            
            logger.info("✅ 删除故事成功: \(storyTitle)")
        } else {
            logger.warning("⚠️ 未找到要删除的故事: \(id)")
        }
    }
    
    // 获取故事
    func getStory(withId id: String) -> Story? {
        return stories.first(where: { $0.id == id })
    }
    
    // 获取所有故事
    func getAllStories() -> [Story] {
        return stories
    }
    
    // 获取宝宝的故事
    func getStories(forChildName childName: String) -> [Story] {
        return stories.filter { $0.childName == childName }
    }
    
    // MARK: - 收藏相关方法
    
    // 收藏故事
    func favoriteStory(withId id: String) -> Bool {
        guard let index = stories.firstIndex(where: { $0.id == id }) else {
            logger.warning("⚠️ 未找到要收藏的故事: \(id)")
            return false
        }
        
        let story = stories[index]
        stories[index] = story.updateFavoriteStatus(true)
        
        // 保存数据
        saveStories()
        
        logger.info("✅ 收藏故事成功: \(story.title)")
        return true
    }
    
    // 取消收藏故事
    func unfavoriteStory(withId id: String) -> Bool {
        guard let index = stories.firstIndex(where: { $0.id == id }) else {
            logger.warning("⚠️ 未找到要取消收藏的故事: \(id)")
            return false
        }
        
        let story = stories[index]
        stories[index] = story.updateFavoriteStatus(false)
        
        // 保存数据
        saveStories()
        
        logger.info("✅ 取消收藏故事成功: \(story.title)")
        return true
    }
    
    // 检查故事是否已收藏
    func isStoryFavorited(withId id: String) -> Bool {
        guard let story = stories.first(where: { $0.id == id }) else {
            logger.warning("⚠️ 未找到要检查的故事: \(id)")
            return false
        }
        
        return story.isFavorite
    }
    
    // 获取收藏的故事列表
    func getFavoriteStories() -> [Story] {
        return stories.filter { $0.isFavorite }
    }
    
    // MARK: - 数据持久化
    
    // 创建数据目录
    private func createDataDirectoryIfNeeded() {
        do {
            // 检查数据目录是否存在
            if !fileManager.fileExists(atPath: self.dataDirectory.path) {
                // 创建数据目录
                try fileManager.createDirectory(at: self.dataDirectory, withIntermediateDirectories: true)
                logger.info("✅ 创建数据目录成功: \(self.dataDirectory.path)")
            }
        } catch {
            logger.error("❌ 创建数据目录失败: \(error.localizedDescription)")
        }
    }
    
    // 加载数据
    private func loadData() {
        // 加载宝宝数据
        loadChildren()
        
        // 加载故事数据
        loadStories()
    }
    
    // 加载宝宝数据
    private func loadChildren() {
        do {
            // 检查文件是否存在
            if fileManager.fileExists(atPath: childrenFile.path) {
                // 读取文件数据
                let data = try Data(contentsOf: childrenFile)
                
                // 解码数据
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                self.children = try decoder.decode([Child].self, from: data)
                
                logger.info("✅ 加载宝宝数据成功，共 \(self.children.count) 个宝宝")
            } else {
                logger.info("⚠️ 宝宝数据文件不存在，使用空数组")
                self.children = []
            }
        } catch {
            logger.error("❌ 加载宝宝数据失败: \(error.localizedDescription)")
            self.children = []
        }
    }
    
    // 加载故事数据
    private func loadStories() {
        do {
            // 检查文件是否存在
            if fileManager.fileExists(atPath: storiesFile.path) {
                // 读取文件数据
                let data = try Data(contentsOf: storiesFile)
                
                // 解码数据
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                self.stories = try decoder.decode([Story].self, from: data)
                
                logger.info("✅ 加载故事数据成功，共 \(self.stories.count) 个故事")
            } else {
                logger.info("⚠️ 故事数据文件不存在，使用空数组")
                self.stories = []
            }
        } catch {
            logger.error("❌ 加载故事数据失败: \(error.localizedDescription)")
            self.stories = []
        }
    }
    
    // 保存宝宝数据
    private func saveChildren() {
        do {
            // 编码数据
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(children)
            
            // 写入文件
            try data.write(to: childrenFile)
            
            logger.info("✅ 保存宝宝数据成功，共 \(self.children.count) 个宝宝")
        } catch {
            logger.error("❌ 保存宝宝数据失败: \(error.localizedDescription)")
        }
    }
    
    // 保存故事数据
    private func saveStories() {
        do {
            // 编码数据
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(stories)
            
            // 写入文件
            try data.write(to: storiesFile)
            
            logger.info("✅ 保存故事数据成功，共 \(self.stories.count) 个故事")
        } catch {
            logger.error("❌ 保存故事数据失败: \(error.localizedDescription)")
        }
    }
} 