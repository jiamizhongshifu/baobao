# 宝宝故事应用性能优化计划

本文档详细说明了宝宝故事应用的性能优化计划，包括数据加载优化、缓存策略改进、网络请求优化、UI响应性提升和内存管理优化等方面。

## 1. 数据加载与存储优化

### 1.1 SwiftData查询优化

当前的`ModelManager`实现在查询数据时可能存在性能瓶颈，特别是在数据量大的情况下。建议进行以下优化：

- **批量获取与分页**：
  ```swift
  func getStoriesWithPagination(context: ModelContext, page: Int, pageSize: Int) -> [StoryModel] {
      var descriptor = FetchDescriptor<StoryModel>()
      descriptor.sortBy = [SortDescriptor(\.createdDate, order: .reverse)]
      descriptor.fetchOffset = page * pageSize
      descriptor.fetchLimit = pageSize
      
      do {
          return try context.fetch(descriptor)
      } catch {
          print("获取故事失败: \(error.localizedDescription)")
          return []
      }
  }
  ```

- **索引优化**：为常用查询字段添加索引，提高查询速度：
  ```swift
  @Model
  final class StoryModel {
      // 添加索引标记
      @Attribute(.unique) var id: String
      @Attribute(.indexed) var createdDate: Date
      @Attribute(.indexed) var isFavorite: Bool
      // 其他属性...
  }
  ```

- **预取关联数据**：在一次查询中预取关联数据，减少多次查询：
  ```swift
  func getStoriesWithSpeeches(context: ModelContext) -> [StoryModel] {
      var descriptor = FetchDescriptor<StoryModel>()
      descriptor.relationship = \StoryModel.speeches
      
      do {
          return try context.fetch(descriptor)
      } catch {
          print("获取故事及语音失败: \(error.localizedDescription)")
          return []
      }
  }
  ```

### 1.2 数据预加载策略

- **应用启动时预加载**：
  ```swift
  func preloadFrequentlyUsedData() {
      Task {
          await MainActor.run {
              // 预加载用户设置
              _ = getUserSettings(context: modelContext)
              
              // 预加载最近的故事
              let recentStories = getRecentStories(context: modelContext, limit: 5)
              
              // 预热缓存
              for story in recentStories {
                  preloadStoryResources(story)
              }
          }
      }
  }
  ```

- **后台预加载**：在应用空闲时预加载可能需要的数据：
  ```swift
  func preloadDataInBackground() {
      let backgroundTask = UIApplication.shared.beginBackgroundTask {
          // 任务结束时调用
      }
      
      DispatchQueue.global(qos: .utility).async {
          // 预加载数据
          // ...
          
          UIApplication.shared.endBackgroundTask(backgroundTask)
      }
  }
  ```

## 2. 缓存策略优化

当前的缓存实现可以进一步优化，以提高应用性能和减少资源消耗。

### 2.1 多级缓存策略

实现内存缓存和磁盘缓存的两级缓存策略：

```swift
class EnhancedCacheManager {
    // 内存缓存
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    // 磁盘缓存（现有实现）
    private let diskCache = CacheManager.shared
    
    init() {
        // 设置内存缓存限制
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func getData(forKey key: String, type: CacheType) -> Data? {
        // 先检查内存缓存
        if let cachedData = memoryCache.object(forKey: key as NSString) as? Data {
            return cachedData
        }
        
        // 再检查磁盘缓存
        if let diskData = diskCache.dataFromCache(forKey: key, type: type) {
            // 添加到内存缓存
            memoryCache.setObject(diskData as NSData, forKey: key as NSString)
            return diskData
        }
        
        return nil
    }
    
    func saveData(_ data: Data, forKey key: String, type: CacheType) {
        // 保存到内存缓存
        memoryCache.setObject(data as NSData, forKey: key as NSString)
        
        // 保存到磁盘缓存
        _ = diskCache.saveToCache(data: data, forKey: key, type: type)
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
}
```

### 2.2 智能缓存预热

根据用户使用模式预热缓存：

