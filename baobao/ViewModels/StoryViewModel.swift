import Foundation
import Combine

class StoryViewModel: ObservableObject {
    // 发布属性，当值变化时会通知观察者
    @Published var stories: [Story] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedStory: Story?
    
    // 故事主题
    let themes = [
        "space": "太空冒险",
        "ocean": "海洋探险",
        "forest": "森林奇遇",
        "dinosaur": "恐龙世界",
        "fairy": "童话王国"
    ]
    
    // 故事长度选项
    let lengthOptions = [
        "short": "短篇故事 (约3分钟)",
        "medium": "中篇故事 (约5分钟)",
        "long": "长篇故事 (约8分钟)"
    ]
    
    // 最近故事（按创建日期排序）
    var recentStories: [Story] {
        return stories.sorted { $0.createdAt > $1.createdAt }
    }
    
    // 推荐故事（可以根据不同条件筛选，这里简单实现为随机排序）
    var recommendedStories: [Story] {
        return stories.shuffled()
    }
    
    private let storyService = StoryService.shared
    private let dataService = StoryDataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 加载所有故事
    func loadStories() {
        isLoading = true
        errorMessage = nil
        
        dataService.getStories { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let stories):
                    self?.stories = stories
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // 根据宝宝名称加载故事
    func loadStories(forChild childName: String) {
        isLoading = true
        errorMessage = nil
        
        dataService.getStoriesByChild(childName: childName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let stories):
                    self?.stories = stories
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // 生成新故事
    func generateStory(theme: String, childName: String, length: String, completion: @escaping (Result<Story, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // 创建一个模拟的故事对象
        let story = Story(
            title: "宝宝的\(themes[theme] ?? "奇妙")冒险",
            content: "这是一个关于\(childName)的\(themes[theme] ?? "奇妙")冒险故事。在这个故事中，\(childName)经历了许多有趣的事情，学到了很多道理。",
            theme: theme,
            childName: childName
        )
        
        // 模拟异步操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isLoading = false
            self?.selectedStory = story
            completion(.success(story))
        }
    }
    
    // 保存故事
    func saveStory(_ story: Story, completion: @escaping (Bool) -> Void) {
        dataService.saveStory(story) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // 如果保存成功，更新本地故事列表
                    if let index = self?.stories.firstIndex(where: { $0.id == story.id }) {
                        self?.stories[index] = story
                    } else {
                        self?.stories.append(story)
                    }
                }
                completion(success)
            }
        }
    }
    
    // 删除故事
    func deleteStory(id: String, completion: @escaping (Bool) -> Void) {
        dataService.deleteStory(id: id) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // 如果删除成功，从本地故事列表中移除
                    self?.stories.removeAll { $0.id == id }
                }
                completion(success)
            }
        }
    }
    
    // 搜索故事
    func searchStories(query: String) {
        if query.isEmpty {
            loadStories()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        dataService.searchStories(query: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let stories):
                    self?.stories = stories
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
} 