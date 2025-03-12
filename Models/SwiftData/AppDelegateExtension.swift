import Foundation
import UIKit
import os.log

/// AppDelegate扩展，用于在应用启动时初始化数据
extension AppDelegate {
    /// 初始化数据
    func initializeAppData() {
        let logger = Logger(subsystem: "com.baobao.app", category: "AppDelegate")
        logger.info("开始初始化应用数据")
        
        // 初始化数据
        DataInitializer.shared.initializeData { success in
            if success {
                logger.info("应用数据初始化成功")
            } else {
                logger.error("应用数据初始化失败")
            }
        }
        
        // 同步离线模式设置
        let settings = SettingsRepository.shared.getAppSettings()
        NetworkManager.shared.setOfflineMode(enabled: settings.offlineModeEnabled)
        
        logger.info("应用数据初始化完成")
    }
} 