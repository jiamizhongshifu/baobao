import SwiftUI

/// 同步设置视图
struct SyncSettingsView: View {
    // 配置管理器
    @ObservedObject private var configManager = ConfigurationManagerObservable.shared
    
    // 同步状态
    @State private var syncStatus: CloudKitSyncStatus = CloudKitSyncService.shared.syncStatus
    
    // 上次同步时间
    @State private var lastSyncTime: Date? = nil
    
    // 是否正在同步
    @State private var isSyncing = false
    
    // 同步结果消息
    @State private var syncResultMessage: String? = nil
    
    // CloudKit状态描述
    private var cloudKitStatusDescription: String {
        switch syncStatus {
        case .available:
            return "CloudKit可用，已连接到iCloud"
        case .unavailable:
            return "CloudKit不可用"
        case .restricted:
            return "CloudKit受限（可能是家长控制）"
        case .noAccount:
            return "未登录iCloud账户"
        case .error(let error):
            return "CloudKit错误: \(error.localizedDescription)"
        }
    }
    
    // 同步状态图标
    private var statusIcon: String {
        switch syncStatus {
        case .available:
            return "checkmark.icloud"
        case .unavailable:
            return "xmark.icloud"
        case .restricted:
            return "lock.icloud"
        case .noAccount:
            return "person.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }
    
    // 状态图标颜色
    private var statusColor: Color {
        switch syncStatus {
        case .available:
            return .green
        case .unavailable, .noAccount:
            return .orange
        case .restricted, .error:
            return .red
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("CloudKit状态")) {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                    Text(cloudKitStatusDescription)
                        .font(.subheadline)
                }
                
                if case .noAccount = syncStatus {
                    Button(action: openICloudSettings) {
                        Text("登录iCloud")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section(header: Text("同步设置")) {
                Toggle("启用CloudKit同步", isOn: $configManager.cloudKitSyncEnabled)
                    .onChange(of: configManager.cloudKitSyncEnabled) { newValue in
                        CloudKitSyncService.shared.checkCloudKitStatus()
                    }
                
                if configManager.cloudKitSyncEnabled {
                    Toggle("仅在Wi-Fi下同步", isOn: $configManager.syncOnWifiOnly)
                    
                    Picker("同步频率", selection: $configManager.syncFrequencyHours) {
                        Text("每6小时").tag(6)
                        Text("每12小时").tag(12)
                        Text("每天").tag(24)
                        Text("每48小时").tag(48)
                    }
                    
                    Toggle("自动下载新故事", isOn: $configManager.autoDownloadNewStories)
                }
            }
            
            if configManager.cloudKitSyncEnabled {
                Section(header: Text("手动同步")) {
                    VStack(alignment: .leading) {
                        if let lastSyncTime = lastSyncTime {
                            Text("上次同步: \(timeAgoString(from: lastSyncTime))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Text("尚未同步")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        if let message = syncResultMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundColor(message.hasPrefix("错误") ? .red : .green)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: performSync) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("正在同步...")
                            } else {
                                Text("立即同步")
                            }
                        }
                    }
                    .disabled(isSyncing || syncStatus != .available)
                }
            }
            
            Section(header: Text("重要说明")) {
                Text("启用CloudKit同步将在您的所有iOS设备之间自动同步故事和宝宝信息，前提是这些设备使用相同的iCloud账户。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text("首次启用同步时，可能需要几分钟时间来完成初始数据上传。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text("同步需要使用网络连接，如果您在移动数据下使用，可能会消耗流量。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("故障排除")) {
                NavigationLink(destination: CloudKitDiagnosticView()) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.blue)
                        Text("CloudKit诊断工具")
                    }
                }
                
                Button(action: {
                    CloudKitSyncService.shared.checkCloudKitStatus()
                    updateSyncStatus()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("刷新CloudKit状态")
                    }
                }
            }
        }
        .navigationTitle("同步设置")
        .onAppear {
            updateSyncStatus()
        }
    }
    
    /// 更新同步状态
    private func updateSyncStatus() {
        syncStatus = CloudKitSyncService.shared.syncStatus
        
        // 获取上次同步时间
        if let syncTimeString = UserDefaults.standard.string(forKey: "LastSyncTime"),
           let syncTime = ISO8601DateFormatter().date(from: syncTimeString) {
            lastSyncTime = syncTime
        }
    }
    
    /// 打开iCloud设置
    private func openICloudSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    /// 执行同步
    private func performSync() {
        isSyncing = true
        syncResultMessage = nil
        
        CoreDataService.shared.triggerSync { result in
            isSyncing = false
            
            switch result {
            case .success:
                syncResultMessage = "同步成功"
                let now = Date()
                lastSyncTime = now
                
                // 保存同步时间
                UserDefaults.standard.set(ISO8601DateFormatter().string(from: now), forKey: "LastSyncTime")
            case .failure(let error):
                syncResultMessage = "错误: \(error.localizedDescription)"
            }
        }
    }
    
    /// 计算时间差显示字符串
    /// - Parameter date: 目标日期
    /// - Returns: 友好的时间差显示
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)天前"
        }
        
        if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        }
        
        if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        }
        
        return "刚刚"
    }
}

/// 配置管理器可观察包装器
class ConfigurationManagerObservable: ObservableObject {
    static let shared = ConfigurationManagerObservable()
    
    private let configManager = ConfigurationManager.shared
    
    @Published var cloudKitSyncEnabled: Bool {
        didSet {
            configManager.set(cloudKitSyncEnabled, forKey: "CLOUDKIT_SYNC_ENABLED")
        }
    }
    
    @Published var syncOnWifiOnly: Bool {
        didSet {
            configManager.set(syncOnWifiOnly, forKey: "SYNC_ON_WIFI_ONLY")
        }
    }
    
    @Published var syncFrequencyHours: Int {
        didSet {
            configManager.set(syncFrequencyHours, forKey: "SYNC_FREQUENCY_HOURS")
            
            // 重新安排同步
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.scheduleSync()
            }
        }
    }
    
    @Published var autoDownloadNewStories: Bool {
        didSet {
            configManager.set(autoDownloadNewStories, forKey: "AUTO_DOWNLOAD_NEW_STORIES")
        }
    }
    
    private init() {
        self.cloudKitSyncEnabled = configManager.cloudKitSyncEnabled
        self.syncOnWifiOnly = configManager.syncOnWifiOnly
        self.syncFrequencyHours = configManager.syncFrequencyHours
        self.autoDownloadNewStories = configManager.autoDownloadNewStories
    }
}

struct SyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SyncSettingsView()
        }
    }
} 