```swift
class CachePreheater {
    private let cacheManager: EnhancedCacheManager
    private let userPreferenceTracker: UserPreferenceTracker
    
    init(cacheManager: EnhancedCacheManager, userPreferenceTracker: UserPreferenceTracker) {
        self.cacheManager = cacheManager
        self.userPreferenceTracker = userPreferenceTracker
    }
    
    func preheatCache() {
        // 获取用户偏好
        let favoriteThemes = userPreferenceTracker.getFavoriteThemes()
        let frequentCharacters = userPreferenceTracker.getFrequentCharacters()
        
        // 预热最可能使用的故事
        for theme in favoriteThemes.prefix(3) {
            for character in frequentCharacters.prefix(2) {
                let cacheKey = generateCacheKey(theme: theme, characterName: character, length: .medium)
                
                // 检查是否已缓存
                if !cacheManager.hasCached(forKey: cacheKey, type: .story) {
                    // 在后台预生成并缓存
                    preGenerateStory(theme: theme, characterName: character, length: .medium)
                }
            }
        }
    }
    
    private func preGenerateStory(theme: StoryTheme, characterName: String, length: StoryLength) {
        Task.detached(priority: .background) {
            // 预生成故事逻辑
        }
    }
}
```

### 2.3 缓存优先级管理

实现基于优先级的缓存淘汰策略：

```swift
enum CachePriority: Int {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

extension CacheManager {
    func cleanCacheToSize(_ targetSize: Int64) {
        // 获取所有缓存记录
        let records = getAllCacheRecords().sorted { (record1, record2) -> Bool in
            // 首先按优先级排序
            if record1.priority.rawValue != record2.priority.rawValue {
                return record1.priority.rawValue < record2.priority.rawValue
            }
            
            // 其次按最后访问时间排序
            return record1.lastAccessedDate < record2.lastAccessedDate
        }
        
        var currentSize = calculateTotalCacheSize()
        var recordsToDelete: [CacheRecord] = []
        
        // 从低优先级开始删除，直到达到目标大小
        for record in records {
            if currentSize <= targetSize {
                break
            }
            
            recordsToDelete.append(record)
            currentSize -= record.fileSize
        }
        
        // 删除选定的记录
        for record in recordsToDelete {
            deleteRecord(record)
        }
    }
}
```

## 3. 网络请求优化

### 3.1 请求合并与批处理

当需要获取多个相关资源时，合并请求以减少网络往返：

```swift
func batchFetchStories(themes: [StoryTheme], completion: @escaping ([StoryModel]) -> Void) {
    // 构建批量请求
    var batchRequest = URLRequest(url: URL(string: configManager.batchStoryEndpoint)!)
    batchRequest.httpMethod = "POST"
    batchRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody = [
        "themes": themes.map { $0.rawValue },
        "count": themes.count
    ]
    
    batchRequest.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
    
    // 发送批量请求
    URLSession.shared.dataTask(with: batchRequest) { data, response, error in
        // 处理响应
    }.resume()
}
```

### 3.2 请求优先级管理

根据用户交互优先级调整网络请求：

```swift
enum RequestPriority {
    case high   // 用户直接交互触发的请求
    case normal // 预加载但用户可能很快需要的内容
    case low    // 后台预加载，非紧急内容
}

func performRequest(url: URL, priority: RequestPriority, completion: @escaping (Data?, Error?) -> Void) {
    var request = URLRequest(url: url)
    
    // 设置请求优先级
    switch priority {
    case .high:
        request.networkServiceType = .responsiveData
    case .normal:
        request.networkServiceType = .default
    case .low:
        request.networkServiceType = .background
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        completion(data, error)
    }.resume()
}
```

### 3.3 智能网络策略

根据网络状况自动调整请求策略：

```swift
func fetchWithNetworkAwareness<T: Decodable>(endpoint: String, completion: @escaping (Result<T, Error>) -> Void) {
    // 检查网络状态
    let networkStatus = NetworkManager.shared.status
    let connectionType = NetworkManager.shared.connectionType
    
    // 根据网络状况调整请求
    switch (networkStatus, connectionType) {
    case (.connected, .wifi):
        // WiFi连接，可以请求高质量内容
        fetchHighQualityContent(endpoint: endpoint, completion: completion)
        
    case (.connected, .cellular):
        // 蜂窝网络，请求压缩内容
        fetchCompressedContent(endpoint: endpoint, completion: completion)
        
    default:
        // 离线或其他情况，使用缓存
        fetchFromCache(endpoint: endpoint, completion: completion)
    }
}
```

