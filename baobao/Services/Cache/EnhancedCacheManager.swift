import Foundation
import os.log
import UIKit
import CommonCrypto

/// 增强型缓存管理器，提供内存缓存和磁盘缓存的两级缓存策略
class EnhancedCacheManager {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = EnhancedCacheManager()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.cache", category: "EnhancedCacheManager")
    
    /// 内存缓存
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    /// 磁盘缓存目录
    private let diskCacheDirectory: URL
    
    /// 缓存访问计数器
    private var accessCounters: [String: Int] = [:]
    
    /// 缓存访问时间记录
    private var lastAccessTimes: [String: Date] = [:]
    
    /// 缓存统计信息
    private(set) var statistics = CacheStatistics()
    
    // MARK: - 初始化
    
    private init() {
        // 设置内存缓存限制
        memoryCache.countLimit = 100 // 最多缓存100个对象
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 最大50MB
        
        // 创建磁盘缓存目录
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDirectory.appendingPathComponent("BaobaoDiskCache")
        
        do {
            try FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("创建缓存目录失败: \(error.localizedDescription)")
        }
        
        // 注册内存警告通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        logger.info("增强型缓存管理器初始化完成")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 公共方法
    
    /// 从缓存获取数据
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存的数据
    func getData(forKey key: String, type: CacheCategory) -> Data? {
        let cacheKey = generateCacheKey(key: key, type: type)
        
        // 记录缓存访问
        recordCacheAccess(key: cacheKey)
        
        // 先检查内存缓存
        if let cachedData = memoryCache.object(forKey: cacheKey as NSString) as? Data {
            logger.debug("从内存缓存获取数据: \(key) (\(cachedData.count) 字节)")
            statistics.memoryHits += 1
            return cachedData
        }
        
        statistics.memoryMisses += 1
        
        // 再检查磁盘缓存
        if let diskData = dataFromDiskCache(forKey: key, type: type) {
            // 添加到内存缓存
            memoryCache.setObject(diskData as NSData, forKey: cacheKey as NSString)
            logger.debug("从磁盘缓存获取数据并添加到内存缓存: \(key) (\(diskData.count) 字节)")
            statistics.diskHits += 1
            return diskData
        }
        
        statistics.diskMisses += 1
        logger.debug("缓存未命中: \(key)")
        return nil
    }
    
    /// 保存数据到缓存
    /// - Parameters:
    ///   - data: 要缓存的数据
    ///   - key: 缓存键
    ///   - type: 缓存类型
    ///   - cost: 内存缓存成本（默认为数据大小）
    /// - Returns: 缓存文件URL
    @discardableResult
    func saveData(_ data: Data, forKey key: String, type: CacheCategory, cost: Int? = nil) -> URL? {
        let cacheKey = generateCacheKey(key: key, type: type)
        
        // 保存到内存缓存
        memoryCache.setObject(data as NSData, forKey: cacheKey as NSString, cost: cost ?? data.count)
        
        // 保存到磁盘缓存
        let fileURL = saveToDiskCache(data: data, forKey: key, type: type)
        
        logger.debug("数据已保存到缓存: \(key) (\(data.count) 字节)")
        return fileURL
    }
    
    /// 保存文本到缓存
    /// - Parameters:
    ///   - text: 要缓存的文本
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    @discardableResult
    func saveText(_ text: String, forKey key: String, type: CacheCategory) -> URL? {
        guard let data = text.data(using: .utf8) else {
            logger.error("文本转换为数据失败: \(key)")
            return nil
        }
        
        return saveData(data, forKey: key, type: type)
    }
    
    /// 从缓存获取文本
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存的文本
    func getText(forKey key: String, type: CacheCategory) -> String? {
        guard let data = getData(forKey: key, type: type) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// 保存文件到缓存
    /// - Parameters:
    ///   - fileURL: 源文件URL
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    @discardableResult
    func saveFile(at fileURL: URL, forKey key: String, type: CacheCategory) -> URL? {
        do {
            let data = try Data(contentsOf: fileURL)
            return saveData(data, forKey: key, type: type)
        } catch {
            logger.error("读取文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从缓存获取文件URL
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 缓存文件URL
    func getFileURL(forKey key: String, type: CacheCategory) -> URL? {
        let cacheKey = generateCacheKey(key: key, type: type)
        
        // 记录缓存访问
        recordCacheAccess(key: cacheKey)
        
        // 直接从磁盘缓存获取文件URL
        return fileURLFromDiskCache(forKey: key, type: type)
    }
    
    /// 检查缓存是否存在
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    /// - Returns: 是否存在
    func hasCached(forKey key: String, type: CacheCategory) -> Bool {
        let cacheKey = generateCacheKey(key: key, type: type)
        
        // 检查内存缓存
        if memoryCache.object(forKey: cacheKey as NSString) != nil {
            return true
        }
        
        // 检查磁盘缓存
        return hasDiskCached(forKey: key, type: type)
    }
    
    /// 从缓存中移除
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 缓存类型
    func removeFromCache(forKey key: String, type: CacheCategory) {
        let cacheKey = generateCacheKey(key: key, type: type)
        
        // 从内存缓存中移除
        memoryCache.removeObject(forKey: cacheKey as NSString)
        
        // 从磁盘缓存中移除
        removeFromDiskCache(forKey: key, type: type)
        
        // 清理访问记录
        accessCounters.removeValue(forKey: cacheKey)
        lastAccessTimes.removeValue(forKey: cacheKey)
        
        logger.debug("已从缓存中移除: \(key)")
    }
    
    /// 清空内存缓存
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        accessCounters.removeAll()
        lastAccessTimes.removeAll()
        
        logger.info("内存缓存已清空")
    }
    
    /// 清空所有缓存
    /// - Parameter type: 缓存类型，如果为nil则清空所有缓存
    func clearCache(type: CacheCategory? = nil) {
        // 清空内存缓存
        if type == nil {
            clearMemoryCache()
        } else {
            // 清除特定类型的内存缓存
            let keysToRemove = accessCounters.keys.filter { $0.contains(type!.rawValue) }
            for key in keysToRemove {
                memoryCache.removeObject(forKey: key as NSString)
                accessCounters.removeValue(forKey: key)
                lastAccessTimes.removeValue(forKey: key)
            }
        }
        
        // 清空磁盘缓存
        clearDiskCache(type: type)
        
        logger.info("缓存已清空: \(type?.rawValue ?? "all")")
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    func getCacheStatistics() -> CacheStatistics {
        return statistics
    }
    
    /// 重置缓存统计信息
    func resetStatistics() {
        statistics = CacheStatistics()
    }
    
    // MARK: - 磁盘缓存方法
    
    /// 从磁盘缓存获取数据
    private func dataFromDiskCache(forKey key: String, type: CacheCategory) -> Data? {
        let fileURL = diskCacheFileURL(forKey: key, type: type)
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            return nil
        }
    }
    
    /// 保存数据到磁盘缓存
    @discardableResult
    private func saveToDiskCache(data: Data, forKey key: String, type: CacheCategory) -> URL {
        let fileURL = diskCacheFileURL(forKey: key, type: type)
        
        do {
            try data.write(to: fileURL)
        } catch {
            logger.error("保存到磁盘缓存失败: \(error.localizedDescription)")
        }
        
        return fileURL
    }
    
    /// 获取磁盘缓存文件URL
    private func diskCacheFileURL(forKey key: String, type: CacheCategory) -> URL {
        let typeDirectory = diskCacheDirectory.appendingPathComponent(type.rawValue)
        
        do {
            try FileManager.default.createDirectory(at: typeDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("创建类型目录失败: \(error.localizedDescription)")
        }
        
        return typeDirectory.appendingPathComponent(key.md5)
    }
    
    /// 从磁盘缓存获取文件URL
    func fileURLFromDiskCache(forKey key: String, type: CacheCategory) -> URL? {
        let fileURL = diskCacheFileURL(forKey: key, type: type)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        return nil
    }
    
    /// 检查磁盘缓存是否存在
    private func hasDiskCached(forKey key: String, type: CacheCategory) -> Bool {
        let fileURL = diskCacheFileURL(forKey: key, type: type)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// 从磁盘缓存中移除
    private func removeFromDiskCache(forKey key: String, type: CacheCategory) {
        let fileURL = diskCacheFileURL(forKey: key, type: type)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            logger.error("从磁盘缓存移除失败: \(error.localizedDescription)")
        }
    }
    
    /// 清空磁盘缓存
    private func clearDiskCache(type: CacheCategory? = nil) {
        if let type = type {
            let typeDirectory = diskCacheDirectory.appendingPathComponent(type.rawValue)
            
            do {
                try FileManager.default.removeItem(at: typeDirectory)
                try FileManager.default.createDirectory(at: typeDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("清空类型缓存失败: \(error.localizedDescription)")
            }
        } else {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: nil)
                for url in contents {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                logger.error("清空所有缓存失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 生成缓存键
    private func generateCacheKey(key: String, type: CacheCategory) -> String {
        return "\(type.rawValue)_\(key)"
    }
    
    /// 记录缓存访问
    private func recordCacheAccess(key: String) {
        // 更新访问计数
        accessCounters[key] = (accessCounters[key] ?? 0) + 1
        
        // 更新访问时间
        lastAccessTimes[key] = Date()
    }
    
    /// 处理内存警告
    @objc private func handleMemoryWarning() {
        clearMemoryCache()
        logger.info("收到内存警告，已清空内存缓存")
    }
}

/// 缓存类型
enum CacheCategory: String {
    case image = "Images"
    case audio = "Audio"
    case text = "Text"
    case data = "Data"
    case story = "Stories"
}

/// 缓存统计信息
struct CacheStatistics {
    /// 内存缓存命中次数
    var memoryHits: Int = 0
    
    /// 内存缓存未命中次数
    var memoryMisses: Int = 0
    
    /// 磁盘缓存命中次数
    var diskHits: Int = 0
    
    /// 磁盘缓存未命中次数
    var diskMisses: Int = 0
    
    /// 内存缓存命中率
    var memoryHitRate: Double {
        let total = memoryHits + memoryMisses
        guard total > 0 else { return 0 }
        return Double(memoryHits) / Double(total)
    }
    
    /// 磁盘缓存命中率
    var diskHitRate: Double {
        let total = diskHits + diskMisses
        guard total > 0 else { return 0 }
        return Double(diskHits) / Double(total)
    }
    
    /// 总体缓存命中率
    var totalHitRate: Double {
        let hits = memoryHits + diskHits
        let total = hits + diskMisses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }
}

// MARK: - String 扩展

extension String {
    /// 计算MD5哈希值
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
} 