import Foundation
import os.log

class FileConflictResolver {
    private static let logger = Logger(subsystem: "com.baobao.app", category: "file-conflict")
    
    /// 检查并解决文件冲突
    static func checkAndResolveConflicts() {
        logger.info("检查文件冲突")
        
        // 检查文档目录中是否存在baobao_prototype目录
        let documentsPrototypePath = FileHelper.documentsDirectory.appendingPathComponent("baobao_prototype").path
        
        if FileManager.default.fileExists(atPath: documentsPrototypePath) {
            logger.info("✅ 文档目录中存在baobao_prototype目录")
            return
        }
        
        // 如果不存在，尝试从Bundle中复制
        if let bundleURL = FileHelper.bundlePrototypeURL {
            do {
                try FileManager.default.copyItem(at: bundleURL, to: FileHelper.documentsDirectory.appendingPathComponent("baobao_prototype"))
                logger.info("✅ 成功从Bundle复制baobao_prototype目录到文档目录")
            } catch {
                logger.error("❌ 复制baobao_prototype目录失败: \(error.localizedDescription)")
                
                // 如果复制失败，创建测试资源
                FileHelper.createTestResources()
            }
        } else {
            logger.warning("⚠️ 未找到baobao_prototype目录，创建测试资源")
            FileHelper.createTestResources()
        }
    }
} 