## 4. UI响应性优化

### 4.1 异步图像加载与缓存

优化图像加载过程，减少主线程阻塞：

```swift
class AsyncImageLoader {
    private let imageCache = NSCache<NSString, UIImage>()
    
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // 检查缓存
        let cacheKey = url.absoluteString as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // 异步加载
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 缓存图像
            self.imageCache.setObject(image, forKey: cacheKey)
            
            // 主线程返回结果
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
```

### 4.2 列表性能优化

优化列表视图性能，特别是对于长列表：

```swift
// 在SwiftUI中使用LazyVStack替代VStack
struct OptimizedStoryList: View {
    @Query private var stories: [StoryModel]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(stories) { story in
                    StoryRowView(story: story)
                        .id(story.id)
                }
            }
            .padding()
        }
    }
}

// 实现高效的列表预取
extension StoryListViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // 预取即将显示的行数据
        for indexPath in indexPaths {
            let story = stories[indexPath.row]
            preloadStoryResources(story)
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // 取消预取
        for indexPath in indexPaths {
            let story = stories[indexPath.row]
            cancelPreloadingForStory(story)
        }
    }
}
```

### 4.3 渐进式加载

实现内容的渐进式加载，提高用户体验：

```swift
struct ProgressiveStoryView: View {
    let story: StoryModel
    @State private var loadingState: LoadingState = .loading
    @State private var contentChunks: [String] = []
    
    enum LoadingState {
        case loading
        case partial
        case complete
        case error
    }
    
    var body: some View {
        VStack {
            // 标题立即显示
            Text(story.title)
                .font(.largeTitle)
                .padding()
            
            // 内容渐进式加载
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(contentChunks.indices, id: \.self) { index in
                        Text(contentChunks[index])
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }
                    
                    if loadingState == .loading || loadingState == .partial {
                        ProgressView()
                            .padding()
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadContentProgressively()
        }
    }
    
    private func loadContentProgressively() {
        // 将内容分成多个块
        let fullContent = story.content
        let chunks = fullContent.split(separator: "\n\n").map(String.init)
        
        // 逐步加载每个块
        loadingState = .partial
        
        for (index, chunk) in chunks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation {
                    contentChunks.append(chunk)
                    
                    if index == chunks.count - 1 {
                        loadingState = .complete
                    }
                }
            }
        }
    }
}
```

## 5. 内存管理优化

### 5.1 资源生命周期管理

优化资源的加载和释放时机：

```swift
class ResourceManager {
    private var loadedResources: [String: Any] = [:]
    private var resourceUsageCount: [String: Int] = [:]
    
    func loadResource<T>(id: String, loader: () -> T) -> T {
        // 检查资源是否已加载
        if let resource = loadedResources[id] as? T {
            // 增加使用计数
            resourceUsageCount[id, default: 0] += 1
            return resource
        }
        
        // 加载资源
        let resource = loader()
        loadedResources[id] = resource
        resourceUsageCount[id] = 1
        
        return resource
    }
    
    func releaseResource(id: String) {
        // 减少使用计数
        resourceUsageCount[id, default: 0] -= 1
        
        // 如果没有使用者，释放资源
        if resourceUsageCount[id, default: 0] <= 0 {
            loadedResources.removeValue(forKey: id)
            resourceUsageCount.removeValue(forKey: id)
        }
    }
    
    func releaseUnusedResources() {
        // 释放所有未使用的资源
        let unusedIds = resourceUsageCount.filter { $0.value <= 0 }.map { $0.key }
        
        for id in unusedIds {
            loadedResources.removeValue(forKey: id)
            resourceUsageCount.removeValue(forKey: id)
        }
    }
}
```

### 5.2 大型资源处理

优化大型资源（如音频文件）的处理：

