import Foundation
import CoreData
import os.log

/// 数据服务类，负责App中所有数据的持久化存储和检索
class CoreDataService {
    /// 共享实例
    static let shared = CoreDataService()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.example.baobao", category: "DataService")
    
    /// 持久化容器
    private lazy var persistentContainer: NSPersistentContainer = {
        // 创建存储文件目录
        let storageURL = createStorageDirectoryIfNeeded()
        
        // 动态创建数据模型
        let model = createDataModel()
        
        // 创建持久化存储描述
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.url = storageURL.appendingPathComponent("BaoBao.sqlite")
        storeDescription.type = NSSQLiteStoreType
        
        // 优化存储设置
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // 创建持久化容器
        let container = NSPersistentContainer(name: "BaoBao", managedObjectModel: model)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                self?.logger.error("❌ 加载持久化存储失败: \(error.localizedDescription)")
                fatalError("无法加载持久化存储: \(error.localizedDescription)")
            } else {
                self?.logger.info("✅ 成功加载持久化存储")
            }
        }
        
        // 自动合并对象上下文的变更
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    /// 主上下文
    private var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// 故事文件URL
    private let storiesURL: URL
    
    /// 宝宝信息文件URL
    private let childrenURL: URL
    
    /// 故事缓存
    private var storiesCache: [Story] = []
    
    /// 宝宝信息缓存
    private var childrenCache: [Child] = []
    
    /// 是否已加载故事
    private var hasLoadedStories = false
    
    /// 是否已加载宝宝信息
    private var hasLoadedChildren = false
    
    /// 是否启用自动同步
    private var autoSyncEnabled: Bool {
        return ConfigurationManager.shared.cloudKitSyncEnabled
    }
    
    /// 初始化
    private init() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 创建数据目录
        let dataDirectory = documentsDirectory.appendingPathComponent("data", isDirectory: true)
        try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // 设置文件URL
        storiesURL = dataDirectory.appendingPathComponent("stories.json")
        childrenURL = dataDirectory.appendingPathComponent("children.json")
        
        logger.info("📊 DataService初始化，数据目录：\(dataDirectory.path)")
        
        // 注册为CloudKit同步委托
        CloudKitSyncService.shared.delegate = self
        
        // 如果启用了CloudKit同步，开始初始同步
        if autoSyncEnabled && CloudKitSyncService.shared.syncStatus == .available {
            performInitialSync()
        }
        
        // 注册通知
        registerNotifications()
    }
    
    // MARK: - 创建数据库模型
    
    /// 动态创建数据模型
    private func createDataModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 创建故事实体
        let storyEntity = NSEntityDescription()
        storyEntity.name = "Story"
        storyEntity.managedObjectClassName = NSStringFromClass(StoryMO.self)
        
        // 创建宝宝实体
        let childEntity = NSEntityDescription()
        childEntity.name = "Child"
        childEntity.managedObjectClassName = NSStringFromClass(ChildMO.self)
        
        // 故事实体属性
        let storyProperties: [NSAttributeDescription] = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "title", type: .stringAttributeType, optional: false),
            createAttribute(name: "content", type: .stringAttributeType, optional: false),
            createAttribute(name: "theme", type: .stringAttributeType, optional: false),
            createAttribute(name: "childName", type: .stringAttributeType, optional: false),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
            createAttribute(name: "audioURL", type: .stringAttributeType, optional: true),
            createAttribute(name: "audioDuration", type: .doubleAttributeType, optional: true),
            createAttribute(name: "lastPlayPosition", type: .doubleAttributeType, optional: true)
        ]
        storyEntity.properties = storyProperties
        
        // 宝宝实体属性
        let childProperties: [NSAttributeDescription] = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "age", type: .integer16AttributeType, optional: false),
            createAttribute(name: "gender", type: .stringAttributeType, optional: false),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false)
        ]
        
        // 兴趣属性（作为转换属性）
        let interestsAttribute = NSAttributeDescription()
        interestsAttribute.name = "interestsData"
        interestsAttribute.attributeType = .binaryDataAttributeType
        interestsAttribute.isOptional = true
        
        childEntity.properties = childProperties + [interestsAttribute]
        
        // 设置模型的实体
        model.entities = [storyEntity, childEntity]
        
        return model
    }
    
    /// 创建属性
    private func createAttribute(name: String, type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
    
    /// 创建并确保存储目录存在
    private func createStorageDirectoryIfNeeded() -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storageURL = documentsURL.appendingPathComponent("CoreData", isDirectory: true)
        
        if !fileManager.fileExists(atPath: storageURL.path) {
            do {
                try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
                logger.info("✅ 创建了数据存储目录: \(storageURL.path)")
            } catch {
                logger.error("❌ 创建数据存储目录失败: \(error.localizedDescription)")
            }
        }
        
        return storageURL
    }
    
    // MARK: - 通知
    
    /// 注册通知
    private func registerNotifications() {
        // 监听应用状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextSaveNotification(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
        
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    /// 处理上下文保存通知
    @objc private func handleContextSaveNotification(_ notification: Notification) {
        guard let sender = notification.object as? NSManagedObjectContext else { return }
        
        // 如果通知来自后台上下文，合并到主上下文
        if sender !== mainContext {
            mainContext.perform {
                self.mainContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    /// 应用进入后台
    @objc private func applicationWillResignActive() {
        logger.info("📱 应用进入后台，保存数据")
        saveChanges()
    }
    
    // MARK: - 后台上下文
    
    /// 创建后台上下文
    private func createBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// 保存更改
    func saveChanges() {
        if mainContext.hasChanges {
            do {
                try mainContext.save()
                logger.info("✅ 成功保存数据变更")
            } catch {
                logger.error("❌ 保存数据失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 故事操作
    
    /// 获取所有故事
    /// - Parameter completion: 完成回调
    func getStories(completion: @escaping (Result<[Story], Error>) -> Void) {
        if hasLoadedStories {
            // 直接返回缓存
            completion(.success(storiesCache))
            return
        }
        
        loadStories { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let stories):
                self.storiesCache = stories
                self.hasLoadedStories = true
                completion(.success(stories))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 保存故事
    /// - Parameters:
    ///   - story: 故事对象
    ///   - completion: 完成回调
    func saveStory(_ story: Story, completion: @escaping (Result<Story, Error>) -> Void) {
        // 先获取当前所有故事
        getStories { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var stories):
                // 检查是否存在同ID故事
                if let index = stories.firstIndex(where: { $0.id == story.id }) {
                    // 更新已有故事
                    stories[index] = story
                } else {
                    // 添加新故事
                    stories.append(story)
                }
                
                // 更新缓存
                self.storiesCache = stories
                
                // 保存到文件
                self.saveStoriesToFile(stories) { saveResult in
                    switch saveResult {
                    case .success:
                        // 同步到CloudKit
                        if self.autoSyncEnabled {
                            CloudKitSyncService.shared.syncStory(story, operation: .add) { _ in
                                // 忽略CloudKit同步结果，本地保存已成功
                            }
                        }
                        completion(.success(story))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 删除故事
    /// - Parameters:
    ///   - storyID: 故事ID
    ///   - completion: 完成回调
    func deleteStory(id storyID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 先获取当前所有故事
        getStories { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var stories):
                // 查找要删除的故事
                guard let index = stories.firstIndex(where: { $0.id == storyID }),
                      let storyToDelete = stories.first(where: { $0.id == storyID }) else {
                    completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到指定故事"])))
                    return
                }
                
                // 从数组中删除
                stories.remove(at: index)
                
                // 更新缓存
                self.storiesCache = stories
                
                // 保存到文件
                self.saveStoriesToFile(stories) { saveResult in
                    switch saveResult {
                    case .success:
                        // 同步到CloudKit
                        if self.autoSyncEnabled {
                            CloudKitSyncService.shared.syncStory(storyToDelete, operation: .delete) { _ in
                                // 忽略CloudKit同步结果，本地删除已成功
                            }
                        }
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 获取特定故事
    /// - Parameters:
    ///   - storyID: 故事ID
    ///   - completion: 完成回调
    func getStory(id storyID: String, completion: @escaping (Result<Story?, Error>) -> Void) {
        getStories { result in
            switch result {
            case .success(let stories):
                let story = stories.first { $0.id == storyID }
                completion(.success(story))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 宝宝操作
    
    /// 获取所有宝宝信息
    /// - Parameter completion: 完成回调
    func getChildren(completion: @escaping (Result<[Child], Error>) -> Void) {
        if hasLoadedChildren {
            // 直接返回缓存
            completion(.success(childrenCache))
            return
        }
        
        loadChildren { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let children):
                self.childrenCache = children
                self.hasLoadedChildren = true
                completion(.success(children))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 保存宝宝信息
    /// - Parameters:
    ///   - child: 宝宝信息对象
    ///   - completion: 完成回调
    func saveChild(_ child: Child, completion: @escaping (Result<Child, Error>) -> Void) {
        // 先获取当前所有宝宝信息
        getChildren { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var children):
                // 检查是否存在同ID宝宝信息
                if let index = children.firstIndex(where: { $0.id == child.id }) {
                    // 更新已有宝宝信息
                    children[index] = child
                } else {
                    // 添加新宝宝信息
                    children.append(child)
                }
                
                // 更新缓存
                self.childrenCache = children
                
                // 保存到文件
                self.saveChildrenToFile(children) { saveResult in
                    switch saveResult {
                    case .success:
                        // 同步到CloudKit
                        if self.autoSyncEnabled {
                            CloudKitSyncService.shared.syncChild(child, operation: .add) { _ in
                                // 忽略CloudKit同步结果，本地保存已成功
                            }
                        }
                        completion(.success(child))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 删除宝宝信息
    /// - Parameters:
    ///   - childID: 宝宝ID
    ///   - completion: 完成回调
    func deleteChild(id childID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 先获取当前所有宝宝信息
        getChildren { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var children):
                // 查找要删除的宝宝信息
                guard let index = children.firstIndex(where: { $0.id == childID }),
                      let childToDelete = children.first(where: { $0.id == childID }) else {
                    completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到指定宝宝信息"])))
                    return
                }
                
                // 从数组中删除
                children.remove(at: index)
                
                // 更新缓存
                self.childrenCache = children
                
                // 保存到文件
                self.saveChildrenToFile(children) { saveResult in
                    switch saveResult {
                    case .success:
                        // 同步到CloudKit
                        if self.autoSyncEnabled {
                            CloudKitSyncService.shared.syncChild(childToDelete, operation: .delete) { _ in
                                // 忽略CloudKit同步结果，本地删除已成功
                            }
                        }
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 获取特定宝宝信息
    /// - Parameters:
    ///   - childID: 宝宝ID
    ///   - completion: 完成回调
    func getChild(id childID: String, completion: @escaping (Result<Child?, Error>) -> Void) {
        getChildren { result in
            switch result {
            case .success(let children):
                let child = children.first { $0.id == childID }
                completion(.success(child))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 私有文件操作方法
    
    /// 从文件加载故事
    /// - Parameter completion: 完成回调
    private func loadStories(completion: @escaping (Result<[Story], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 检查文件是否存在
                if FileManager.default.fileExists(atPath: self.storiesURL.path) {
                    // 读取文件内容
                    let data = try Data(contentsOf: self.storiesURL)
                    
                    // 解码JSON
                    let stories = try JSONDecoder().decode([Story].self, from: data)
                    
                    DispatchQueue.main.async {
                        self.logger.info("📖 从文件加载了\(stories.count)个故事")
                        completion(.success(stories))
                    }
                } else {
                    // 文件不存在，返回空数组
                    DispatchQueue.main.async {
                        self.logger.info("📖 故事文件不存在，返回空数组")
                        completion(.success([]))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.error("❌ 加载故事失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 保存故事到文件
    /// - Parameters:
    ///   - stories: 故事数组
    ///   - completion: 完成回调
    private func saveStoriesToFile(_ stories: [Story], completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 编码为JSON
                let data = try JSONEncoder().encode(stories)
                
                // 写入文件
                try data.write(to: self.storiesURL)
                
                DispatchQueue.main.async {
                    self.logger.info("💾 已保存\(stories.count)个故事到文件")
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.error("❌ 保存故事失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 从文件加载宝宝信息
    /// - Parameter completion: 完成回调
    private func loadChildren(completion: @escaping (Result<[Child], Error>) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 检查文件是否存在
                if FileManager.default.fileExists(atPath: self.childrenURL.path) {
                    // 读取文件内容
                    let data = try Data(contentsOf: self.childrenURL)
                    
                    // 解码JSON
                    let children = try JSONDecoder().decode([Child].self, from: data)
                    
                    DispatchQueue.main.async {
                        self.logger.info("👶 从文件加载了\(children.count)个宝宝信息")
                        completion(.success(children))
                    }
                } else {
                    // 文件不存在，返回空数组
                    DispatchQueue.main.async {
                        self.logger.info("👶 宝宝信息文件不存在，返回空数组")
                        completion(.success([]))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.error("❌ 加载宝宝信息失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 保存宝宝信息到文件
    /// - Parameters:
    ///   - children: 宝宝信息数组
    ///   - completion: 完成回调
    private func saveChildrenToFile(_ children: [Child], completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 编码为JSON
                let data = try JSONEncoder().encode(children)
                
                // 写入文件
                try data.write(to: self.childrenURL)
                
                DispatchQueue.main.async {
                    self.logger.info("💾 已保存\(children.count)个宝宝信息到文件")
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    self.logger.error("❌ 保存宝宝信息失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 同步方法
    
    /// 执行初始同步
    private func performInitialSync() {
        logger.info("🔄 执行初始CloudKit同步")
        
        CloudKitSyncService.shared.performFullSync { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.logger.info("✅ 初始CloudKit同步完成")
            case .failure(let error):
                self.logger.error("❌ 初始CloudKit同步失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 触发全量同步
    /// - Parameter completion: 完成回调
    func triggerSync(completion: @escaping (Result<Void, Error>) -> Void) {
        guard autoSyncEnabled else {
            completion(.failure(NSError(domain: "com.example.baobao", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit同步未启用"])))
            return
        }
        
        CloudKitSyncService.shared.performFullSync(completion: completion)
    }
}

// MARK: - CloudKit同步委托

extension CoreDataService: CloudKitSyncDelegate {
    func cloudKitSyncStatusChanged(_ status: CloudKitSyncStatus) {
        switch status {
        case .available:
            logger.info("🌩️ CloudKit同步状态变更: 可用")
            // 同步状态变为可用时，执行全量同步
            if autoSyncEnabled {
                performInitialSync()
            }
        case .unavailable:
            logger.warning("🌩️ CloudKit同步状态变更: 不可用")
        case .restricted:
            logger.warning("🌩️ CloudKit同步状态变更: 受限")
        case .noAccount:
            logger.warning("🌩️ CloudKit同步状态变更: 未登录iCloud账户")
        case .error(let error):
            logger.error("🌩️ CloudKit同步状态变更: 错误 - \(error.localizedDescription)")
        }
    }
    
    func cloudKitNewDataReceived(type: CloudKitSyncType, id: String) {
        logger.info("📨 收到CloudKit新数据通知: \(type.rawValue), ID: \(id)")
        
        // 收到新数据通知时，执行全量同步
        if autoSyncEnabled {
            CloudKitSyncService.shared.performFullSync { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    self.logger.info("✅ 收到新数据后的同步完成")
                case .failure(let error):
                    self.logger.error("❌ 收到新数据后的同步失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 托管对象子类

/// 故事托管对象
@objc(StoryMO)
public class StoryMO: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var content: String
    @NSManaged public var theme: String
    @NSManaged public var childName: String
    @NSManaged public var createdAt: Date
    @NSManaged public var audioURL: String?
    @NSManaged public var audioDuration: Double
    @NSManaged public var lastPlayPosition: Double
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoryMO> {
        return NSFetchRequest<StoryMO>(entityName: "Story")
    }
}

/// 宝宝托管对象
@objc(ChildMO)
public class ChildMO: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var age: Int16
    @NSManaged public var gender: String
    @NSManaged public var createdAt: Date
    @NSManaged public var interestsData: Data?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChildMO> {
        return NSFetchRequest<ChildMO>(entityName: "Child")
    }
}
