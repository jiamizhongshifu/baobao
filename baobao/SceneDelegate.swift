//
//  SceneDelegate.swift
//  baobao
//
//  Created by 钟庆标 on 2025/3/10.
//

import UIKit
import os.log
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private let logger = Logger(subsystem: "com.baobao.app", category: "scene")
    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { 
            logger.error("❌ 无法获取窗口场景")
            return 
        }
        
        logger.info("🔄 开始配置窗口场景")
        
        // 创建窗口实例
        window = UIWindow(windowScene: windowScene)
        
        // 创建 SwiftUI 视图模型
        let storyViewModel = StoryViewModel()
        let childViewModel = ChildViewModel()
        let audioPlayerViewModel = AudioPlayerViewModel()
        
        // 创建 SwiftUI 视图
        let contentView = ContentView()
            .environmentObject(storyViewModel)
            .environmentObject(childViewModel)
            .environmentObject(audioPlayerViewModel)
        
        // 创建 UIHostingController 来托管 SwiftUI 视图
        let hostingController = UIHostingController(rootView: contentView)
        
        // 设置 hostingController 为窗口的根视图控制器
        window?.rootViewController = hostingController
        
        // 使窗口可见
        window?.makeKeyAndVisible()
        
        // 设置应用的外观
        setupAppearance()
        
        logger.info("✅ 窗口场景配置完成")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        logger.info("场景已断开连接")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        logger.info("场景变为活跃状态")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        logger.info("场景即将进入非活跃状态")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        logger.info("场景即将进入前台")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        logger.info("场景已进入后台")
    }
    
    // 设置应用的外观
    private func setupAppearance() {
        // 设置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "PrimaryBackground")
        appearance.titleTextAttributes = [.foregroundColor: UIColor(named: "PrimaryText") ?? .black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(named: "PrimaryText") ?? .black]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // 设置标签栏外观
        UITabBar.appearance().backgroundColor = UIColor(named: "PrimaryBackground")
    }
} 