```swift
class AudioResourceManager {
    private var activeAudioPlayers: [String: AVAudioPlayer] = [:]
    
    func playAudio(url: URL, storyId: String) {
        // 如果已有播放器在播放，先停止
        if let existingPlayer = activeAudioPlayers[storyId] {
            existingPlayer.stop()
        }
        
        do {
            // 创建新的播放器
            let player = try AVAudioPlayer(contentsOf: url)
            activeAudioPlayers[storyId] = player
            player.play()
            
            // 播放完成后释放资源
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.releaseAudioPlayer(for: storyId)
            }
        } catch {
            print("播放音频失败: \(error.localizedDescription)")
        }
    }
    
    func releaseAudioPlayer(for storyId: String) {
        activeAudioPlayers.removeValue(forKey: storyId)
    }
    
    func releaseAllAudioPlayers() {
        for (_, player) in activeAudioPlayers {
            player.stop()
        }
        activeAudioPlayers.removeAll()
    }
}
```

### 5.3 内存警告处理

响应系统内存警告，释放非必要资源：

```swift
extension AppDelegate {
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // 清理内存缓存
        ImageCache.shared.clearMemoryCache()
        
        // 释放未使用的资源
        ResourceManager.shared.releaseUnusedResources()
        
        // 释放音频播放器
        AudioResourceManager.shared.releaseAllAudioPlayers()
        
        // 通知垃圾回收
        autoreleasepool {
            // 强制垃圾回收
        }
    }
}
```

## 6. 后台任务优化

### 6.1 后台任务优先级管理

根据任务重要性设置优先级：

```swift
enum TaskPriority {
    case userInitiated
    case userInteractive
    case utility
    case background
}

func scheduleTask(priority: TaskPriority, work: @escaping () -> Void) {
    let qos: DispatchQoS.QoSClass
    
    switch priority {
    case .userInteractive:
        qos = .userInteractive
    case .userInitiated:
        qos = .userInitiated
    case .utility:
        qos = .utility
    case .background:
        qos = .background
    }
    
    DispatchQueue.global(qos: qos).async {
        work()
    }
}
```

### 6.2 批量处理后台任务

合并多个小任务为批量操作：

```swift
class BatchProcessor {
    private var pendingOperations: [() -> Void] = []
    private let operationQueue = OperationQueue()
    private let batchSize = 10
    private var timer: Timer?
    
    init() {
        operationQueue.maxConcurrentOperationCount = 1
        startProcessingTimer()
    }
    
    func addOperation(_ operation: @escaping () -> Void) {
        pendingOperations.append(operation)
        
        // 如果达到批处理大小，立即处理
        if pendingOperations.count >= batchSize {
            processPendingOperations()
        }
    }
    
    private func startProcessingTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.processPendingOperations()
        }
    }
    
    private func processPendingOperations() {
        guard !pendingOperations.isEmpty else { return }
        
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        operationQueue.addOperation {
            for operation in operations {
                operation()
            }
        }
    }
}
```

## 7. 实施计划

### 7.1 优先级排序

1. **高优先级**（立即实施）：
   - 实现多级缓存策略
   - 优化SwiftData查询
   - 实现网络请求优先级管理

2. **中优先级**（1-2周内实施）：
   - 实现数据预加载策略
   - 优化UI响应性
   - 实现智能网络策略

3. **低优先级**（长期优化）：
   - 实现缓存优先级管理
   - 优化内存管理
   - 实现批量处理后台任务

### 7.2 性能指标

实施优化后，我们期望达到以下性能指标：

- 应用启动时间：< 2秒
- 列表滚动帧率：> 55 FPS
- 故事加载时间：< 1秒
- 内存使用峰值：< 150MB
- 电池消耗：每小时使用 < 5%

### 7.3 监控与评估

实施以下监控机制评估优化效果：

- 使用Instruments工具监控CPU、内存和I/O使用情况
- 实现自定义性能追踪点，记录关键操作的执行时间
- 收集用户反馈，特别关注应用响应性和电池消耗
- 定期审查崩溃报告和性能异常

## 8. 结论

通过实施上述优化措施，宝宝故事应用将在以下方面获得显著改进：

1. **更快的响应速度**：通过多级缓存和预加载策略，减少用户等待时间
2. **更流畅的用户体验**：通过UI渲染优化和异步处理，提高界面流畅度
3. **更低的资源消耗**：通过智能资源管理，减少内存和电池消耗
4. **更好的离线体验**：通过优化缓存策略，提升离线模式下的应用表现
5. **更高的稳定性**：通过改进错误处理和资源管理，减少崩溃和异常

这些优化将使宝宝故事应用在各种设备和网络条件下都能提供出色的用户体验，特别是对于低端设备和不稳定网络环境的用户。 