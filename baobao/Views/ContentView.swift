import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storyViewModel: StoryViewModel
    @EnvironmentObject private var childViewModel: ChildViewModel
    @State private var selectedView: String? = "home"
    @State private var showSidebar = false
    
    var body: some View {
        NavigationView {
            // 侧边栏
            SidebarView(selectedView: $selectedView)
            
            // 主内容区域
            Group {
                switch selectedView {
                case "home":
                    HomeView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case "themes":
                    StoryThemesView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case "children":
                    ChildManagementView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case "profile":
                    ProfileView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                default:
                    HomeView()
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedView)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle()) // 在iPad上显示为双列模式
        .onAppear {
            // 加载初始数据
            childViewModel.loadChildren()
            storyViewModel.loadStories()
            
            // 注册侧边栏切换通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ToggleSidebar"),
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.spring()) {
                    showSidebar.toggle()
                }
            }
        }
    }
}

// 侧边栏视图
struct SidebarView: View {
    @Binding var selectedView: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: 0) {
            // 应用标题
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.darkBlue)
                
                Text("宝宝故事")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                Color.cardBackground
                    .shadow(color: Color.customBlack.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // 导航列表
            List {
                NavigationLink(
                    destination: HomeView(),
                    tag: "home",
                    selection: $selectedView
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 18))
                            .foregroundColor(selectedView == "home" ? Color.darkBlue : Color.darkGray)
                            .frame(width: 24, height: 24)
                        
                        Text("首页")
                            .font(.system(size: 16, weight: selectedView == "home" ? .semibold : .regular))
                            .foregroundColor(selectedView == "home" ? Color.darkBlue : Color.primaryText)
                    }
                    .padding(.vertical, 12)
                }
                .listRowBackground(selectedView == "home" ? Color.lightBlue.opacity(0.3) : Color.clear)
                
                NavigationLink(
                    destination: StoryThemesView(),
                    tag: "themes",
                    selection: $selectedView
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 18))
                            .foregroundColor(selectedView == "themes" ? Color.darkBlue : Color.darkGray)
                            .frame(width: 24, height: 24)
                        
                        Text("故事主题")
                            .font(.system(size: 16, weight: selectedView == "themes" ? .semibold : .regular))
                            .foregroundColor(selectedView == "themes" ? Color.darkBlue : Color.primaryText)
                    }
                    .padding(.vertical, 12)
                }
                .listRowBackground(selectedView == "themes" ? Color.lightBlue.opacity(0.3) : Color.clear)
                
                NavigationLink(
                    destination: ChildManagementView(),
                    tag: "children",
                    selection: $selectedView
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(selectedView == "children" ? Color.darkBlue : Color.darkGray)
                            .frame(width: 24, height: 24)
                        
                        Text("宝宝管理")
                            .font(.system(size: 16, weight: selectedView == "children" ? .semibold : .regular))
                            .foregroundColor(selectedView == "children" ? Color.darkBlue : Color.primaryText)
                    }
                    .padding(.vertical, 12)
                }
                .listRowBackground(selectedView == "children" ? Color.lightBlue.opacity(0.3) : Color.clear)
                
                NavigationLink(
                    destination: ProfileView(),
                    tag: "profile",
                    selection: $selectedView
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(selectedView == "profile" ? Color.darkBlue : Color.darkGray)
                            .frame(width: 24, height: 24)
                        
                        Text("我的")
                            .font(.system(size: 16, weight: selectedView == "profile" ? .semibold : .regular))
                            .foregroundColor(selectedView == "profile" ? Color.darkBlue : Color.primaryText)
                    }
                    .padding(.vertical, 12)
                }
                .listRowBackground(selectedView == "profile" ? Color.lightBlue.opacity(0.3) : Color.clear)
            }
            .listStyle(SidebarListStyle())
            .background(Color.backgroundColor)
        }
        .background(Color.backgroundColor)
    }
} 