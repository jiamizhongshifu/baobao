//
//  AppDelegate.swift
//  baobao
//
//  Created by 钟庆标 on 2025/3/10.
//

import UIKit
import CloudKit
import BackgroundTasks
import os.log

class AppDelegate: UIResponder, UIApplicationDelegate {
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "lifecycle")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.info("🚀 应用启动开始")
        
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
        
        // 初始化服务组件
        logger.info("🌩️ 开始初始化核心服务")
        
        logger.info("🔧 初始化配置管理器")
        let configManager = ConfigurationManager.shared
        logger.info("📊 配置管理器初始化完成，CloudKit配置：\(configManager.cloudKitSyncEnabled ? "已启用" : "已禁用")")
        
        logger.info("🌩️ 初始化CloudKit同步服务")
        let cloudKitService = CloudKitSyncService.shared
        logger.info("🌩️ CloudKit同步服务状态: \(cloudKitService.syncStatus)")
        
        logger.info("💾 初始化数据服务")
        let dataService = DataService.shared
        
        // 配置远程通知
        logger.info("🔔 配置远程通知")
        configureRemoteNotifications(application)
        
        // 注册后台任务
        logger.info("⏱️ 注册后台任务")
        registerBackgroundTasks()
        
        // 如果CloudKit同步已启用并且可用，安排定期同步
        if configManager.cloudKitSyncEnabled && cloudKitService.syncStatus == .available {
            logger.info("🔄 安排CloudKit定期同步")
            scheduleSync()
        }
        
        logger.info("🚀 应用启动完成")
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
    
    // MARK: - 远程通知
    
    /// 配置远程通知
    /// - Parameter application: 应用实例
    private func configureRemoteNotifications(_ application: UIApplication) {
        // 注册远程通知
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        notificationCenter.requestAuthorization(options: options) { granted, error in
            if granted {
                self.logger.info("✅ 用户授予通知权限")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else if let error = error {
                self.logger.error("❌ 请求通知权限失败: \(error.localizedDescription)")
            } else {
                self.logger.warning("⚠️ 用户拒绝了通知权限")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        logger.info("✅ 成功注册APNs，设备令牌: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("❌ 注册APNs失败: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // 如果这是一个CloudKit通知，处理它
        if let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            handleCloudKitNotification(cloudKitNotification, completionHandler: completionHandler)
        } else {
            completionHandler(.noData)
        }
    }
    
    /// 处理CloudKit通知
    /// - Parameters:
    ///   - notification: CloudKit通知
    ///   - completionHandler: 完成处理器
    private func handleCloudKitNotification(_ notification: CKNotification, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("📬 收到CloudKit通知")
        
        if !ConfigurationManager.shared.cloudKitSyncEnabled {
            logger.info("ℹ️ CloudKit同步未启用，忽略通知")
            completionHandler(.noData)
            return
        }
        
        // 检查是否是数据库通知
        if notification.notificationType == .database {
            // 执行同步
            DataService.shared.triggerSync { result in
                switch result {
                case .success:
                    self.logger.info("✅ CloudKit通知处理完成，数据已同步")
                    completionHandler(.newData)
                case .failure(let error):
                    self.logger.error("❌ CloudKit通知处理失败: \(error.localizedDescription)")
                    completionHandler(.failed)
                }
            }
        } else {
            logger.info("ℹ️ 非数据库通知，忽略")
            completionHandler(.noData)
        }
    }
    
    // MARK: - 后台任务
    
    /// 注册后台任务
    private func registerBackgroundTasks() {
        // 注册定期同步任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.baobao.sync", using: nil) { task in
            self.handleSyncTask(task as! BGProcessingTask)
        }
        
        logger.info("✅ 注册后台同步任务")
    }
    
    /// 处理同步任务
    /// - Parameter task: 后台处理任务
    private func handleSyncTask(_ task: BGProcessingTask) {
        // 安排下一次同步
        scheduleSync()
        
        // 添加任务到期取消
        let expirationHandler = {
            task.setTaskCompleted(success: false)
            self.logger.warning("⚠️ 后台同步任务未完成就到期了")
        }
        task.expirationHandler = expirationHandler
        
        // 如果同步未启用，立即完成任务
        if !ConfigurationManager.shared.cloudKitSyncEnabled {
            task.setTaskCompleted(success: true)
            return
        }
        
        // 执行同步
        DataService.shared.triggerSync { result in
            switch result {
            case .success:
                self.logger.info("✅ 后台同步任务完成")
                task.setTaskCompleted(success: true)
            case .failure(let error):
                self.logger.error("❌ 后台同步任务失败: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    /// 安排下一次同步
    func scheduleSync() {
        // 只有在启用了同步的情况下才安排
        guard ConfigurationManager.shared.cloudKitSyncEnabled else {
            return
        }
        
        let syncFrequencyHours = ConfigurationManager.shared.syncFrequencyHours
        let request = BGProcessingTaskRequest(identifier: "com.example.baobao.sync")
        
        // 设置最早开始时间，默认为syncFrequencyHours小时后
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(syncFrequencyHours) * 3600)
        
        // 要求网络连接
        request.requiresNetworkConnectivity = true
        
        // 如果设置了仅Wi-Fi同步，则要求在电源上
        request.requiresExternalPower = ConfigurationManager.shared.syncOnWifiOnly
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("✅ 成功安排下一次后台同步，将在\(syncFrequencyHours)小时后执行")
        } catch {
            logger.error("❌ 安排后台同步失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 应用在前台时收到通知
        completionHandler([.sound, .banner, .list])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 用户点击通知
        completionHandler()
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

