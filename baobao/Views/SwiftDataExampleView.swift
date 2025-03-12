import SwiftUI
import SwiftData

/// 展示如何在实际应用中使用SwiftData模型的示例视图
struct SwiftDataExampleView: View {
    // 获取模型上下文
    @Environment(\.modelContext) private var modelContext
    
    // 查询所有故事，按创建日期降序排序
    @Query(sort: \StoryModel.createdDate, order: .reverse) private var stories: [StoryModel]
    
    // 用户设置状态
    @State private var userSettings: UserSettingsModel?
    @State private var showingAddStory = false
    @State private var newStoryTitle = ""
    @State private var newStoryContent = ""
    @State private var selectedTheme = SDStoryTheme.space
    @State private var selectedLength = SDStoryLength.medium
    @State private var characterName = "小明"
    
    // 使用依赖注入方式
    private let modelManager: ModelManaging
    
    // 初始化方法，允许注入ModelManager
    init(modelManager: ModelManaging = ModelManager()) {
        self.modelManager = modelManager
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 用户设置卡片
                if let settings = userSettings {
                    userSettingsCard(settings)
                }
                
                // 故事列表
                List {
                    ForEach(stories) { story in
                        NavigationLink(destination: StoryDetailView(story: story)) {
                            StoryRowView(story: story)
                        }
                    }
                    .onDelete(perform: deleteStories)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("宝宝故事")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddStory = true
                    }) {
                        Label("添加故事", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddStory) {
                addStoryView
            }
            .onAppear {
                loadUserSettings()
            }
        }
    }
    
    // 用户设置卡片视图
    private func userSettingsCard(_ settings: UserSettingsModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("用户设置")
                    .font(.headline)
                Spacer()
                Button(action: {
                    toggleOfflineMode()
                }) {
                    Label(
                        settings.isOfflineModeEnabled ? "离线模式：开启" : "离线模式：关闭",
                        systemImage: settings.isOfflineModeEnabled ? "wifi.slash" : "wifi"
                    )
                    .font(.caption)
                }
            }
            
            Text("默认语音：\(settings.defaultVoiceType?.rawValue ?? "")")
                .font(.caption)
            
            Text("上次使用角色：\(settings.lastUsedCharacterName ?? "")")
                .font(.caption)
            
            Text("缓存设置：\(settings.maxCacheSizeMB)MB，\(settings.cacheExpiryDays)天过期")
                .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // 添加故事表单视图
    private var addStoryView: some View {
        NavigationStack {
            Form {
                Section(header: Text("故事信息")) {
                    TextField("标题", text: $newStoryTitle)
                    
                    TextField("内容", text: $newStoryContent)
                        .frame(height: 100)
                    
                    TextField("角色名称", text: $characterName)
                    
                    Picker("故事主题", selection: $selectedTheme) {
                        ForEach(SDStoryTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    Picker("故事长度", selection: $selectedLength) {
                        ForEach(SDStoryLength.allCases, id: \.self) { length in
                            Text(length.rawValue).tag(length)
                        }
                    }
                }
            }
            .navigationTitle("添加新故事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingAddStory = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        addStory()
                        showingAddStory = false
                    }
                    .disabled(newStoryTitle.isEmpty || newStoryContent.isEmpty)
                }
            }
        }
    }
    
    // 加载用户设置
    private func loadUserSettings() {
        userSettings = modelManager.getUserSettings(context: modelContext)
    }
    
    // 切换离线模式
    private func toggleOfflineMode() {
        if let settings = userSettings {
            settings.isOfflineModeEnabled.toggle()
            do {
                try modelContext.save()
            } catch {
                print("保存离线模式设置失败: \(error.localizedDescription)")
                // 可以在这里添加用户提示
            }
        }
    }
    
    // 添加新故事
    private func addStory() {
        let newStory = StoryModel(
            title: newStoryTitle,
            content: newStoryContent,
            theme: selectedTheme,
            characterName: characterName,
            lengthType: selectedLength
        )
        
        modelContext.insert(newStory)
        
        // 更新用户设置中的最后使用角色
        if let settings = userSettings {
            settings.lastUsedCharacterName = characterName
        }
        
        do {
            try modelContext.save()
            // 重置表单
            newStoryTitle = ""
            newStoryContent = ""
            showingAddStory = false
        } catch {
            print("保存新故事失败: \(error.localizedDescription)")
            // 可以在这里添加用户提示
        }
    }
    
    // 删除故事
    private func deleteStories(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stories[index])
        }
        
        do {
            try modelContext.save()
        } catch {
            print("删除故事失败: \(error.localizedDescription)")
            // 可以在这里添加用户提示
        }
    }
    
    // 添加语音
    private func addSpeech(for story: StoryModel, voiceType: SDVoiceType) {
        let newSpeech = SpeechModel(
            fileURL: "file:///tmp/speech_\(UUID().uuidString).mp3",
            voiceType: voiceType,
            fileSize: 1024 * 1024, // 1MB
            duration: 60, // 60秒
            isLocalTTS: false,
            story: story
        )
        
        modelContext.insert(newSpeech)
        do {
            try modelContext.save()
        } catch {
            print("保存语音失败: \(error.localizedDescription)")
            // 可以在这里添加用户提示
        }
    }
}

