import Foundation
import os.log

/// 性能监控工具，用于跟踪应用的性能指标
class PerformanceMonitor {
    // MARK: - 单例
    
    /// 共享实例
    static let shared = PerformanceMonitor()
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.baobao.performance", category: "PerformanceMonitor")
    
    /// 操作计时器
    private var operationTimers: [String: CFAbsoluteTime] = [:]
    
    /// 操作计数器
    private var operationCounters: [String: Int] = [:]
    
    /// 操作耗时统计
    private var operationDurations: [String: [Double]] = [:]
    
    /// 是否启用详细日志
    private var isVerboseLoggingEnabled = false
    
    // MARK: - 初始化
    
    private init() {
        logger.info("性能监控工具初始化完成")
    }
    
    // MARK: - 公共方法
    
    /// 启用详细日志
    func enableVerboseLogging() {
        isVerboseLoggingEnabled = true
        logger.info("已启用详细日志")
    }
    
    /// 禁用详细日志
    func disableVerboseLogging() {
        isVerboseLoggingEnabled = false
        logger.info("已禁用详细日志")
    }
    
    /// 开始计时操作
    /// - Parameter operation: 操作名称
    func startOperation(_ operation: String) {
        operationTimers[operation] = CFAbsoluteTimeGetCurrent()
        operationCounters[operation, default: 0] += 1
        
        if isVerboseLoggingEnabled {
            logger.debug("开始操作: \(operation)")
        }
    }
    
    /// 结束计时操作
    /// - Parameter operation: 操作名称
    /// - Returns: 操作耗时（秒）
    @discardableResult
    func endOperation(_ operation: String) -> Double {
        guard let startTime = operationTimers[operation] else {
            logger.error("未找到操作的开始时间: \(operation)")
            return 0
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // 记录操作耗时
        operationDurations[operation, default: []].append(duration)
        
        // 移除计时器
        operationTimers.removeValue(forKey: operation)
        
        if isVerboseLoggingEnabled {
            logger.debug("结束操作: \(operation)，耗时: \(duration) 秒")
        }
        
        return duration
    }
    
    /// 测量操作耗时
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - work: 要执行的操作
    /// - Returns: 操作结果
    @discardableResult
    func measure<T>(_ operation: String, work: () throws -> T) rethrows -> T {
        startOperation(operation)
        let result = try work()
        endOperation(operation)
        return result
    }
    
    /// 异步测量操作耗时
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - work: 要执行的异步操作
    func measureAsync<T>(_ operation: String, work: (@escaping (T) -> Void) -> Void) {
        startOperation(operation)
        
        work { result in
            self.endOperation(operation)
        }
    }
    
    /// 获取操作统计信息
    /// - Parameter operation: 操作名称
    /// - Returns: 操作统计信息
    func getOperationStats(_ operation: String) -> OperationStats? {
        guard let durations = operationDurations[operation], !durations.isEmpty else {
            return nil
        }
        
        let count = operationCounters[operation] ?? 0
        let totalDuration = durations.reduce(0, +)
        let averageDuration = totalDuration / Double(durations.count)
        let minDuration = durations.min() ?? 0
        let maxDuration = durations.max() ?? 0
        
        return OperationStats(
            operation: operation,
            count: count,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            minDuration: minDuration,
            maxDuration: maxDuration
        )
    }
    
    /// 获取所有操作统计信息
    /// - Returns: 所有操作统计信息
    func getAllOperationStats() -> [OperationStats] {
        return operationDurations.keys.compactMap { getOperationStats($0) }
    }
    
    /// 重置统计信息
    func resetStats() {
        operationTimers.removeAll()
        operationCounters.removeAll()
        operationDurations.removeAll()
        
        logger.info("已重置性能统计信息")
    }
    
    /// 打印性能报告
    func printPerformanceReport() {
        let stats = getAllOperationStats().sorted { $0.totalDuration > $1.totalDuration }
        
        logger.info("===== 性能报告 =====")
        
        if stats.isEmpty {
            logger.info("没有性能数据")
            return
        }
        
        for stat in stats {
            logger.info("\(stat.operation): 执行\(stat.count)次，总耗时\(String(format: "%.4f", stat.totalDuration))秒，平均\(String(format: "%.4f", stat.averageDuration))秒，最短\(String(format: "%.4f", stat.minDuration))秒，最长\(String(format: "%.4f", stat.maxDuration))秒")
        }
        
        logger.info("===================")
    }
}

/// 操作统计信息
struct OperationStats: Identifiable {
    /// 唯一标识符
    var id: String { operation }
    
    /// 操作名称
    let operation: String
    
    /// 执行次数
    let count: Int
    
    /// 总耗时
    let totalDuration: Double
    
    /// 平均耗时
    let averageDuration: Double
    
    /// 最短耗时
    let minDuration: Double
    
    /// 最长耗时
    let maxDuration: Double
}

/// 性能监控扩展
extension PerformanceMonitor {
    /// 常用操作名称
    enum Operation {
        static let appLaunch = "AppLaunch"
        static let storyGeneration = "StoryGeneration"
        static let speechSynthesis = "SpeechSynthesis"
        static let dataLoading = "DataLoading"
        static let cacheAccess = "CacheAccess"
        static let networkRequest = "NetworkRequest"
        static let uiRendering = "UIRendering"
        static let imageLoading = "ImageLoading"
        static let fileIO = "FileIO"
    }
} 