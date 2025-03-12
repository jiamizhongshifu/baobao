import Foundation
import SwiftData
import SwiftUI

/// SwiftData使用示例
struct SwiftDataUsageExamples {
    
    // MARK: - 在SwiftUI视图中使用SwiftData
    
    /// 故事列表视图示例
    struct StoryListView: View {
        @Environment(\.modelContext) private var modelContext
        @Query(sort: \StoryModel.createdDate, order: .reverse) private var stories: [StoryModel]
        
        var body: some View {
            List {
                ForEach(stories) { story in
                    NavigationLink(destination: StoryDetailView(story: story)) {
                        StoryRowView(story: story)
                    }
                }
                .onDelete(perform: deleteStories)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSampleStory) {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
        }
        
        private func addSampleStory() {
            let newStory = StoryModel(
                title: "新故事",
                content: "这是一个新故事的内容...",
                theme: .space,
                characterName: "小明",
                lengthType: .medium
            )
            modelContext.insert(newStory)
            try? modelContext.save()
        }
        
        private func deleteStories(offsets: IndexSet) {
            for index in offsets {
                modelContext.delete(stories[index])
            }
            try? modelContext.save()
        }
    }
    
    /// 故事行视图示例
    struct StoryRowView: View {
        let story: StoryModel
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(story.title)
                    .font(.headline)
                
                HStack {
                    Text(story.characterName)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(story.storyTheme?.rawValue ?? "")
                        .font(.caption)
                        .padding(4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    if story.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(story.formattedCreatedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    /// 故事详情视图示例
    struct StoryDetailView: View {
        @Environment(\.modelContext) private var modelContext
        @State private var selectedVoiceType: VoiceType = .xiaoMing
        
        let story: StoryModel
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(story.title)
                        .font(.largeTitle)
                        .bold()
                    
                    HStack {
                        Text("主角: \(story.characterName)")
                        Spacer()
                        Text("主题: \(story.storyTheme?.rawValue ?? "")")
                    }
                    .font(.subheadline)
                    
                    Divider()
                    
                    Text(story.content)
                        .font(.body)
                        .lineSpacing(6)
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("选择朗读语音:")
                            .font(.headline)
                        
                        Picker("语音类型", selection: $selectedVoiceType) {
                            ForEach(VoiceType.allVoiceTypes, id: \.self) { voiceType in
                                Text(voiceType.rawValue).tag(voiceType)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Button(action: synthesizeSpeech) {
                            Label("开始朗读", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleFavorite) {
                        Image(systemName: story.isFavorite ? "star.fill" : "star")
                            .foregroundColor(story.isFavorite ? .yellow : .gray)
                    }
                }
            }
            .onAppear {
                story.incrementReadCount()
                try? modelContext.save()
            }
        }
        
        private func toggleFavorite() {
            story.toggleFavorite()
            try? modelContext.save()
        }
        
        private func synthesizeSpeech() {
            // 这里应该调用SpeechService来合成语音
            print("为故事《\(story.title)》合成\(selectedVoiceType.rawValue)语音")
            
            // 示例：创建语音记录
            let speech = SpeechModel(
                fileURL: "file:///path/to/speech/\(UUID().uuidString).mp3",
                voiceType: selectedVoiceType,
                fileSize: 1024 * 1024, // 示例大小
                duration: 120, // 示例时长
                story: story
            )
            
            modelContext.insert(speech)
            try? modelContext.save()
        }
    }
    
    // MARK: - 在代码中使用SwiftData
    
    /// 故事服务示例
    class StoryServiceExample {
        let modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }
        
        /// 生成新故事
        func generateStory(theme: StoryTheme, characterName: String, length: StoryLength, completion: @escaping (Result<StoryModel, Error>) -> Void) {
            // 这里应该调用AI服务生成故事内容
            // 示例中直接创建一个假故事
            
            let title = "\(characterName)的\(theme.rawValue)"
            let content = "这是一个关于\(characterName)的\(theme.rawValue)故事。这个故事很\(length.rawValue)..."
            
            let story = StoryModel(
                title: title,
                content: content,
                theme: theme,
                characterName: characterName,
                lengthType: length
            )
            
            modelContext.insert(story)
            
            do {
                try modelContext.save()
                completion(.success(story))
            } catch {
                completion(.failure(error))
            }
        }
        
        /// 获取收藏的故事
        func getFavoriteStories() -> [StoryModel] {
            return ModelManager.shared.getStories(context: modelContext, isFavoriteOnly: true)
        }
        
        /// 获取特定主题的故事
        func getStoriesByTheme(theme: StoryTheme) -> [StoryModel] {
            return ModelManager.shared.getStoriesByTheme(context: modelContext, theme: theme)
        }
        
        /// 删除故事
        func deleteStory(_ story: StoryModel) {
            modelContext.delete(story)
            try? modelContext.save()
        }
    }
    
    /// 缓存管理示例
    class CacheManagerExample {
        let modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }
        
        /// 添加缓存记录
        func addCacheRecord(type: CacheType, filePath: String, fileSize: Int64, relatedItemId: String? = nil) {
            let record = CacheRecordModel(
                cacheType: type,
                filePath: filePath,
                fileSize: fileSize,
                priority: .medium,
                relatedItemId: relatedItemId
            )
            
            modelContext.insert(record)
            try? modelContext.save()
        }
        
        /// 清理过期缓存
        func cleanExpiredCache(expiryDays: Int) {
            let expiredRecords = ModelManager.shared.getExpiredCacheRecords(context: modelContext, expiryDays: expiryDays)
            
            for record in expiredRecords {
                // 删除文件
                let fileURL = URL(string: record.filePath)
                if let fileURL = fileURL {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                // 删除记录
                modelContext.delete(record)
            }
            
            try? modelContext.save()
        }
        
        /// 获取缓存统计信息
        func getCacheStatistics() -> (count: Int, totalSize: String) {
            let records = ModelManager.shared.getCacheRecords(context: modelContext)
            let totalSize = records.reduce(0) { $0 + $1.fileSize }
            
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
            byteCountFormatter.countStyle = .file
            
            return (records.count, byteCountFormatter.string(fromByteCount: totalSize))
        }
    }
    
    /// 用户设置管理示例
    class UserSettingsManagerExample {
        let modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }
        
        /// 获取用户设置
        func getUserSettings() -> UserSettingsModel {
            return ModelManager.shared.getUserSettings(context: modelContext)
        }
        
        /// 更新默认语音类型
        func updateDefaultVoiceType(_ voiceType: VoiceType) {
            let settings = getUserSettings()
            settings.updateDefaultVoiceType(voiceType)
            try? modelContext.save()
        }
        
        /// 切换离线模式
        func toggleOfflineMode() {
            let settings = getUserSettings()
            settings.toggleOfflineMode()
            try? modelContext.save()
        }
        
        /// 更新缓存设置
        func updateCacheSettings(maxSizeMB: Int, expiryDays: Int) {
            let settings = getUserSettings()
            settings.updateCacheSettings(maxSizeMB: maxSizeMB, expiryDays: expiryDays)
            try? modelContext.save()
        }
    }
}

// MARK: - 应用入口点示例
struct SwiftDataAppExample: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = ModelContainerSetup.getModelContainer()
        } catch {
            fatalError("无法创建ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                SwiftDataUsageExamples.StoryListView()
            }
            .navigationViewStyle(.stack)
        }
        .modelContainer(modelContainer)
    }
} 