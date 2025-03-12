import Foundation
import SwiftData

/// 孩子信息模型
@Model
final class Child {
    /// 唯一标识符
    var id: String
    /// 孩子姓名
    var name: String
    /// 孩子年龄
    var age: Int
    /// 孩子性别（可选）
    var gender: String?
    /// 孩子生日（可选）
    var birthday: Date?
    /// 孩子头像URL（可选）
    var avatarURL: String?
    /// 创建时间
    var createdAt: Date
    /// 最后修改时间
    var updatedAt: Date
    /// 孩子喜欢的故事主题
    var favoriteThemes: [String]
    /// 孩子喜欢的语音类型
    var favoriteVoiceType: String?
    
    /// 初始化方法
    init(
        id: String = UUID().uuidString,
        name: String,
        age: Int,
        gender: String? = nil,
        birthday: Date? = nil,
        avatarURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        favoriteThemes: [String] = [],
        favoriteVoiceType: String? = nil
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.birthday = birthday
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.favoriteThemes = favoriteThemes
        self.favoriteVoiceType = favoriteVoiceType
    }
} 