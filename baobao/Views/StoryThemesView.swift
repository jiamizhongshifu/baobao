import SwiftUI

struct StoryThemesView: View {
    @EnvironmentObject private var storyViewModel: StoryViewModel
    @EnvironmentObject private var childViewModel: ChildViewModel
    
    // 每行显示的主题数量
    private let columnsCount = 2
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 头部说明
                    headerSection
                    
                    // 主题网格
                    themesGridSection
                }
                .padding()
            }
        }
        .navigationTitle("故事主题")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // 头部说明部分
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择一个主题")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.primaryText)
            
            Text("为\(childViewModel.selectedChild?.name ?? "宝宝")选择一个喜欢的故事主题，我们将为你生成一个精彩的故事。")
                .font(.system(size: 16))
                .foregroundColor(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(24)
        .shadow(color: Color.customBlack.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // 主题网格部分
    private var themesGridSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columnsCount), spacing: 20) {
            ForEach(Array(storyViewModel.themes), id: \.key) { key, value in
                NavigationLink(destination: StoryGenerationView(theme: key)) {
                    ThemeCardLarge(
                        title: value,
                        description: themeDescription(for: key),
                        iconName: themeIconName(for: key),
                        color: themeColor(for: key)
                    )
                }
                .buttonStyle(PlainButtonStyle())
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
    
    // 获取主题描述
    private func themeDescription(for theme: String) -> String {
        switch theme {
        case "space":
            return "探索浩瀚宇宙，遇见外星朋友"
        case "ocean":
            return "潜入深海世界，发现海洋奥秘"
        case "forest":
            return "漫步神秘森林，结交动物伙伴"
        case "dinosaur":
            return "穿越远古时代，邂逅恐龙家族"
        case "fairy":
            return "进入魔法王国，体验奇幻冒险"
        default:
            return "开启精彩故事，激发无限想象"
        }
    }
}

// 大型主题卡片
struct ThemeCardLarge: View {
    let title: String
    let description: String
    let iconName: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(color)
            }
            
            // 标题和描述
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.primaryText)
                    .lineLimit(1)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // 创建故事按钮
            HStack {
                Spacer()
                
                Text("创建故事")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
        }
        .frame(height: 200)
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.customBlack.opacity(0.05), radius: 8, x: 0, y: 4)
    }
} 