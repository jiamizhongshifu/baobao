import Foundation
import os.log

class StoryDataService {
    static let shared = StoryDataService()
    private let logger = Logger(subsystem: "com.example.baobao", category: "StoryDataService")
    
    private let storiesKey = "stories"
    private let apiService = StoryService.shared
    
    private init() {
        logger.info("🚀 StoryDataService初始化")
    }
    
    // MARK: - 故事管理
    
    // 获取所有故事
    func getStories(completion: @escaping (Result<[Story], Error>) -> Void) {
        logger.info("📥 获取所有故事")
        
        if let data = UserDefaults.standard.data(forKey: storiesKey) {
            do {
                let stories = try JSONDecoder().decode([Story].self, from: data)
                logger.info("✅ 成功获取\(stories.count)个故事")
                completion(.success(stories))
            } catch {
                logger.error("❌ 解码故事数据失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        } else {
            logger.info("ℹ️ 没有找到故事数据，返回空数组")
            completion(.success([]))
        }
    }
    
    // 根据宝宝名称获取故事
    func getStoriesByChild(childName: String, completion: @escaping (Result<[Story], Error>) -> Void) {
        logger.info("📥 获取宝宝\(childName)的故事")
        
        getStories { result in
            switch result {
            case .success(let stories):
                let filteredStories = stories.filter { $0.childName == childName }
                completion(.success(filteredStories))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 保存故事
    func saveStory(_ story: Story, completion: @escaping (Bool) -> Void) {
        logger.info("💾 保存故事: \(story.title)")
        
        getStories { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var stories):
                // 检查是否已存在相同ID的故事
                if let index = stories.firstIndex(where: { $0.id == story.id }) {
                    // 更新现有故事
                    stories[index] = story
                    logger.info("✏️ 更新故事: \(story.title)")
                } else {
                    // 添加新故事
                    stories.append(story)
                    logger.info("➕ 添加新故事: \(story.title)")
                }
                
                // 保存更新后的故事列表
                do {
                    let data = try JSONEncoder().encode(stories)
                    UserDefaults.standard.set(data, forKey: storiesKey)
                    logger.info("✅ 故事保存成功")
                    completion(true)
                } catch {
                    logger.error("❌ 编码故事数据失败: \(error.localizedDescription)")
                    completion(false)
                }
                
            case .failure(let error):
                logger.error("❌ 获取故事列表失败: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // 删除故事
    func deleteStory(id: String, completion: @escaping (Bool) -> Void) {
        logger.info("🗑️ 删除故事ID: \(id)")
        
        getStories { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var stories):
                // 移除指定ID的故事
                let originalCount = stories.count
                stories.removeAll { $0.id == id }
                
                if stories.count < originalCount {
                    // 故事被成功移除
                    do {
                        let data = try JSONEncoder().encode(stories)
                        UserDefaults.standard.set(data, forKey: storiesKey)
                        logger.info("✅ 故事删除成功")
                        completion(true)
                    } catch {
                        logger.error("❌ 编码故事数据失败: \(error.localizedDescription)")
                        completion(false)
                    }
                } else {
                    // 未找到指定ID的故事
                    logger.warning("⚠️ 未找到ID为\(id)的故事")
                    completion(false)
                }
                
            case .failure(let error):
                logger.error("❌ 获取故事列表失败: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // 搜索故事
    func searchStories(query: String, completion: @escaping (Result<[Story], Error>) -> Void) {
        logger.info("🔍 搜索故事: \(query)")
        
        getStories { result in
            switch result {
            case .success(let stories):
                let lowercaseQuery = query.lowercased()
                let filteredStories = stories.filter { story in
                    story.title.lowercased().contains(lowercaseQuery) ||
                    story.content.lowercased().contains(lowercaseQuery) ||
                    story.childName.lowercased().contains(lowercaseQuery)
                }
                completion(.success(filteredStories))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 清除所有数据（用于测试和重置）
    func clearAllData(completion: @escaping (Bool) -> Void) {
        logger.warning("🧹 清除所有故事数据")
        UserDefaults.standard.removeObject(forKey: storiesKey)
        completion(true)
    }
} 