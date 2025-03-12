import SwiftUI

struct StoryGenerationView: View {
    @EnvironmentObject private var storyViewModel: StoryViewModel
    @EnvironmentObject private var childViewModel: ChildViewModel
    @EnvironmentObject private var audioPlayerViewModel: AudioPlayerViewModel
    
    let theme: String
    
    @State private var selectedLength = "medium"
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    @State private var generatedStory: Story?
    @State private var navigateToStoryDetail = false
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color.primaryBackground
                .edgesIgnoringSafeArea(.all)
            
            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 主题信息
                    themeInfoSection
                    
                    // 宝宝选择
                    childSelectionSection
                    
                    // 故事长度选择
                    storyLengthSection
                    
                    // 生成按钮
                    generateButton
                }
                .padding()
            }
            
            // 加载指示器
            if isGenerating {
                generatingOverlay
            }
        }
        .navigationTitle(storyViewModel.themes[theme] ?? "创建故事")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("提示"),
                message: Text(errorMessage ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
        .navigationDestination(isPresented: $navigateToStoryDetail) {
            if let story = generatedStory {
                StoryDetailView(story: story)
            }
        }
    }
    
    // 主题信息部分
    private var themeInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 主题图标和标题
            HStack(spacing: 16) {
                Image(systemName: themeIconName(for: theme))
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(themeColor(for: theme))
                    .cornerRadius(16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(storyViewModel.themes[theme] ?? "未知主题")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.primaryText)
                    
                    Text(themeDescription(for: theme))
                        .font(.subheadline)
                        .foregroundColor(Color.secondaryText)
                }
            }
            
            // 主题描述
            Text("在这个主题中，我们将为你的宝宝创建一个精彩的故事，让他们成为故事的主角，体验一段奇妙的冒险。")
                .font(.body)
                .foregroundColor(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 宝宝选择部分
    private var childSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择宝宝")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            if childViewModel.children.isEmpty {
                // 没有宝宝时显示添加提示
                VStack(spacing: 12) {
                    Text("还没有添加宝宝")
                        .font(.subheadline)
                        .foregroundColor(Color.secondaryText)
                    
                    NavigationLink(destination: ChildManagementView()) {
                        Text("添加宝宝")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.searchBarBackground)
                .cornerRadius(8)
            } else {
                // 显示宝宝选择列表
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(childViewModel.children, id: \.id) { child in
                            ChildSelectionCard(
                                child: child,
                                isSelected: childViewModel.selectedChild?.id == child.id,
                                onSelect: {
                                    childViewModel.selectChild(child)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 故事长度选择部分
    private var storyLengthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("故事长度")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            VStack(spacing: 12) {
                ForEach(Array(storyViewModel.lengthOptions), id: \.key) { key, value in
                    Button(action: {
                        selectedLength = key
                    }) {
                        HStack {
                            Image(systemName: selectedLength == key ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedLength == key ? themeColor(for: theme) : Color.secondaryText)
                            
                            Text(value)
                                .font(.subheadline)
                                .foregroundColor(Color.primaryText)
                            
                            Spacer()
                        }
                        .padding()
                        .background(selectedLength == key ? themeColor(for: theme).opacity(0.1) : Color.searchBarBackground)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 生成按钮
    private var generateButton: some View {
        Button(action: {
            generateStory()
        }) {
            Text("开始生成故事")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    childViewModel.selectedChild == nil ? Color.gray : themeColor(for: theme)
                )
                .cornerRadius(12)
        }
        .disabled(childViewModel.selectedChild == nil || isGenerating)
        .padding(.vertical, 8)
    }
    
    // 生成中覆盖层
    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("正在为\(childViewModel.selectedChild?.name ?? "宝宝")创作故事...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("这可能需要一点时间，请耐心等待")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
            .background(Color.primaryBackground.opacity(0.8))
            .cornerRadius(16)
        }
    }
    
    // 生成故事
    private func generateStory() {
        guard let selectedChild = childViewModel.selectedChild else {
            errorMessage = "请先选择一个宝宝"
            showAlert = true
            return
        }
        
        isGenerating = true
        
        storyViewModel.generateStory(
            theme: theme,
            childName: selectedChild.name,
            length: selectedLength
        ) { result in
            isGenerating = false
            
            switch result {
            case .success(let story):
                generatedStory = story
                navigateToStoryDetail = true
            case .failure(let error):
                errorMessage = "生成故事失败: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // 获取主题图标名称
    private func themeIconName(for theme: String) -> String {
        switch theme {
        case "space":
            return "airplane"
        case "ocean":
            return "water.waves"
        case "forest":
            return "leaf.fill"
        case "dinosaur":
            return "fossil.shell.fill"
        case "fairy":
            return "wand.and.stars"
        default:
            return "book.fill"
        }
    }
    
    // 获取主题颜色
    private func themeColor(for theme: String) -> Color {
        switch theme {
        case "space":
            return Color.purple
        case "ocean":
            return Color.blue
        case "forest":
            return Color.green
        case "dinosaur":
            return Color.orange
        case "fairy":
            return Color.pink
        default:
            return Color.gray
        }
    }
    
    // 获取主题描述
    private func themeDescription(for theme: String) -> String {
        switch theme {
        case "space":
            return "探索浩瀚宇宙，与外星人交朋友"
        case "ocean":
            return "潜入深海，发现神秘的海底世界"
        case "forest":
            return "在森林中冒险，结识各种小动物"
        case "dinosaur":
            return "穿越时空，与恐龙一起玩耍"
        case "fairy":
            return "进入童话世界，体验魔法冒险"
        default:
            return "开始一段奇妙的冒险"
        }
    }
}

// 宝宝选择卡片
struct ChildSelectionCard: View {
    let child: Child
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // 宝宝头像
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.gray)
                        .frame(width: 60, height: 60)
                    
                    Text(child.name.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // 宝宝名字
                Text(child.name)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? Color.accentColor : Color.primaryText)
                
                // 宝宝年龄和性别
                Text("\(child.age)岁 · \(child.gender == .male ? "男孩" : "女孩")")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
            .frame(width: 100)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.searchBarBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
    }
} 