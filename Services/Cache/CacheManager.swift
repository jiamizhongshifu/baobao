import Foundation
import os.log

/// 缓存类型
enum CacheType: String {
    case story = "stories"
    case speech = "speech"
    case image = "images"
}

/// 缓存管理器，负责管理应用缓存
class CacheManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = CacheManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.cache", category: "CacheManager")
    
    /// 缓存根目录
    private let cacheRootDirectory: URL = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.baobao.cache", isDirectory: true)
        
        // 创建缓存根目录
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        return cacheDir
    }()
    
    /// 缓存目录字典
    private var cacheDirectories: [CacheType: URL] = [:]
    
    /// 最大缓存时间（秒）
    private var maxCacheAge: TimeInterval {
        return TimeInterval(ConfigurationManager.shared.maxCacheAgeDays * 24 * 60 * 60)
    }
    
    /// 最大缓存大小（字节）
    private var maxCacheSize: Int64 {
        return Int64(ConfigurationManager.shared.maxCacheSizeMB) * 1024 * 1024
    }
    
    // MARK: - 初始化
    
    private init() {
        setupCacheDirectories()
        cleanExpiredCache()
    }
    
    // MARK: - 公共方法
    
    /// 保存数据到缓存
    /// - Parameters:
    ///   - data: 要缓存的数据
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    func saveToCache(data: Data, forKey key: String, type: CacheType) -> URL? {
        // 检查缓存大小
        checkCacheSize()
        
        // 获取缓存文件路径
        let cacheFile = cacheFileURL(forKey: key, type: type)
        
        do {
            // 创建缓存目录（如果不存在）
            try FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            // 写入数据
            try data.write(to: cacheFile)
            
            logger.info("已缓存数据: \(key) (\(data.count) 字节)")
            return cacheFile
        } catch {
            logger.error("缓存数据失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 保存文件到缓存
    /// - Parameters:
    ///   - fileURL: 源文件URL
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    func saveFileToCache(fileURL: URL, forKey key: String, type: CacheType) -> URL? {
        // 检查缓存大小
        checkCacheSize()
        
        // 获取缓存文件路径
        let cacheFile = cacheFileURL(forKey: key, type: type)
        
        do {
            // 创建缓存目录（如果不存在）
            try FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: cacheFile.path) {
                try FileManager.default.removeItem(at: cacheFile)
            }
            
            // 复制文件
            try FileManager.default.copyItem(at: fileURL, to: cacheFile)
            
            // 获取文件大小
            let attributes = try FileManager.default.attributesOfItem(atPath: cacheFile.path)
            if let fileSize = attributes[.size] as? Int64 {
                logger.info("已缓存文件: \(key) (\(fileSize) 字节)")
            } else {
                logger.info("已缓存文件: \(key)")
            }
            
            return cacheFile
        } catch {
            logger.error("缓存文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 保存文本到缓存
    /// - Parameters:
    ///   - text: 要缓存的文本
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    func saveTextToCache(text: String, forKey key: String, type: CacheType) -> URL? {
        guard let data = text.data(using: .utf8) else {
            logger.error("文本转换为数据失败")
            return nil
        }
        
        return saveToCache(data: data, forKey: key, type: type)
    }
    
    /// 从缓存获取数据
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存的数据
    func dataFromCache(forKey key: String, type: CacheType) -> Data? {
        let cacheFile = cacheFileURL(forKey: key, type: type)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return nil
        }
        
        // 检查文件是否过期
        if isFileExpired(at: cacheFile) {
            // 删除过期文件
            try? FileManager.default.removeItem(at: cacheFile)
            return nil
        }
        
        do {
            // 读取数据
            let data = try Data(contentsOf: cacheFile)
            logger.info("从缓存读取数据: \(key) (\(data.count) 字节)")
            return data
        } catch {
            logger.error("读取缓存数据失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从缓存获取文本
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存的文本
    func textFromCache(forKey key: String, type: CacheType) -> String? {
        guard let data = dataFromCache(forKey: key, type: type) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// 从缓存获取文件URL
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    func fileURLFromCache(forKey key: String, type: CacheType) -> URL? {
        let cacheFile = cacheFileURL(forKey: key, type: type)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return nil
        }
        
        // 检查文件是否过期
        if isFileExpired(at: cacheFile) {
            // 删除过期文件
            try? FileManager.default.removeItem(at: cacheFile)
            return nil
        }
        
        return cacheFile
    }
    
    /// 检查缓存是否存在
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 是否存在
    func hasCached(forKey key: String, type: CacheType) -> Bool {
        let cacheFile = cacheFileURL(forKey: key, type: type)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return false
        }
        
        // 检查文件是否过期
        if isFileExpired(at: cacheFile) {
            // 删除过期文件
            try? FileManager.default.removeItem(at: cacheFile)
            return false
        }
        
        return true
    }
    
    /// 从缓存中移除
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    func removeFromCache(forKey key: String, type: CacheType) {
        let cacheFile = cacheFileURL(forKey: key, type: type)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return
        }
        
        do {
            // 删除文件
            try FileManager.default.removeItem(at: cacheFile)
            logger.info("已从缓存中移除: \(key)")
        } catch {
            logger.error("从缓存中移除失败: \(error.localizedDescription)")
        }
    }
    
    /// 清空缓存
    /// - Parameter type: 缓存类型，如果为nil则清空所有缓存
    func clearCache(type: CacheType? = nil) {
        if let type = type {
            // 清空指定类型的缓存
            guard let cacheDir = cacheDirectories[type] else {
                return
            }
            
            do {
                // 获取缓存目录中的所有文件
                let cacheFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
                
                // 删除所有文件
                for fileURL in cacheFiles {
                    try FileManager.default.removeItem(at: fileURL)
                }
                
                logger.info("已清空缓存: \(type.rawValue)")
            } catch {
                logger.error("清空缓存失败: \(error.localizedDescription)")
            }
        } else {
            // 清空所有缓存
            do {
                // 获取缓存根目录中的所有文件
                let cacheDirs = try FileManager.default.contentsOfDirectory(at: cacheRootDirectory, includingPropertiesForKeys: nil)
                
                // 删除所有文件
                for dirURL in cacheDirs {
                    try FileManager.default.removeItem(at: dirURL)
                }
                
                // 重新创建缓存目录
                setupCacheDirectories()
                
                logger.info("已清空所有缓存")
            } catch {
                logger.error("清空所有缓存失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 获取缓存大小
    /// - Parameter type: 缓存类型，如果为nil则获取所有缓存大小
    /// - Returns: 缓存大小（字节）
    func cacheSize(type: CacheType? = nil) -> Int64 {
        if let type = type {
            // 获取指定类型的缓存大小
            guard let cacheDir = cacheDirectories[type] else {
                return 0
            }
            
            return directorySize(at: cacheDir)
        } else {
            // 获取所有缓存大小
            return directorySize(at: cacheRootDirectory)
        }
    }
    
    // MARK: - 私有方法
    
    /// 设置缓存目录
    private func setupCacheDirectories() {
        // 为每种缓存类型创建目录
        for type in CacheType.allCases {
            let cacheDir = cacheRootDirectory.appendingPathComponent(type.rawValue, isDirectory: true)
            
            // 创建缓存目录
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            // 保存缓存目录
            cacheDirectories[type] = cacheDir
        }
    }
    
    /// 获取缓存文件URL
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    private func cacheFileURL(forKey key: String, type: CacheType) -> URL {
        // 获取缓存目录
        guard let cacheDir = cacheDirectories[type] else {
            fatalError("未找到缓存目录: \(type.rawValue)")
        }
        
        // 生成文件名
        let fileName = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        
        // 根据缓存类型确定文件扩展名
        let fileExtension: String
        switch type {
        case .story:
            fileExtension = "txt"
        case .speech:
            fileExtension = "mp3"
        case .image:
            fileExtension = "png"
        }
        
        // 返回完整的文件URL
        return cacheDir.appendingPathComponent("\(fileName).\(fileExtension)")
    }
    
    /// 检查文件是否过期
    /// - Parameter fileURL: 文件URL
    /// - Returns: 是否过期
    private func isFileExpired(at fileURL: URL) -> Bool {
        do {
            // 获取文件属性
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            
            // 获取文件创建日期
            if let creationDate = attributes[.creationDate] as? Date {
                // 计算文件年龄
                let age = Date().timeIntervalSince(creationDate)
                
                // 检查是否超过最大缓存时间
                return age > maxCacheAge
            }
        } catch {
            logger.error("获取文件属性失败: \(error.localizedDescription)")
        }
        
        // 如果无法获取文件属性，默认为过期
        return true
    }
    
    /// 清理过期缓存
    private func cleanExpiredCache() {
        // 遍历所有缓存类型
        for (type, cacheDir) in cacheDirectories {
            do {
                // 获取缓存目录中的所有文件
                let cacheFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
                
                var expiredCount = 0
                
                // 检查每个文件是否过期
                for fileURL in cacheFiles {
                    if isFileExpired(at: fileURL) {
                        // 删除过期文件
                        try FileManager.default.removeItem(at: fileURL)
                        expiredCount += 1
                    }
                }
                
                if expiredCount > 0 {
                    logger.info("已清理 \(expiredCount) 个过期缓存文件 (\(type.rawValue))")
                }
            } catch {
                logger.error("清理过期缓存失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 检查缓存大小
    private func checkCacheSize() {
        // 获取当前缓存大小
        let currentSize = cacheSize()
        
        // 检查是否超过最大缓存大小
        if currentSize > maxCacheSize {
            // 清理最旧的缓存文件
            cleanOldestCacheFiles()
        }
    }
    
    /// 清理最旧的缓存文件
    private func cleanOldestCacheFiles() {
        // 遍历所有缓存类型
        for (type, cacheDir) in cacheDirectories {
            do {
                // 获取缓存目录中的所有文件
                let cacheFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
                
                // 按创建日期排序
                let sortedFiles = cacheFiles.sorted { file1, file2 in
                    do {
                        let attrs1 = try file1.resourceValues(forKeys: [.creationDateKey])
                        let attrs2 = try file2.resourceValues(forKeys: [.creationDateKey])
                        
                        guard let date1 = attrs1.creationDate, let date2 = attrs2.creationDate else {
                            return false
                        }
                        
                        return date1 < date2
                    } catch {
                        return false
                    }
                }
                
                // 删除最旧的30%的文件
                let filesToDelete = Int(Double(sortedFiles.count) * 0.3)
                for i in 0..<min(filesToDelete, sortedFiles.count) {
                    try FileManager.default.removeItem(at: sortedFiles[i])
                }
                
                if filesToDelete > 0 {
                    logger.info("已清理 \(filesToDelete) 个最旧的缓存文件 (\(type.rawValue))")
                }
            } catch {
                logger.error("清理最旧缓存文件失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 计算目录大小
    /// - Parameter directoryURL: 目录URL
    /// - Returns: 目录大小（字节）
    private func directorySize(at directoryURL: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        
        // 获取文件枚举器
        guard let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        // 遍历目录中的所有文件
        for case let fileURL as URL in enumerator {
            do {
                // 获取文件属性
                let resourceValues = try fileURL.resourceValues(forKeys: keys)
                
                // 如果是目录，跳过（枚举器会自动遍历子目录）
                if resourceValues.isDirectory == true {
                    continue
                }
                
                // 累加文件大小
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                logger.error("获取文件大小失败: \(error.localizedDescription)")
            }
        }
        
        return totalSize
    }
}

// MARK: - CacheType扩展

extension CacheType: CaseIterable {} 