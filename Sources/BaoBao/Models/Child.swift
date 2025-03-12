import Foundation

/// 宝宝信息模型
struct Child: Codable, Identifiable {
    /// 宝宝ID
    let id: String
    
    /// 宝宝名字
    let name: String
    
    /// 宝宝年龄
    let age: Int
    
    /// 宝宝性别
    let gender: String
    
    /// 兴趣爱好
    let interests: [String]
    
    /// 创建时间
    let createdAt: Date
    
    /// 初始化宝宝信息
    /// - Parameters:
    ///   - id: 宝宝ID，默认自动生成
    ///   - name: 宝宝名字
    ///   - age: 宝宝年龄
    ///   - gender: 宝宝性别
    ///   - interests: 兴趣爱好，默认为空数组
    ///   - createdAt: 创建时间，默认为当前时间
    init(id: String = UUID().uuidString,
         name: String,
         age: Int,
         gender: String,
         interests: [String] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.interests = interests
        self.createdAt = createdAt
    }
    
    /// 更新宝宝信息
    /// - Parameters:
    ///   - name: 宝宝名字
    ///   - age: 宝宝年龄
    ///   - gender: 宝宝性别
    ///   - interests: 兴趣爱好
    /// - Returns: 更新后的宝宝信息
    func update(name: String? = nil,
                age: Int? = nil,
                gender: String? = nil,
                interests: [String]? = nil) -> Child {
        return Child(
            id: self.id,
            name: name ?? self.name,
            age: age ?? self.age,
            gender: gender ?? self.gender,
            interests: interests ?? self.interests,
            createdAt: self.createdAt
        )
    }
} 