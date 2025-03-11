import Foundation
import os.log

class FileConflictResolver {
    private static let logger = Logger(subsystem: "com.baobao.app", category: "conflict-resolver")
    
    /// 检查并修复项目中的文件冲突
    static func checkAndResolveConflicts() {
        logger.info("🔍 开始检查文件冲突")
        
        let fileManager = FileManager.default
        let documentsDirectory = FileHelper.documentsDirectory
        
        // 检查文档目录中的baobao_prototype目录
        let prototypeURL = documentsDirectory.appendingPathComponent("baobao_prototype")
        
        if fileManager.fileExists(atPath: prototypeURL.path) {
            logger.info("✅ 找到baobao_prototype目录: \(prototypeURL.path)")
            
            // 检查并修复可能冲突的文件
            do {
                let contents = try fileManager.contentsOfDirectory(at: prototypeURL, includingPropertiesForKeys: nil)
                
                // 检查顶级目录中的冲突文件
                for fileURL in contents {
                    checkAndRenameConflictFile(fileURL)
                }
                
                // 检查子目录中的冲突文件
                for fileURL in contents {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                        if let subContents = try? fileManager.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: nil) {
                            for subFileURL in subContents {
                                checkAndRenameConflictFile(subFileURL)
                            }
                        }
                    }
                }
                
                logger.info("✅ 文件冲突检查完成")
                
            } catch {
                logger.error("❌ 检查文件冲突失败: \(error.localizedDescription)")
            }
        } else {
            logger.info("⚠️ 未找到baobao_prototype目录")
        }
    }
    
    /// 检查并重命名冲突文件
    private static func checkAndRenameConflictFile(_ fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        
        // 检查是否是Swift文件
        if fileName.hasSuffix(".swift") {
            // 检查是否是冲突文件
            let conflictFiles = ["AppDelegate.swift", "SceneDelegate.swift", "ViewController.swift"]
            
            if conflictFiles.contains(fileName) {
                let newFileName = fileName.replacingOccurrences(of: ".swift", with: "Prototype.swift")
                let newFileURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFileName)
                
                do {
                    try FileManager.default.moveItem(at: fileURL, to: newFileURL)
                    logger.info("🔄 重命名文件: \(fileName) -> \(newFileName)")
                } catch {
                    logger.error("❌ 重命名文件失败: \(error.localizedDescription)")
                }
            }
        }
    }
} 