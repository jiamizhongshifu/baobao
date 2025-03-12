import Foundation
import os.log

class DataService {
    static let shared = DataService()
    private let logger = Logger(subsystem: "com.example.baobao", category: "DataService")
    
    private let childrenKey = "children"
    
    private init() {
        logger.info("🚀 DataService初始化")
    }
    
    // MARK: - 宝宝管理
    
    // 获取所有宝宝
    func getChildren(completion: @escaping (Result<[Child], Error>) -> Void) {
        logger.info("📥 获取所有宝宝")
        
        if let data = UserDefaults.standard.data(forKey: childrenKey) {
            do {
                let children = try JSONDecoder().decode([Child].self, from: data)
                logger.info("✅ 成功获取\(children.count)个宝宝")
                completion(.success(children))
            } catch {
                logger.error("❌ 解码宝宝数据失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        } else {
            logger.info("ℹ️ 没有找到宝宝数据，返回空数组")
            completion(.success([]))
        }
    }
    
    // 保存宝宝
    func saveChild(_ child: Child, completion: @escaping (Bool) -> Void) {
        logger.info("💾 保存宝宝: \(child.name)")
        
        getChildren { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var children):
                // 检查是否已存在相同ID的宝宝
                if let index = children.firstIndex(where: { $0.id == child.id }) {
                    // 更新现有宝宝
                    children[index] = child
                    logger.info("✏️ 更新宝宝: \(child.name)")
                } else {
                    // 添加新宝宝
                    children.append(child)
                    logger.info("➕ 添加新宝宝: \(child.name)")
                }
                
                // 保存更新后的宝宝列表
                do {
                    let data = try JSONEncoder().encode(children)
                    UserDefaults.standard.set(data, forKey: childrenKey)
                    logger.info("✅ 宝宝保存成功")
                    completion(true)
                } catch {
                    logger.error("❌ 编码宝宝数据失败: \(error.localizedDescription)")
                    completion(false)
                }
                
            case .failure(let error):
                logger.error("❌ 获取宝宝列表失败: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // 删除宝宝
    func deleteChild(id: String, completion: @escaping (Bool) -> Void) {
        logger.info("🗑️ 删除宝宝ID: \(id)")
        
        getChildren { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var children):
                // 移除指定ID的宝宝
                let originalCount = children.count
                children.removeAll { $0.id == id }
                
                if children.count < originalCount {
                    // 宝宝被成功移除
                    do {
                        let data = try JSONEncoder().encode(children)
                        UserDefaults.standard.set(data, forKey: childrenKey)
                        logger.info("✅ 宝宝删除成功")
                        completion(true)
                    } catch {
                        logger.error("❌ 编码宝宝数据失败: \(error.localizedDescription)")
                        completion(false)
                    }
                } else {
                    // 未找到指定ID的宝宝
                    logger.warning("⚠️ 未找到ID为\(id)的宝宝")
                    completion(false)
                }
                
            case .failure(let error):
                logger.error("❌ 获取宝宝列表失败: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // 清除所有数据（用于测试和重置）
    func clearAllData(completion: @escaping (Bool) -> Void) {
        logger.warning("🧹 清除所有数据")
        UserDefaults.standard.removeObject(forKey: childrenKey)
        completion(true)
    }
} 