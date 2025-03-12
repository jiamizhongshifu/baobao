import SwiftUI
import SwiftData
import os.log

/// 性能监控和分页功能示例视图
struct PerformanceAndPaginationExampleView: View {
    // MARK: - 属性
    
    /// 模型管理器
    @State private var modelManager: ModelManaging = ModelManager.shared
    
    /// 模型上下文
    @Environment(\.modelContext) private var modelContext
    
    /// 故事服务
    private let storyService = StoryService.shared
    
    /// 性能监控器
    private let performanceMonitor = PerformanceMonitor.shared
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.example", category: "PerformanceAndPaginationExample")
    
    /// 故事列表
    @State private var stories: [StoryModel] = []
    
    /// 当前页码
    @State private var currentPage: Int = 1
    
    /// 每页数量
    @State private var pageSize: Int = 10
    
    /// 总故事数量
    @State private var totalStories: Int = 0
    
    /// 是否仅显示收藏
    @State private var isFavoriteOnly: Bool = false
    
    /// 是否正在加载
    @State private var isLoading: Bool = false
    
    /// 性能统计信息
    @State private var performanceStats: [OperationStats] = []
    
    // MARK: - 视图
    
    var body: some View {
        NavigationView {
            VStack {
                // 筛选控制
                HStack {
                    Toggle("仅显示收藏", isOn: $isFavoriteOnly)
                        .onChange(of: isFavoriteOnly) { _, _ in
                            resetAndLoadStories()
                        }
                    
                    Spacer()
                    
                    Button("刷新") {
                        resetAndLoadStories()
                    }
                }
                .padding()
                
                // 故事列表
                List {
                    ForEach(stories) { story in
                        StoryRow(story: story)
                    }
                    
                    // 加载更多按钮
                    if stories.count < totalStories {
                        Button("加载更多") {
                            loadMoreStories()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(isLoading)
                    }
                }
                
                // 分页信息
                HStack {
                    Text("第\(currentPage)页")
                    Spacer()
                    Text("共\(totalStories)个故事")
                }
                .padding()
                
                // 性能监控按钮
                Button("查看性能统计") {
                    showPerformanceStats()
                }
                .padding()
            }
            .navigationTitle("故事列表")
            .onAppear {
                // 初始加载
                resetAndLoadStories()
            }
        }
        .sheet(isPresented: .constant(!performanceStats.isEmpty)) {
            PerformanceStatsView(stats: performanceStats) {
                performanceStats = []
            }
        }
    }
    
    // MARK: - 方法
    
    /// 重置并加载故事
    private func resetAndLoadStories() {
        currentPage = 1
        loadStories()
        
        // 获取总故事数
        Task {
            do {
                let context = modelContext
                totalStories = try await modelManager.getStoriesCount(context: context, isFavoriteOnly: isFavoriteOnly)
            } catch {
                logger.error("获取故事总数失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 加载故事
    private func loadStories() {
        isLoading = true
        
        // 使用性能监控器测量加载时间
        performanceMonitor.startOperation("LoadStories_Page\(currentPage)")
        
        Task {
            do {
                let context = modelContext
                
                // 使用分页加载故事
                let loadedStories = try await modelManager.getStoriesWithPagination(
                    context: context,
                    page: currentPage,
                    pageSize: pageSize,
                    isFavoriteOnly: isFavoriteOnly
                )
                
                if currentPage == 1 {
                    stories = loadedStories
                } else {
                    stories.append(contentsOf: loadedStories)
                }
                
                performanceMonitor.endOperation("LoadStories_Page\(currentPage)")
                logger.info("成功加载第\(currentPage)页故事，数量: \(loadedStories.count)")
            } catch {
                performanceMonitor.endOperation("LoadStories_Page\(currentPage)")
                logger.error("加载故事失败: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    /// 加载更多故事
    private func loadMoreStories() {
        currentPage += 1
        loadStories()
    }
    
    /// 显示性能统计
    private func showPerformanceStats() {
        performanceStats = performanceMonitor.getAllOperationStats()
    }
}

/// 故事行视图
struct StoryRow: View {
    let story: StoryModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(story.title ?? "无标题")
                .font(.headline)
            
            HStack {
                Text("主题: \(story.themeString)")
                    .font(.subheadline)
                
                Spacer()
                
                Text("角色: \(story.characterName ?? "未知")")
                    .font(.subheadline)
            }
            
            Text("创建时间: \(formattedDate(story.createdDate))")
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    /// 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 性能统计视图
struct PerformanceStatsView: View {
    let stats: [OperationStats]
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(stats) { stat in
                    VStack(alignment: .leading) {
                        Text(stat.operation)
                            .font(.headline)
                        
                        HStack {
                            Text("调用次数: \(stat.count)")
                            Spacer()
                            Text("总时间: \(String(format: "%.2f", stat.totalDuration))秒")
                        }
                        .font(.subheadline)
                        
                        HStack {
                            Text("平均时间: \(String(format: "%.2f", stat.averageDuration * 1000))毫秒")
                            Spacer()
                            Text("最长时间: \(String(format: "%.2f", stat.maxDuration * 1000))毫秒")
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("性能统计")
            .navigationBarItems(trailing: Button("关闭") {
                onClose()
            })
        }
    }
}

/// 预览提供者
struct PerformanceAndPaginationExampleView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceAndPaginationExampleView()
    }
} 