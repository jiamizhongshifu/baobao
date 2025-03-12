import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var storyViewModel: StoryViewModel
    @EnvironmentObject private var childViewModel: ChildViewModel
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingAddChildSheet = false
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            // 主内容
            VStack(spacing: 0) {
                // 头部欢迎区域
                welcomeHeader
                
                // 搜索栏
                searchBar
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 24) {
                        // 最近故事区域
                        recentStoriesSection
                        
                        // 故事主题区域
                        storyThemesSection
                        
                        // 推荐故事区域
                        recommendedStoriesSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 触发侧边栏显示
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleSidebar"), object: nil)
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.darkBlue)
                }
            }
        }
        .sheet(isPresented: $showingAddChildSheet) {
            AddChildView(isPresented: $showingAddChildSheet)
        }
        .onAppear {
            // 加载数据
            storyViewModel.loadStories()
            childViewModel.loadChildren()
        }
    }
    
    // 欢迎头部
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // 欢迎文本
                VStack(alignment: .leading, spacing: 8) {
                    Text("你好，\(childViewModel.selectedChild?.name ?? "小朋友")")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.primaryText)
                    
                    Text("今天想听什么故事呢？")
                        .font(.system(size: 16))
                        .foregroundColor(Color.secondaryText)
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                // 宝宝选择按钮
                Button(action: {
                    showingAddChildSheet = true
                }) {
                    if let child = childViewModel.selectedChild {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 50, height: 50)
                                .shadow(color: Color.darkBlue.opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            Text(child.name.prefix(1))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 50, height: 50)
                                .shadow(color: Color.darkBlue.opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
        }
    }
    
    // 搜索栏
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSearching ? Color.darkBlue : Color.darkGray)
                    .padding(.leading, 8)
                
                TextField("搜索故事", text: $searchText, onEditingChanged: { editing in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching = editing
                    }
                })
                .font(.system(size: 16))
                .foregroundColor(Color.primaryText)
                .padding(.vertical, 10)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.darkGray)
                    }
                    .padding(.trailing, 8)
                    .transition(.scale)
                    .animation(.easeInOut(duration: 0.2), value: searchText)
                }
            }
            .padding(.horizontal, 8)
            .background(Color.searchBarBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSearching ? Color.darkBlue.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearching)
            
            if isSearching {
                Button("取消") {
                    searchText = ""
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .foregroundColor(Color.darkBlue)
                .padding(.leading, 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isSearching)
            }
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                storyViewModel.searchStories(query: newValue)
            } else if !isSearching {
                storyViewModel.loadStories()
            }
        }
    }
    
    // 最近故事区域
    private var recentStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "最近故事", actionTitle: "查看全部")
            
            if storyViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if storyViewModel.recentStories.isEmpty {
                emptyStoriesView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(storyViewModel.recentStories.prefix(5), id: \.id) { story in
                            NavigationLink(destination: StoryDetailView(story: story)) {
                                RecentStoryCard(story: story)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }
            }
        }
        .cardStyle()
    }
    
    // 故事主题区域
    private var storyThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "故事主题", actionTitle: "全部主题")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(storyViewModel.themes.keys.prefix(4)), id: \.self) { key in
                    NavigationLink(destination: StoryGenerationView(theme: key)) {
                        ThemeCard(
                            title: storyViewModel.themes[key] ?? "",
                            iconName: themeIconName(for: key),
                            color: themeColor(for: key)
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .cardStyle()
    }
    
    // 推荐故事区域
    private var recommendedStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "推荐故事", actionTitle: "更多推荐")
            
            if storyViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if storyViewModel.stories.isEmpty {
                emptyStoriesView
            } else {
                VStack(spacing: 16) {
                    ForEach(storyViewModel.stories.prefix(3), id: \.id) { story in
                        NavigationLink(destination: StoryDetailView(story: story)) {
                            RecommendedStoryRow(story: story)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .cardStyle()
    }
    
    // 空故事视图
    private var emptyStoriesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(Color.darkGray.opacity(0.7))
                .padding(.bottom, 8)
            
            Text("还没有故事")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.primaryText)
            
            Text("点击「故事主题」创建你的第一个故事")
                .font(.system(size: 16))
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            NavigationLink(destination: StoryThemesView()) {
                Text("创建故事")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LinearGradient.primaryGradient)
                    .cornerRadius(10)
                    .shadow(color: Color.darkBlue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    // 获取主题图标名称
    private func themeIconName(for theme: String) -> String {
        switch theme {
        case "space":
            return "airplane"
        case "ocean":
            return "water.waves"
        case "forest":
            return "leaf"
        case "dinosaur":
            return "leaf"
        case "fairy":
            return "wand.and.stars"
        default:
            return "book"
        }
    }
    
    // 获取主题颜色
    private func themeColor(for theme: String) -> Color {
        switch theme {
        case "space":
            return Color(hex: "8A2BE2") // BlueViolet
        case "ocean":
            return Color(hex: "1E90FF") // DodgerBlue
        case "forest":
            return Color(hex: "228B22") // ForestGreen
        case "dinosaur":
            return Color(hex: "CD853F") // Peru
        case "fairy":
            return Color(hex: "FF69B4") // HotPink
        default:
            return Color.darkBlue
        }
    }
}

// MARK: - 辅助视图

// 区域标题
struct SectionHeader: View {
    let title: String
    let actionTitle: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.primaryText)
            
            Spacer()
            
            NavigationLink(destination: EmptyView()) {
                Text(actionTitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color.darkBlue)
            }
        }
    }
}

// 最近故事卡片
struct RecentStoryCard: View {
    let story: Story
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 故事封面
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.babyBlue, Color.darkBlue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 120)
                    .cornerRadius(12)
                
                // 故事标题
                Text(story.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .lineLimit(2)
            }
            
            // 故事信息
            HStack {
                // 宝宝名称
                Text(story.childName)
                    .font(.system(size: 14))
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                // 创建日期
                Text(formatDate(story.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondaryText)
            }
        }
        .frame(width: 180)
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.customBlack.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

// 推荐故事行
struct RecommendedStoryRow: View {
    let story: Story
    
    var body: some View {
        HStack(spacing: 16) {
            // 故事封面
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.babyBlue, Color.darkBlue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .cornerRadius(12)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // 故事信息
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.primaryText)
                    .lineLimit(2)
                
                Text(story.content.prefix(50) + "...")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
                    .lineLimit(2)
                
                HStack {
                    Text(story.childName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.darkBlue)
                    
                    Spacer()
                    
                    Text(formatDate(story.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(Color.secondaryText)
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.customBlack.opacity(0.05), radius: 5, x: 0, y: 3)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

// 主题卡片
struct ThemeCard: View {
    let title: String
    let iconName: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            // 标题
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.customBlack.opacity(0.05), radius: 5, x: 0, y: 3)
    }
} 