import Foundation
import SwiftData
import os.log
import Combine

/// 孩子仓库，负责处理孩子相关的数据操作
class ChildRepository {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = ChildRepository()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.repository", category: "ChildRepository")
    
    /// 数据管理器
    private let dataManager = DataManager.shared
    
    /// 孩子变更发布者
    private let childChangesSubject = PassthroughSubject<Void, Never>()
    
    /// 孩子变更发布者
    var childChangesPublisher: AnyPublisher<Void, Never> {
        return childChangesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 公共方法
    
    /// 获取所有孩子
    func getAllChildren() -> [ChildModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<ChildModel>(sortBy: [ChildModel.sortByName])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("获取所有孩子失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 按ID获取孩子
    func getChild(withId id: String) -> ChildModel? {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<ChildModel>(
            predicate: #Predicate { child in
                child.id == id
            }
        )
        
        do {
            let children = try context.fetch(descriptor)
            return children.first
        } catch {
            logger.error("获取孩子失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 按名字搜索孩子
    func searchChildren(byName name: String) -> [ChildModel] {
        let context = dataManager.mainContext
        let descriptor = FetchDescriptor<ChildModel>(
            predicate: ChildModel.withName(name),
            sortBy: [ChildModel.sortByName]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("搜索孩子失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 保存孩子
    func saveChild(_ child: ChildModel) {
        let context = dataManager.mainContext
        
        // 检查是否已存在
        if let existingChild = getChild(withId: child.id) {
            // 更新现有孩子
            existingChild.name = child.name
            existingChild.age = child.age
            existingChild.gender = child.gender
            existingChild.interests = child.interests
            existingChild.updatedAt = Date()
        } else {
            // 添加新孩子
            context.insert(child)
            
            // 如果没有语音偏好，创建默认的
            if child.voicePreference == nil {
                let voicePreference = VoicePreferenceModel.createDefault(for: child)
                child.voicePreference = voicePreference
                context.insert(voicePreference)
            }
        }
        
        do {
            try context.save()
            childChangesSubject.send()
            logger.info("保存孩子成功: \(child.id)")
        } catch {
            logger.error("保存孩子失败: \(error.localizedDescription)")
        }
    }
    
    /// 删除孩子
    func deleteChild(_ child: ChildModel) {
        let context = dataManager.mainContext
        
        // 删除关联的语音偏好
        if let voicePreference = child.voicePreference {
            context.delete(voicePreference)
        }
        
        // 删除孩子
        context.delete(child)
        
        do {
            try context.save()
            childChangesSubject.send()
            logger.info("删除孩子成功: \(child.id)")
        } catch {
            logger.error("删除孩子失败: \(error.localizedDescription)")
        }
    }
    
    /// 更新孩子的语音偏好
    func updateVoicePreference(childId: String, voiceType: String, speechRate: Double = 1.0, volume: Double = 1.0, useLocalTTS: Bool = false) {
        guard let child = getChild(withId: childId) else {
            logger.error("更新语音偏好失败: 未找到孩子 \(childId)")
            return
        }
        
        let context = dataManager.mainContext
        
        if let voicePreference = child.voicePreference {
            // 更新现有偏好
            voicePreference.preferredVoiceType = voiceType
            voicePreference.speechRate = speechRate
            voicePreference.volume = volume
            voicePreference.useLocalTTS = useLocalTTS
            voicePreference.updatedAt = Date()
        } else {
            // 创建新偏好
            let newPreference = VoicePreferenceModel(
                preferredVoiceType: voiceType,
                speechRate: speechRate,
                volume: volume,
                useLocalTTS: useLocalTTS,
                child: child
            )
            child.voicePreference = newPreference
            context.insert(newPreference)
        }
        
        do {
            try context.save()
            logger.info("更新语音偏好成功: \(childId)")
        } catch {
            logger.error("更新语音偏好失败: \(error.localizedDescription)")
        }
    }
    
    /// 添加兴趣
    func addInterest(childId: String, interest: String) {
        guard let child = getChild(withId: childId) else {
            logger.error("添加兴趣失败: 未找到孩子 \(childId)")
            return
        }
        
        if !child.interests.contains(interest) {
            child.interests.append(interest)
            child.updatedAt = Date()
            
            do {
                try dataManager.mainContext.save()
                logger.info("添加兴趣成功: \(childId), 兴趣: \(interest)")
            } catch {
                logger.error("添加兴趣失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 移除兴趣
    func removeInterest(childId: String, interest: String) {
        guard let child = getChild(withId: childId) else {
            logger.error("移除兴趣失败: 未找到孩子 \(childId)")
            return
        }
        
        if let index = child.interests.firstIndex(of: interest) {
            child.interests.remove(at: index)
            child.updatedAt = Date()
            
            do {
                try dataManager.mainContext.save()
                logger.info("移除兴趣成功: \(childId), 兴趣: \(interest)")
            } catch {
                logger.error("移除兴趣失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 从旧版Child创建并保存ChildModel
    func createFromLegacyChild(_ legacyChild: Child) -> ChildModel {
        // 创建新的ChildModel
        let childModel = ChildModel(from: legacyChild)
        
        // 保存到数据库
        saveChild(childModel)
        
        return childModel
    }
} 