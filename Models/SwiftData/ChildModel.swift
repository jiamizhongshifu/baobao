import Foundation
import SwiftData

/// 孩子模型 - SwiftData兼容
@Model
final class ChildModel {
    // MARK: - 属性
    
    /// 唯一标识符
    var id: String
    
    /// 名字
    var name: String
    
    /// 年龄
    var age: Int
    
    /// 性别
    var gender: String
    
    /// 兴趣爱好
    var interests: [String]
    
    /// 创建时间
    var createdAt: Date
    
    /// 最后修改时间
    var updatedAt: Date
    
    /// 关联的故事（一对多）
    @Relationship(deleteRule: .cascade, inverse: \StoryModel.child)
    var stories: [StoryModel] = []
    
    /// 语音偏好设置
    @Relationship(deleteRule: .cascade, inverse: \VoicePreferenceModel.child)
    var voicePreference: VoicePreferenceModel?
    
    // MARK: - 初始化方法
    
    init(
        id: String = UUID().uuidString,
        name: String,
        age: Int,
        gender: String,
        interests: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        stories: [StoryModel] = [],
        voicePreference: VoicePreferenceModel? = nil
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.interests = interests
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.stories = stories
        self.voicePreference = voicePreference
    }
    
    // MARK: - 转换方法
    
    /// 从旧版Child模型创建
    convenience init(from child: Child) {
        self.init(
            id: child.id,
            name: child.name,
            age: child.age,
            gender: child.gender,
            interests: child.interests,
            createdAt: child.createdAt,
            updatedAt: Date()
        )
    }
    
    /// 转换为旧版Child模型
    func toChild() -> Child {
        return Child(
            id: id,
            name: name,
            age: age,
            gender: gender,
            interests: interests,
            createdAt: createdAt
        )
    }
}

// MARK: - 查询扩展

extension ChildModel {
    /// 按名字筛选
    static func withName(_ name: String) -> Predicate<ChildModel> {
        #Predicate { child in
            child.name.localizedCaseInsensitiveContains(name)
        }
    }
    
    /// 按年龄范围筛选
    static func withAgeRange(min: Int, max: Int) -> Predicate<ChildModel> {
        #Predicate { child in
            child.age >= min && child.age <= max
        }
    }
    
    /// 按性别筛选
    static func withGender(_ gender: String) -> Predicate<ChildModel> {
        #Predicate { child in
            child.gender == gender
        }
    }
    
    /// 按名字排序
    static var sortByName: SortDescriptor<ChildModel> {
        SortDescriptor(\.name)
    }
} 