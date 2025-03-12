# 宝宝故事应用 - 性能监控与分页功能使用指南

本指南介绍如何使用宝宝故事应用中新增的性能监控和分页功能，帮助开发者优化应用性能并提高大数据量下的用户体验。

## 目录

- [性能监控功能](#性能监控功能)
  - [基本用法](#基本用法)
  - [高级用法](#高级用法)
  - [性能报告](#性能报告)
- [分页功能](#分页功能)
  - [基本用法](#分页功能基本用法)
  - [与UI集成](#与UI集成)
  - [最佳实践](#分页最佳实践)
- [示例代码](#示例代码)

## 性能监控功能

性能监控系统通过`PerformanceMonitor`类提供，用于跟踪和分析应用中各种操作的性能指标，帮助开发者识别性能瓶颈并优化应用性能。

### 基本用法

#### 1. 获取性能监控器实例

```swift
let performanceMonitor = PerformanceMonitor.shared
```

#### 2. 测量操作时间

```swift
// 方法1：使用开始和结束方法
performanceMonitor.startOperation("操作名称")
// 执行需要测量的操作
performanceMonitor.endOperation("操作名称")

// 方法2：使用measure方法测量同步操作
let result = performanceMonitor.measure("操作名称") {
    // 执行需要测量的操作
    return someValue
}

// 方法3：使用measureAsync方法测量异步操作
Task {
    let result = await performanceMonitor.measureAsync("异步操作名称") {
        // 执行需要测量的异步操作
        return await someAsyncValue
    }
}
```

#### 3. 启用/禁用详细日志

```swift
// 启用详细日志
performanceMonitor.enableVerboseLogging()

// 禁用详细日志
performanceMonitor.disableVerboseLogging()
```

### 高级用法

#### 1. 自定义操作名称

为了保持一致性，建议使用`PerformanceMonitor.Operation`中定义的常量：

```swift
performanceMonitor.startOperation(PerformanceMonitor.Operation.storyGeneration)
// 执行故事生成操作
performanceMonitor.endOperation(PerformanceMonitor.Operation.storyGeneration)
```

#### 2. 嵌套操作测量

```swift
performanceMonitor.startOperation("外部操作")

// 执行一些操作

performanceMonitor.startOperation("内部操作")
// 执行内部操作
performanceMonitor.endOperation("内部操作")

// 执行更多操作

performanceMonitor.endOperation("外部操作")
```

#### 3. 重置性能数据

```swift
// 重置所有性能数据
performanceMonitor.resetAllStats()

// 重置特定操作的性能数据
performanceMonitor.resetStats(forOperation: "操作名称")
```

### 性能报告

#### 1. 获取性能统计信息

```swift
// 获取所有操作的统计信息
let allStats = performanceMonitor.getAllOperationStats()

// 获取特定操作的统计信息
let specificStats = performanceMonitor.getStats(forOperation: "操作名称")
```

#### 2. 打印性能报告

```swift
// 打印所有操作的性能报告
performanceMonitor.printPerformanceReport()
```

#### 3. 性能统计结构

`OperationStats`结构包含以下信息：

- `operationName`：操作名称
- `count`：操作执行次数
- `totalDuration`：总执行时间（秒）
- `averageDuration`：平均执行时间（秒）
- `minDuration`：最短执行时间（秒）
- `maxDuration`：最长执行时间（秒）

## 分页功能

分页功能通过`ModelManager`类提供，用于高效加载大量数据，避免一次性加载全部数据导致的性能问题。

### <a name="分页功能基本用法"></a>基本用法

#### 1. 使用分页加载故事

```swift
do {
    let context = try modelManager.getContext()
    
    // 加载第1页，每页10条数据
    let stories = try await modelManager.getStoriesWithPagination(
        context: context,
        page: 1,
        pageSize: 10,
        isFavoriteOnly: false
    )
    
    // 使用加载的故事数据
    updateUI(with: stories)
} catch {
    handleError(error)
}
```

#### 2. 获取故事总数

```swift
do {
    let context = try modelManager.getContext()
    
    // 获取故事总数
    let totalCount = try await modelManager.getStoriesCount(
        context: context,
        isFavoriteOnly: false
    )
    
    // 更新UI显示总数
    updateTotalCountLabel(totalCount)
} catch {
    handleError(error)
}
```

#### 3. 加载更多数据（下一页）

```swift
// 当用户滚动到底部或点击"加载更多"按钮时
func loadNextPage() {
    currentPage += 1
    
    do {
        let context = try modelManager.getContext()
        
        // 加载下一页数据
        let moreStories = try await modelManager.getStoriesWithPagination(
            context: context,
            page: currentPage,
            pageSize: pageSize,
            isFavoriteOnly: isFavoriteOnly
        )
        
        // 将新数据添加到现有数据中
        stories.append(contentsOf: moreStories)
        
        // 更新UI
        updateUI(with: stories)
    } catch {
        handleError(error)
        currentPage -= 1  // 恢复页码
    }
}
```

### 与UI集成

#### 1. SwiftUI列表集成

```swift
struct StoriesListView: View {
    @State private var stories: [StoryModel] = []
    @State private var currentPage = 1
    @State private var pageSize = 20
    @State private var totalStories = 0
    @State private var isLoading = false
    
    var body: some View {
        List {
            ForEach(stories) { story in
                StoryRow(story: story)
            }
            
            if stories.count < totalStories {
                Button("加载更多") {
                    loadMoreStories()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(isLoading)
            }
        }
        .onAppear {
            loadInitialStories()
        }
    }
    
    private func loadInitialStories() {
        // 实现初始加载逻辑
    }
    
    private func loadMoreStories() {
        // 实现加载更多逻辑
    }
}
```

#### 2. UIKit表格视图集成

```swift
class StoriesTableViewController: UITableViewController {
    private var stories: [StoryModel] = []
    private var currentPage = 1
    private var pageSize = 20
    private var totalStories = 0
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadInitialStories()
    }
    
    // 在表格视图滚动到底部时加载更多数据
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        if offsetY > contentHeight - height && !isLoading && stories.count < totalStories {
            loadMoreStories()
        }
    }
    
    private func loadInitialStories() {
        // 实现初始加载逻辑
    }
    
    private func loadMoreStories() {
        // 实现加载更多逻辑
    }
}
```

### <a name="分页最佳实践"></a>最佳实践

1. **选择合适的页面大小**：根据UI和数据复杂度选择合适的页面大小，通常在10-30之间
2. **预加载下一页**：当用户接近当前页底部时，提前加载下一页数据
3. **显示加载状态**：在加载数据时显示加载指示器，提高用户体验
4. **错误处理**：妥善处理加载失败情况，提供重试选项
5. **缓存已加载数据**：避免重复加载相同页面的数据
6. **结合性能监控**：使用性能监控功能跟踪分页加载性能

## 示例代码

完整的示例代码可以在`/Users/zhongqingbiao/Documents/baobao/baobao/Examples/PerformanceAndPaginationExample.swift`文件中找到，该示例展示了如何：

1. 使用分页功能加载故事数据
2. 实现"加载更多"功能
3. 集成性能监控
4. 显示性能统计信息

要运行示例，请在应用中导航到"示例"部分，然后选择"性能与分页示例"。

## 总结

通过使用性能监控和分页功能，您可以：

1. 识别和解决应用中的性能瓶颈
2. 优化大数据量下的加载性能
3. 提高应用响应速度和用户体验
4. 减少内存占用和电池消耗

如有任何问题或建议，请联系开发团队。 