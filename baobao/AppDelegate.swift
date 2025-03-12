//
//  AppDelegate.swift
//  baobao
//
//  Created by 钟庆标 on 2025/3/10.
//

import UIKit
import os.log

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "lifecycle")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.info("🚀 应用启动开始")
        
        // 初始化所有服务
        initializeServices()
        
        // 初始化应用数据
        initializeAppData()
        
        // 设置未捕获异常处理
        setupUncaughtExceptionHandler()
        
        // 检查并修复文件冲突
        FileConflictResolver.checkAndResolveConflicts()
        
        // 获取应用程序的工作目录
        let workingDirectory = FileManager.default.currentDirectoryPath
        logger.info("📂 当前工作目录: \(workingDirectory)")
        
        // 获取应用程序的Bundle路径
        let bundlePath = Bundle.main.bundlePath
        logger.info("📂 Bundle路径: \(bundlePath)")
        
        // 获取文档目录
        let documentsPath = FileHelper.documentsDirectory.path
        logger.info("📂 文档目录: \(documentsPath)")
        
        // 定义可能的baobao_prototype目录路径
        let possiblePaths = [
            // 项目根目录
            bundlePath.components(separatedBy: "/baobao.app")[0].components(separatedBy: "/Build")[0] + "/baobao_prototype",
            // 工作目录
            workingDirectory + "/baobao_prototype",
            // 文档目录的上级目录
            documentsPath.components(separatedBy: "/Documents")[0] + "/baobao_prototype",
            // 硬编码的开发目录路径
            "/Users/zhongqingbiao/Documents/baobao/baobao_prototype"
        ]
        
        // 检查并打印所有可能的路径
        for path in possiblePaths {
            logger.info("🔍 检查路径: \(path)")
            if FileManager.default.fileExists(atPath: path) {
                logger.info("✅ 找到baobao_prototype目录: \(path)")
                // 复制到文档目录
                do {
                    let destinationPath = FileHelper.documentsDirectory.appendingPathComponent("baobao_prototype").path
                    if FileManager.default.fileExists(atPath: destinationPath) {
                        try FileManager.default.removeItem(atPath: destinationPath)
                        logger.info("🗑️ 已删除旧的baobao_prototype目录")
                    }
                    try FileManager.default.copyItem(atPath: path, toPath: destinationPath)
                    logger.info("✅ 成功复制baobao_prototype目录到文档目录")
                    return true
                } catch {
                    logger.error("❌ 复制目录失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 如果所有路径都失败，则创建测试资源
        logger.info("⚠️ 未找到baobao_prototype目录，创建测试资源")
        FileHelper.createTestResources()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Private Methods
    
    private func setupUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let logger = Logger(subsystem: "com.baobao.app", category: "crash")
            logger.fault("""
                ❌ 未捕获的异常:
                - 名称: \(exception.name.rawValue)
                - 原因: \(exception.reason ?? "未知")
                - 调用栈: \(exception.callStackSymbols.joined(separator: "\n"))
                """)
        }
    }
    
    // 确保所有服务都被初始化
    private func initializeServices() {
        // 初始化数据服务
        let _ = DataService.shared
        
        // 初始化故事服务
        let _ = StoryService.shared
        
        // 初始化语音服务
        let _: SpeechServiceProtocol = SpeechService.shared
        
        // 初始化API控制器
        let _ = APIController.shared
        
        logger.info("所有服务已初始化完成")
    }
}

// MARK: - UIApplication.State Extension
extension UIApplication.State {
    var description: String {
        switch self {
        case .active:
            return "活跃"
        case .inactive:
            return "不活跃"
        case .background:
            return "后台"
        @unknown default:
            return "未知"
        }
    }
} 