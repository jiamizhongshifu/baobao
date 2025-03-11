import Foundation

struct Child: Codable {
    let id: String
    let name: String
    let age: Int
    let gender: String
    let interests: [String]
    let createdAt: Date
    
    init(id: String = UUID().uuidString,
         name: String,
         age: Int,
         gender: String,
         interests: [String],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.interests = interests
        self.createdAt = createdAt
    }
    
    // 从字典创建Child对象
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let age = dictionary["age"] as? Int,
              let gender = dictionary["gender"] as? String,
              let interests = dictionary["interests"] as? [String],
              let createdAtString = dictionary["createdAt"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.interests = interests
        self.createdAt = createdAt
    }
    
    // 转换为字典
    func toDictionary() -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        return [
            "id": id,
            "name": name,
            "age": age,
            "gender": gender,
            "interests": interests,
            "createdAt": dateFormatter.string(from: createdAt)
        ]
    }
} 