import Foundation
import os.log

class CopyOriginalResources {
    private static let logger = Logger(subsystem: "com.baobao.app", category: "resource-copy")
    
    /// 复制原始的baobao_prototype目录到文档目录
    static func copyOriginalPrototypeToDocuments() {
        logger.info("🔄 开始复制原始的baobao_prototype目录")
        
        let fileManager = FileManager.default
        let documentsDirectory = FileHelper.documentsDirectory
        
        // 打印当前工作目录
        if let currentPath = fileManager.currentDirectoryPath as String? {
            logger.info("📂 当前工作目录: \(currentPath)")
        }
        
        // 打印应用Bundle路径
        logger.info("📂 应用Bundle路径: \(Bundle.main.bundlePath)")
        
        // 打印文档目录路径
        logger.info("📂 文档目录路径: \(documentsDirectory.path)")
        
        // 获取应用沙盒外的原始baobao_prototype目录
        // 注意：这个路径需要根据实际情况调整
        let possiblePaths = [
            // 项目根目录
            documentsDirectory.deletingLastPathComponent().appendingPathComponent("baobao_prototype"),
            // 上级目录
            documentsDirectory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("baobao_prototype"),
            // 应用Bundle目录
            URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("baobao_prototype"),
            // 应用Bundle的上级目录
            URL(fileURLWithPath: Bundle.main.bundlePath).deletingLastPathComponent().appendingPathComponent("baobao_prototype"),
            // 当前工作目录
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("baobao_prototype"),
            // 硬编码路径（仅用于测试）
            URL(fileURLWithPath: "/Users/zhongqingbiao/Documents/baobao/baobao_prototype")
        ]
        
        // 打印所有可能的路径
        for (index, path) in possiblePaths.enumerated() {
            logger.info("📂 可能的路径 \(index + 1): \(path.path)")
            if fileManager.fileExists(atPath: path.path) {
                logger.info("✅ 路径存在: \(path.path)")
            } else {
                logger.info("❌ 路径不存在: \(path.path)")
            }
        }
        
        var originalPrototypeURL: URL? = nil
        
        // 检查可能的路径
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path.path) {
                originalPrototypeURL = path
                logger.info("✅ 找到原始baobao_prototype目录: \(path.path)")
                break
            }
        }
        
        if let sourceURL = originalPrototypeURL {
            let destinationURL = documentsDirectory.appendingPathComponent("baobao_prototype")
            
            do {
                // 如果目标目录已存在，先删除
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                    logger.info("🗑️ 已删除旧的baobao_prototype目录")
                }
                
                // 创建目标目录
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                logger.info("✅ 创建目标目录: \(destinationURL.path)")
                
                // 复制目录内容，排除Swift文件
                try copyDirectoryContents(from: sourceURL, to: destinationURL, excludingExtensions: ["swift"])
                
                // 列出复制的文件
                if let contents = try? fileManager.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil) {
                    logger.info("📄 目录内容 (\(destinationURL.lastPathComponent)):")
                    contents.forEach { fileURL in
                        logger.info("- \(fileURL.lastPathComponent)")
                    }
                }
                
            } catch {
                logger.error("❌ 复制原始baobao_prototype目录失败: \(error.localizedDescription)")
                // 如果复制失败，使用FileHelper创建测试资源
                FileHelper.createTestResources()
            }
        } else {
            logger.error("❌ 无法找到原始baobao_prototype目录")
            
            // 尝试在应用Bundle中查找baobao_prototype目录
            if let bundleURL = Bundle.main.url(forResource: "baobao_prototype", withExtension: nil) {
                logger.info("✅ 在应用Bundle中找到baobao_prototype目录: \(bundleURL.path)")
                
                let destinationURL = documentsDirectory.appendingPathComponent("baobao_prototype")
                
                do {
                    // 如果目标目录已存在，先删除
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                        logger.info("🗑️ 已删除旧的baobao_prototype目录")
                    }
                    
                    // 创建目标目录
                    try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                    logger.info("✅ 创建目标目录: \(destinationURL.path)")
                    
                    // 复制目录内容，排除Swift文件
                    try copyDirectoryContents(from: bundleURL, to: destinationURL, excludingExtensions: ["swift"])
                    
                    // 列出复制的文件
                    if let contents = try? fileManager.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil) {
                        logger.info("📄 目录内容 (\(destinationURL.lastPathComponent)):")
                        contents.forEach { fileURL in
                            logger.info("- \(fileURL.lastPathComponent)")
                        }
                    }
                    
                    return
                } catch {
                    logger.error("❌ 复制应用Bundle中的baobao_prototype目录失败: \(error.localizedDescription)")
                }
            }
            
            // 如果找不到原始目录，使用FileHelper创建测试资源
            FileHelper.createTestResources()
        }
    }
    
    /// 复制目录内容，排除指定扩展名的文件
    private static func copyDirectoryContents(from sourceURL: URL, to destinationURL: URL, excludingExtensions: [String]) throws {
        let fileManager = FileManager.default
        
        // 获取源目录中的所有内容
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil, options: [])
        
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            let fileExtension = fileURL.pathExtension.lowercased()
            
            // 检查是否应该排除此文件
            if excludingExtensions.contains(fileExtension) {
                logger.info("⏭️ 跳过文件: \(fileName) (扩展名: \(fileExtension))")
                continue
            }
            
            let destinationFileURL = destinationURL.appendingPathComponent(fileName)
            
            // 检查是否是目录
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // 如果是目录，创建目标目录并递归复制内容
                try fileManager.createDirectory(at: destinationFileURL, withIntermediateDirectories: true, attributes: nil)
                try copyDirectoryContents(from: fileURL, to: destinationFileURL, excludingExtensions: excludingExtensions)
            } else {
                // 如果是文件，直接复制
                try fileManager.copyItem(at: fileURL, to: destinationFileURL)
                logger.info("✅ 复制文件: \(fileName)")
            }
        }
    }
} 