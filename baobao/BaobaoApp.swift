import SwiftUI

@main
struct BaobaoApp: App {
    // 环境对象，用于在整个应用中共享数据
    @StateObject private var storyViewModel = StoryViewModel()
    @StateObject private var childViewModel = ChildViewModel()
    @StateObject private var audioPlayerViewModel = AudioPlayerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storyViewModel)
                .environmentObject(childViewModel)
                .environmentObject(audioPlayerViewModel)
                .onAppear {
                    // 应用启动时的初始化操作
                    setupAppearance()
                }
        }
    }
    
    // 设置应用的外观
    private func setupAppearance() {
        // 设置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color("PrimaryBackground"))
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color("PrimaryText"))]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color("PrimaryText"))]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // 设置标签栏外观
        UITabBar.appearance().backgroundColor = UIColor(Color("PrimaryBackground"))
    }
} 