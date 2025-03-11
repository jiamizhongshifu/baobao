//
//  SceneDelegate.swift
//  baobao
//
//  Created by 钟庆标 on 2025/3/10.
//

import UIKit
import os.log

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
        
        // 创建首页视图控制器
        let homeViewController = HomeViewController()
        
        // 创建导航控制器并设置首页为根视图控制器
        let navigationController = UINavigationController(rootViewController: homeViewController)
        
        // 设置导航控制器为窗口的根视图控制器
        window?.rootViewController = navigationController
        
        // 使窗口可见
        window?.makeKeyAndVisible()
        
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


}