/// 故事行视图
struct StoryRowView: View {
    let story: StoryModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(story.title)
                    .font(.headline)
                Spacer()
                if story.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            Text("角色：\(story.characterName)")
                .font(.caption)
            
            HStack {
                Text("主题：\(story.storyTheme?.rawValue ?? "")")
                    .font(.caption)
                Spacer()
                Text("阅读次数：\(story.readCount)")
                    .font(.caption)
            }
            
            Text("创建于：\(story.formattedCreatedDate)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

/// 故事详情视图
struct StoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedVoiceType = SDVoiceType.xiaoMing
    
    let story: StoryModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 故事标题
                Text(story.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 故事元数据
                HStack {
                    VStack(alignment: .leading) {
                        Text("角色：\(story.characterName)")
                            .font(.subheadline)
                        Text("主题：\(story.storyTheme?.rawValue ?? "")")
                            .font(.subheadline)
                        Text("长度：\(story.storyLengthType?.rawValue ?? "")")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        toggleFavorite()
                    }) {
                        Image(systemName: story.isFavorite ? "star.fill" : "star")
                            .font(.title)
                            .foregroundColor(story.isFavorite ? .yellow : .gray)
                    }
                }
                .padding(.bottom)
                
                // 故事内容
                Text(story.content)
                    .font(.body)
                    .lineSpacing(8)
                
                Divider()
                
                // 语音选择
                VStack(alignment: .leading) {
                    Text("选择语音")
                        .font(.headline)
                    
                    Picker("语音类型", selection: $selectedVoiceType) {
                        ForEach(SDVoiceType.allCases, id: \.self) { voiceType in
                            Text(voiceType.rawValue).tag(voiceType)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Button(action: {
                        readStory()
                    }) {
                        Label("朗读故事", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                
                // 语音列表
                if let speeches = story.speeches, !speeches.isEmpty {
                    VStack(alignment: .leading) {
                        Text("已生成的语音")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(speeches) { speech in
                            speechRow(speech)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("故事详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            incrementReadCount()
        }
    }
    
    // 语音行视图
    private func speechRow(_ speech: SpeechModel) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("语音：\(speech.voiceType?.rawValue ?? "")")
                    .font(.subheadline)
                
                Text("大小：\(speech.formattedFileSize) • 时长：\(speech.formattedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                playSpeech(speech)
            }) {
                Image(systemName: "play.circle")
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
    
    // 切换收藏状态
    private func toggleFavorite() {
        story.toggleFavorite()
        try? modelContext.save()
    }
    
    // 增加阅读次数
    private func incrementReadCount() {
        story.incrementReadCount()
        try? modelContext.save()
    }
    
    // 朗读故事
    private func readStory() {
        // 这里应该调用SpeechService来合成语音
        print("朗读故事，使用语音：\(selectedVoiceType.rawValue)")
        
        // 模拟添加一个新的语音记录
        let newSpeech = SpeechModel(
            fileURL: "file:///tmp/speech_\(UUID().uuidString).mp3",
            voiceType: selectedVoiceType,
            fileSize: 1024 * 1024, // 1MB
            duration: 60, // 60秒
            isLocalTTS: false,
            story: story
        )
        
        modelContext.insert(newSpeech)
        try? modelContext.save()
    }
    
    // 播放语音
    private func playSpeech(_ speech: SpeechModel) {
        // 这里应该调用AVPlayer来播放语音
        print("播放语音：\(speech.fileURL)")
    }
}

#Preview {
    // 使用预览模型容器
    let container = ModelContainerSetup.getPreviewModelContainer()
    
    return SwiftDataExampleView()
        .modelContainer(container)
} 