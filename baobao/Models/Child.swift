import Foundation

struct Child: Identifiable, Codable {
    let id: String
    let name: String
    let age: Int
    let gender: Gender
    let interests: [String]
    let createdAt: Date
    
    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"
    }
    
    init(id: String = UUID().uuidString, 
         name: String, 
         age: Int, 
         gender: Gender, 
         interests: [String] = [], 
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.interests = interests
        self.createdAt = createdAt
    }
} 