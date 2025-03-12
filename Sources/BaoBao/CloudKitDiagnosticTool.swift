import Foundation
import CloudKit
import os.log

/// CloudKit诊断工具
class CloudKitDiagnosticTool {
    /// 共享实例
    static let shared = CloudKitDiagnosticTool()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "CloudKitDiagnosticTool")
    
    /// CloudKit容器
    private let container: CKContainer
    
    /// 初始化
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.example.baobao")
    }
    
    /// 运行诊断测试
    /// - Parameter completion: 完成回调
    func runDiagnostics(completion: @escaping (String) -> Void) {
        logger.info("🔍 开始CloudKit诊断")
        
        var report = "=== CloudKit诊断报告 ===\n"
        report += "时间: \(Date())\n"
        report += "设备: \(UIDevice.current.name)\n"
        report += "系统: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n\n"
        
        // 检查iCloud容器配置
        report += "容器标识符: \(container.containerIdentifier ?? "未知")\n\n"
        
        // 检查是否启用了CloudKit同步
        let isEnabled = ConfigurationManager.shared.cloudKitSyncEnabled
        report += "CloudKit同步配置: \(isEnabled ? "已启用" : "已禁用")\n\n"
        
        // 检查账户状态
        checkAccountStatus { accountReport in
            report += accountReport
            
            // 检查权限
            self.checkPermissions { permissionsReport in
                report += permissionsReport
                
                // 检查网络连接
                self.checkNetworkConnection { networkReport in
                    report += networkReport
                    
                    // 检查区域和记录
                    self.checkZonesAndRecords { zonesReport in
                        report += zonesReport
                        
                        self.logger.info("✅ CloudKit诊断完成")
                        completion(report)
                    }
                }
            }
        }
    }
    
    /// 检查账户状态
    /// - Parameter completion: 完成回调
    private func checkAccountStatus(completion: @escaping (String) -> Void) {
        logger.info("🔍 检查iCloud账户状态")
        
        var report = "== iCloud账户状态 ==\n"
        
        container.accountStatus { status, error in
            if let error = error {
                report += "错误: \(error.localizedDescription)\n\n"
                completion(report)
                return
            }
            
            switch status {
            case .available:
                report += "状态: 可用 ✅\n"
            case .noAccount:
                report += "状态: 无账户 ❌\n"
                report += "解决方案: 请登录iCloud账户\n"
            case .restricted:
                report += "状态: 受限 ⚠️\n"
                report += "解决方案: 检查家长控制设置\n"
            case .couldNotDetermine:
                report += "状态: 无法确定 ❓\n"
                report += "解决方案: 检查网络连接和iCloud设置\n"
            @unknown default:
                report += "状态: 未知 ❓\n"
            }
            
            // 获取用户ID
            self.container.fetchUserRecordID { recordID, error in
                if let error = error {
                    report += "获取用户ID错误: \(error.localizedDescription)\n\n"
                } else if let recordID = recordID {
                    report += "用户ID: \(recordID.recordName)\n\n"
                } else {
                    report += "无法获取用户ID\n\n"
                }
                
                completion(report)
            }
        }
    }
    
    /// 检查权限
    /// - Parameter completion: 完成回调
    private func checkPermissions(completion: @escaping (String) -> Void) {
        logger.info("🔍 检查CloudKit权限")
        
        var report = "== CloudKit权限 ==\n"
        
        container.requestApplicationPermission(.userDiscoverability) { status, error in
            if let error = error {
                report += "权限检查错误: \(error.localizedDescription)\n\n"
                completion(report)
                return
            }
            
            switch status {
            case .granted:
                report += "用户可发现性: 已授权 ✅\n\n"
            case .denied:
                report += "用户可发现性: 已拒绝 ❌\n"
                report += "解决方案: 在设置中授权iCloud访问\n\n"
            case .initialState:
                report += "用户可发现性: 初始状态 ⚠️\n"
                report += "解决方案: 需要请求权限\n\n"
            case .couldNotComplete:
                report += "用户可发现性: 无法完成 ❌\n"
                report += "解决方案: 检查网络连接和iCloud设置\n\n"
            @unknown default:
                report += "用户可发现性: 未知状态 ❓\n\n"
            }
            
            completion(report)
        }
    }
    
    /// 检查网络连接
    /// - Parameter completion: 完成回调
    private func checkNetworkConnection(completion: @escaping (String) -> Void) {
        logger.info("🔍 检查网络连接")
        
        var report = "== 网络连接 ==\n"
        
        // 简单的网络连接测试
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        let url = URL(string: "https://www.apple.com")!
        let task = session.dataTask(with: url) { _, response, error in
            if let error = error {
                report += "网络测试错误: \(error.localizedDescription)\n\n"
            } else if let httpResponse = response as? HTTPURLResponse {
                report += "网络测试响应码: \(httpResponse.statusCode)\n"
                report += "网络状态: \(httpResponse.statusCode == 200 ? "正常 ✅" : "异常 ⚠️")\n\n"
            } else {
                report += "获取网络响应失败\n\n"
            }
            
            completion(report)
        }
        task.resume()
    }
    
    /// 检查区域和记录
    /// - Parameter completion: 完成回调
    private func checkZonesAndRecords(completion: @escaping (String) -> Void) {
        logger.info("🔍 检查CloudKit区域和记录")
        
        var report = "== CloudKit区域和记录 ==\n"
        
        // 获取自定义区域
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "BaoBaoZone", ownerName: CKCurrentUserDefaultName)
        
        database.fetch(withRecordZoneID: zoneID) { zone, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == CKError.zoneNotFound.rawValue {
                    report += "BaoBaoZone: 不存在 ⚠️\n"
                    report += "解决方案: 需要创建自定义区域\n\n"
                } else {
                    report += "检查区域错误: \(error.localizedDescription)\n\n"
                }
            } else if zone != nil {
                report += "BaoBaoZone: 存在 ✅\n"
                
                // 尝试获取记录数量
                let query = CKQuery(recordType: "Story", predicate: NSPredicate(value: true))
                database.perform(query, inZoneWith: zoneID) { records, error in
                    if let error = error {
                        report += "查询记录错误: \(error.localizedDescription)\n\n"
                    } else {
                        let storyCount = records?.count ?? 0
                        report += "故事记录数: \(storyCount)\n\n"
                    }
                    
                    completion(report)
                }
            } else {
                report += "区域检查结果不明确\n\n"
                completion(report)
            }
        }
    }
    
    /// 清理CloudKit数据
    /// - Parameter completion: 完成回调
    func clearCloudKitData(completion: @escaping (Result<Void, Error>) -> Void) {
        logger.warning("⚠️ 开始清理CloudKit数据")
        
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "BaoBaoZone", ownerName: CKCurrentUserDefaultName)
        
        // 删除区域将同时删除区域中的所有记录
        database.delete(withRecordZoneID: zoneID) { zoneID, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == CKError.zoneNotFound.rawValue {
                    // 区域不存在，视为成功
                    self.logger.info("✅ CloudKit区域不存在，无需清理")
                    completion(.success(()))
                } else {
                    self.logger.error("❌ 删除CloudKit区域失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                self.logger.info("✅ 已成功清理CloudKit数据")
                completion(.success(()))
            }
        }
    }
    
    /// 创建诊断报告文件
    /// - Parameter report: 报告内容
    /// - Returns: 文件URL
    func saveDiagnosticReport(_ report: String) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "CloudKit_Diagnostic_\(formatter.string(from: Date())).txt"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("✅ 诊断报告已保存: \(fileURL.path)")
            return fileURL
        } catch {
            logger.error("❌ 保存诊断报告失败: \(error.localizedDescription)")
            return nil
        }
    }
} 