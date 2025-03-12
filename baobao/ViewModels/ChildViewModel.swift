import Foundation
import Combine

class ChildViewModel: ObservableObject {
    // 发布属性，当值变化时会通知观察者
    @Published var children: [Child] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedChild: Child?
    
    // 性别选项
    let genderOptions = [
        "male": "男孩",
        "female": "女孩"
    ]
    
    // 兴趣选项
    let interestOptions = [
        "animals": "动物",
        "space": "太空",
        "dinosaurs": "恐龙",
        "fairy_tales": "童话",
        "science": "科学",
        "music": "音乐",
        "sports": "运动",
        "art": "艺术"
    ]
    
    private let dataService = APIDataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 加载所有宝宝
    func loadChildren() {
        isLoading = true
        errorMessage = nil
        
        // 使用getAllChildren方法获取所有宝宝
        let children = dataService.getAllChildren()
        self.children = children
        
        // 如果有宝宝且没有选中的宝宝，则选中第一个
        if !children.isEmpty && self.selectedChild == nil {
            self.selectedChild = children[0]
        }
        
        isLoading = false
    }
    
    // 保存宝宝
    func saveChild(_ child: Child, completion: @escaping (Bool) -> Void) {
        // 根据是否存在ID决定是添加还是更新
        if children.contains(where: { $0.id == child.id }) {
            dataService.updateChild(child)
        } else {
            dataService.addChild(child)
        }
        
        // 更新本地宝宝列表
        if let index = self.children.firstIndex(where: { $0.id == child.id }) {
            self.children[index] = child
        } else {
            self.children.append(child)
        }
        
        // 如果没有选中的宝宝，则选中当前保存的宝宝
        if self.selectedChild == nil {
            self.selectedChild = child
        }
        
        completion(true)
    }
    
    // 删除宝宝
    func deleteChild(id: String, completion: @escaping (Bool) -> Void) {
        dataService.deleteChild(withId: id)
        
        // 从本地宝宝列表中移除
        self.children.removeAll { $0.id == id }
        
        // 如果删除的是当前选中的宝宝，则重置选中的宝宝
        if self.selectedChild?.id == id {
            self.selectedChild = self.children.first
        }
        
        completion(true)
    }
    
    // 选择宝宝
    func selectChild(_ child: Child) {
        selectedChild = child
    }
    
    // 创建新宝宝
    func createNewChild(name: String, age: Int, gender: String, interests: [String], completion: @escaping (Result<Child, Error>) -> Void) {
        // 创建Gender枚举值
        let genderEnum: Child.Gender = (gender == "male") ? .male : .female
        
        let newChild = Child(
            name: name,
            age: age,
            gender: genderEnum,
            interests: interests
        )
        
        saveChild(newChild) { success in
            if success {
                completion(.success(newChild))
            } else {
                completion(.failure(NSError(domain: "ChildViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "保存宝宝信息失败"])))
            }
        }
    }
    
    // 清除所有宝宝数据
    func clearAllChildren() {
        // 清空本地宝宝列表
        self.children.removeAll()
        
        // 清空选中的宝宝
        self.selectedChild = nil
        
        // 清空数据服务中的宝宝数据
        // 由于 APIDataService 没有 clearAllData 方法，我们手动删除所有宝宝
        let allChildren = dataService.getAllChildren()
        for child in allChildren {
            dataService.deleteChild(withId: child.id)
        }
    }
} 