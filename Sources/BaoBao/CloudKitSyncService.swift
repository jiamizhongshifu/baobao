import Foundation
import CloudKit
import os.log

/// CloudKit同步状态
enum CloudKitSyncStatus {
    case available          // CloudKit可用
    case unavailable        // CloudKit不可用
    case restricted         // CloudKit受限（如家长控制）
    case noAccount          // 未登录iCloud账户
    case error(Error)       // 发生错误
}

/// CloudKit同步类型
enum CloudKitSyncType: String {
    case story = "Story"     // 故事同步
    case child = "Child"     // 宝宝信息同步
}

/// CloudKit同步操作
enum CloudKitSyncOperation {
    case add                // 添加记录
    case update             // 更新记录
    case delete             // 删除记录
}

/// CloudKit同步服务
class CloudKitSyncService {
    /// 共享实例
    static let shared = CloudKitSyncService()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "CloudKitSyncService")
    
    /// CloudKit容器
    private let container: CKContainer
    
    /// 私有数据库
    private var privateDatabase: CKDatabase {
        return container.privateCloudDatabase
    }
    
    /// 同步状态
    private(set) var syncStatus: CloudKitSyncStatus = .unavailable
    
    /// 同步委托
    weak var delegate: CloudKitSyncDelegate?
    
    /// 存储区域名称
    private let zoneName = "BaoBaoZone"
    
    /// 存储区ID
    private lazy var zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    
    /// 订阅ID
    private let subscriptionID = "com.example.baobao.changes"
    
    /// 是否启用同步
    var isSyncEnabled: Bool {
        return ConfigurationManager.shared.cloudKitSyncEnabled
    }
    
    /// 初始化
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.example.baobao")
        logger.info("🌩️ CloudKitSyncService初始化开始")
        
        // 打印更多调试信息
        logger.info("📱 设备名称: \(UIDevice.current.name)")
        logger.info("📱 系统版本: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        
        // 检查iCloud容器配置
        logger.info("🔍 检查iCloud容器: \(container.containerIdentifier ?? "未知")")
        
        // 检查同步状态
        logger.info("🔍 开始检查CloudKit状态")
        checkCloudKitStatus()
    }
    
    // MARK: - 公共方法
    
    /// 设置同步状态
    /// - Parameter status: 同步状态
    func setSyncStatus(_ status: CloudKitSyncStatus) {
        self.syncStatus = status
        logger.info("🔄 CloudKit同步状态更新为: \(statusDescription(for: status))")
        delegate?.cloudKitSyncStatusChanged(status)
    }
    
    /// 获取状态描述
    /// - Parameter status: 同步状态
    /// - Returns: 状态描述
    private func statusDescription(for status: CloudKitSyncStatus) -> String {
        switch status {
        case .available:
            return "可用"
        case .unavailable:
            return "不可用"
        case .restricted:
            return "受限"
        case .noAccount:
            return "无账户"
        case .error(let error):
            return "错误(\(error.localizedDescription))"
        }
    }
    
    /// 检查CloudKit状态
    func checkCloudKitStatus() {
        guard isSyncEnabled else {
            logger.info("🌩️ CloudKit同步已禁用，配置值: \(ConfigurationManager.shared.cloudKitSyncEnabled)")
            setSyncStatus(.unavailable)
            return
        }
        
        logger.info("🔍 开始向iCloud服务查询账户状态")
        container.accountStatus { [weak self] status, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("❌ 检查CloudKit状态失败: \(error.localizedDescription)")
                    self.setSyncStatus(.error(error))
                    return
                }
                
                self.logger.info("✅ 获取到CloudKit账户状态: \(status.rawValue)")
                
                switch status {
                case .available:
                    self.logger.info("✅ CloudKit可用")
                    self.setSyncStatus(.available)
                    self.setupCloudKit()
                case .noAccount:
                    self.logger.warning("⚠️ 未登录iCloud账户")
                    self.setSyncStatus(.noAccount)
                case .restricted:
                    self.logger.warning("⚠️ CloudKit受限")
                    self.setSyncStatus(.restricted)
                case .couldNotDetermine:
                    self.logger.warning("⚠️ 无法确定CloudKit状态")
                    self.setSyncStatus(.unavailable)
                @unknown default:
                    self.logger.warning("⚠️ 未知的CloudKit状态")
                    self.setSyncStatus(.unavailable)
                }
            }
        }
    }
    
    /// 同步故事
    /// - Parameters:
    ///   - story: 故事对象
    ///   - operation: 同步操作
    ///   - completion: 完成回调
    func syncStory(_ story: Story, operation: CloudKitSyncOperation, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard isSyncEnabled, case .available = syncStatus else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit不可用"])))
            return
        }
        
        switch operation {
        case .add, .update:
            saveStory(story, completion: completion)
        case .delete:
            deleteStory(story, completion: completion)
        }
    }
    
    /// 同步宝宝信息
    /// - Parameters:
    ///   - child: 宝宝对象
    ///   - operation: 同步操作
    ///   - completion: 完成回调
    func syncChild(_ child: Child, operation: CloudKitSyncOperation, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        guard isSyncEnabled, case .available = syncStatus else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit不可用"])))
            return
        }
        
        switch operation {
        case .add, .update:
            saveChild(child, completion: completion)
        case .delete:
            deleteChild(child, completion: completion)
        }
    }
    
    /// 获取所有故事
    /// - Parameter completion: 完成回调
    func fetchAllStories(completion: @escaping (Result<[Story], Error>) -> Void) {
        guard isSyncEnabled, case .available = syncStatus else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit不可用"])))
            return
        }
        
        let query = CKQuery(recordType: CloudKitSyncType.story.rawValue, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        privateDatabase.perform(query, inZoneWith: zoneID) { [weak self] records, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("❌ 获取故事失败: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let records = records else {
                    completion(.success([]))
                    return
                }
                
                let stories = records.compactMap { self.storyFromRecord($0) }
                self.logger.info("✅ 从CloudKit获取到\(stories.count)个故事")
                completion(.success(stories))
            }
        }
    }
    
    /// 获取所有宝宝信息
    /// - Parameter completion: 完成回调
    func fetchAllChildren(completion: @escaping (Result<[Child], Error>) -> Void) {
        guard isSyncEnabled, case .available = syncStatus else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit不可用"])))
            return
        }
        
        let query = CKQuery(recordType: CloudKitSyncType.child.rawValue, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        privateDatabase.perform(query, inZoneWith: zoneID) { [weak self] records, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("❌ 获取宝宝信息失败: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let records = records else {
                    completion(.success([]))
                    return
                }
                
                let children = records.compactMap { self.childFromRecord($0) }
                self.logger.info("✅ 从CloudKit获取到\(children.count)个宝宝信息")
                completion(.success(children))
            }
        }
    }
    
    /// 执行全量同步
    /// - Parameter completion: 完成回调
    func performFullSync(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isSyncEnabled, case .available = syncStatus else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit不可用"])))
            return
        }
        
        let group = DispatchGroup()
        var syncError: Error?
        
        // 获取所有故事
        group.enter()
        fetchAllStories { result in
            switch result {
            case .success(let cloudStories):
                // 获取本地故事进行对比和合并
                DataService.shared.getStories { localResult in
                    switch localResult {
                    case .success(let localStories):
                        self.mergeStories(local: localStories, cloud: cloudStories)
                    case .failure(let error):
                        syncError = error
                    }
                    group.leave()
                }
            case .failure(let error):
                syncError = error
                group.leave()
            }
        }
        
        // 获取所有宝宝信息
        group.enter()
        fetchAllChildren { result in
            switch result {
            case .success(let cloudChildren):
                // 获取本地宝宝信息进行对比和合并
                DataService.shared.getChildren { localResult in
                    switch localResult {
                    case .success(let localChildren):
                        self.mergeChildren(local: localChildren, cloud: cloudChildren)
                    case .failure(let error):
                        syncError = error
                    }
                    group.leave()
                }
            case .failure(let error):
                syncError = error
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = syncError {
                self.logger.error("❌ 全量同步失败: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                self.logger.info("✅ 全量同步完成")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - 私有辅助方法
    
    /// 设置CloudKit
    private func setupCloudKit() {
        createZoneIfNeeded { [weak self] success in
            guard let self = self, success else { return }
            
            // 创建订阅以接收远程更改通知
            self.createSubscriptionIfNeeded()
        }
    }
    
    /// 创建自定义区域
    /// - Parameter completion: 完成回调
    private func createZoneIfNeeded(completion: @escaping (Bool) -> Void) {
        let recordZone = CKRecordZone(zoneID: zoneID)
        
        privateDatabase.fetch(withRecordZoneID: zoneID) { [weak self] (zone, error) in
            guard let self = self else { return }
            
            if let error = error {
                let ckError = error as NSError
                if ckError.code == CKError.zoneNotFound.rawValue {
                    // 区域不存在，创建
                    self.privateDatabase.save(recordZone) { (_, error) in
                        if let error = error {
                            self.logger.error("❌ 创建CloudKit区域失败: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            self.logger.info("✅ 创建CloudKit区域成功")
                            completion(true)
                        }
                    }
                } else {
                    self.logger.error("❌ 检查CloudKit区域失败: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                // 区域已存在
                self.logger.info("ℹ️ CloudKit区域已存在")
                completion(true)
            }
        }
    }
    
    /// 创建数据库订阅
    private func createSubscriptionIfNeeded() {
        // 检查当前订阅
        privateDatabase.fetch(withSubscriptionID: subscriptionID) { [weak self] (subscription, error) in
            guard let self = self else { return }
            
            if let error = error {
                let ckError = error as NSError
                if ckError.code == CKError.unknownItem.rawValue {
                    // 订阅不存在，创建
                    self.createSubscription()
                } else {
                    self.logger.error("❌ 检查CloudKit订阅失败: \(error.localizedDescription)")
                }
            } else {
                // 订阅已存在
                self.logger.info("ℹ️ CloudKit订阅已存在")
            }
        }
    }
    
    /// 创建订阅
    private func createSubscription() {
        // 创建订阅条件
        let predicate = NSPredicate(value: true)
        
        // 构建通知信息
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // 静默推送
        
        // 创建订阅
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        subscription.notificationInfo = notificationInfo
        
        // 保存订阅
        privateDatabase.save(subscription) { [weak self] (_, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("❌ 创建CloudKit订阅失败: \(error.localizedDescription)")
            } else {
                self.logger.info("✅ 创建CloudKit订阅成功")
            }
        }
    }
    
    // MARK: - 记录转换方法
    
    /// 将故事转换为CloudKit记录
    /// - Parameter story: 故事对象
    /// - Returns: CloudKit记录
    private func recordFromStory(_ story: Story) -> CKRecord {
        let recordID = CKRecord.ID(recordName: story.id, zoneID: zoneID)
        let record = CKRecord(recordType: CloudKitSyncType.story.rawValue, recordID: recordID)
        
        record["title"] = story.title as CKRecordValue
        record["content"] = story.content as CKRecordValue
        record["theme"] = story.theme as CKRecordValue
        record["childName"] = story.childName as CKRecordValue
        record["createdAt"] = story.createdAt as CKRecordValue
        
        if let audioURL = story.audioURL {
            record["audioURL"] = audioURL as CKRecordValue
        }
        
        if let audioDuration = story.audioDuration {
            record["audioDuration"] = audioDuration as CKRecordValue
        }
        
        if let lastPlayPosition = story.lastPlayPosition {
            record["lastPlayPosition"] = lastPlayPosition as CKRecordValue
        }
        
        return record
    }
    
    /// 将CloudKit记录转换为故事
    /// - Parameter record: CloudKit记录
    /// - Returns: 故事对象
    private func storyFromRecord(_ record: CKRecord) -> Story? {
        guard let title = record["title"] as? String,
              let content = record["content"] as? String,
              let theme = record["theme"] as? String,
              let childName = record["childName"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }
        
        let audioURL = record["audioURL"] as? String
        let audioDuration = record["audioDuration"] as? TimeInterval
        let lastPlayPosition = record["lastPlayPosition"] as? TimeInterval
        
        return Story(
            id: record.recordID.recordName,
            title: title,
            content: content,
            theme: theme,
            childName: childName,
            createdAt: createdAt,
            audioURL: audioURL,
            audioDuration: audioDuration,
            lastPlayPosition: lastPlayPosition
        )
    }
    
    /// 将宝宝信息转换为CloudKit记录
    /// - Parameter child: 宝宝对象
    /// - Returns: CloudKit记录
    private func recordFromChild(_ child: Child) -> CKRecord {
        let recordID = CKRecord.ID(recordName: child.id, zoneID: zoneID)
        let record = CKRecord(recordType: CloudKitSyncType.child.rawValue, recordID: recordID)
        
        record["name"] = child.name as CKRecordValue
        record["age"] = child.age as CKRecordValue
        record["gender"] = child.gender as CKRecordValue
        record["createdAt"] = child.createdAt as CKRecordValue
        
        if !child.interests.isEmpty {
            record["interests"] = child.interests as CKRecordValue
        }
        
        return record
    }
    
    /// 将CloudKit记录转换为宝宝信息
    /// - Parameter record: CloudKit记录
    /// - Returns: 宝宝对象
    private func childFromRecord(_ record: CKRecord) -> Child? {
        guard let name = record["name"] as? String,
              let age = record["age"] as? Int,
              let gender = record["gender"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }
        
        let interests = record["interests"] as? [String] ?? []
        
        return Child(
            id: record.recordID.recordName,
            name: name,
            age: age,
            gender: gender,
            interests: interests,
            createdAt: createdAt
        )
    }
    
    // MARK: - 数据操作方法
    
    /// 保存故事到CloudKit
    /// - Parameters:
    ///   - story: 故事对象
    ///   - completion: 完成回调
    private func saveStory(_ story: Story, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let record = recordFromStory(story)
        
        privateDatabase.save(record) { [weak self] (savedRecord, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("❌ 保存故事到CloudKit失败: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    self.logger.info("✅ 故事已同步到CloudKit: \(story.id)")
                    completion(.success(savedRecord))
                } else {
                    let error = NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知错误"])
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 删除故事从CloudKit
    /// - Parameters:
    ///   - story: 故事对象
    ///   - completion: 完成回调
    private func deleteStory(_ story: Story, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: story.id, zoneID: zoneID)
        
        privateDatabase.delete(withRecordID: recordID) { [weak self] (recordID, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    // 检查是否是记录不存在的错误
                    let ckError = error as NSError
                    if ckError.code == CKError.unknownItem.rawValue {
                        // 记录不存在，视为成功
                        self.logger.info("ℹ️ 删除的故事在CloudKit中不存在: \(story.id)")
                        let dummyRecord = self.recordFromStory(story)
                        completion(.success(dummyRecord))
                    } else {
                        self.logger.error("❌ 从CloudKit删除故事失败: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                } else {
                    self.logger.info("✅ 故事已从CloudKit删除: \(story.id)")
                    let dummyRecord = self.recordFromStory(story)
                    completion(.success(dummyRecord))
                }
            }
        }
    }
    
    /// 保存宝宝信息到CloudKit
    /// - Parameters:
    ///   - child: 宝宝对象
    ///   - completion: 完成回调
    private func saveChild(_ child: Child, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let record = recordFromChild(child)
        
        privateDatabase.save(record) { [weak self] (savedRecord, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("❌ 保存宝宝信息到CloudKit失败: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    self.logger.info("✅ 宝宝信息已同步到CloudKit: \(child.id)")
                    completion(.success(savedRecord))
                } else {
                    let error = NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知错误"])
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 删除宝宝信息从CloudKit
    /// - Parameters:
    ///   - child: 宝宝对象
    ///   - completion: 完成回调
    private func deleteChild(_ child: Child, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: child.id, zoneID: zoneID)
        
        privateDatabase.delete(withRecordID: recordID) { [weak self] (recordID, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    // 检查是否是记录不存在的错误
                    let ckError = error as NSError
                    if ckError.code == CKError.unknownItem.rawValue {
                        // 记录不存在，视为成功
                        self.logger.info("ℹ️ 删除的宝宝信息在CloudKit中不存在: \(child.id)")
                        let dummyRecord = self.recordFromChild(child)
                        completion(.success(dummyRecord))
                    } else {
                        self.logger.error("❌ 从CloudKit删除宝宝信息失败: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                } else {
                    self.logger.info("✅ 宝宝信息已从CloudKit删除: \(child.id)")
                    let dummyRecord = self.recordFromChild(child)
                    completion(.success(dummyRecord))
                }
            }
        }
    }
    
    // MARK: - 数据合并方法
    
    /// 合并故事数据
    /// - Parameters:
    ///   - local: 本地故事列表
    ///   - cloud: 云端故事列表
    private func mergeStories(local: [Story], cloud: [Story]) {
        let localDict = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let cloudDict = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        
        // 本地有，云端没有的 -> 上传到云端
        let localOnly = local.filter { cloudDict[$0.id] == nil }
        for story in localOnly {
            syncStory(story, operation: .add) { _ in }
        }
        
        // 云端有，本地没有的 -> 下载到本地
        let cloudOnly = cloud.filter { localDict[$0.id] == nil }
        for story in cloudOnly {
            DataService.shared.saveStory(story) { _ in }
        }
        
        // 都有的 -> 根据时间戳决定
        let common = local.filter { cloudDict[$0.id] != nil }
        for localStory in common {
            guard let cloudStory = cloudDict[localStory.id] else { continue }
            
            if localStory.createdAt > cloudStory.createdAt {
                // 本地较新，更新云端
                syncStory(localStory, operation: .update) { _ in }
            } else if cloudStory.createdAt > localStory.createdAt {
                // 云端较新，更新本地
                DataService.shared.saveStory(cloudStory) { _ in }
            }
            // 时间戳相同则不处理
        }
    }
    
    /// 合并宝宝信息数据
    /// - Parameters:
    ///   - local: 本地宝宝信息列表
    ///   - cloud: 云端宝宝信息列表
    private func mergeChildren(local: [Child], cloud: [Child]) {
        let localDict = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let cloudDict = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        
        // 本地有，云端没有的 -> 上传到云端
        let localOnly = local.filter { cloudDict[$0.id] == nil }
        for child in localOnly {
            syncChild(child, operation: .add) { _ in }
        }
        
        // 云端有，本地没有的 -> 下载到本地
        let cloudOnly = cloud.filter { localDict[$0.id] == nil }
        for child in cloudOnly {
            DataService.shared.saveChild(child) { _ in }
        }
        
        // 都有的 -> 根据时间戳决定
        let common = local.filter { cloudDict[$0.id] != nil }
        for localChild in common {
            guard let cloudChild = cloudDict[localChild.id] else { continue }
            
            if localChild.createdAt > cloudChild.createdAt {
                // 本地较新，更新云端
                syncChild(localChild, operation: .update) { _ in }
            } else if cloudChild.createdAt > localChild.createdAt {
                // 云端较新，更新本地
                DataService.shared.saveChild(cloudChild) { _ in }
            }
            // 时间戳相同则不处理
        }
    }
}

/// CloudKit同步委托协议
protocol CloudKitSyncDelegate: AnyObject {
    /// CloudKit同步状态变更
    /// - Parameter status: 新的同步状态
    func cloudKitSyncStatusChanged(_ status: CloudKitSyncStatus)
    
    /// 新数据到达
    /// - Parameters:
    ///   - type: 数据类型
    ///   - id: 数据ID
    func cloudKitNewDataReceived(type: CloudKitSyncType, id: String)
} 