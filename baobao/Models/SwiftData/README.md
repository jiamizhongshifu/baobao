# SwiftData 模型设计

本目录包含宝宝故事应用的SwiftData模型设计，用于数据持久化和管理。

## 模型概述

我们设计了四个主要模型来满足应用的需求：

1. **StoryModel**: 存储故事信息
2. **SpeechModel**: 存储语音信息
3. **UserSettingsModel**: 存储用户设置
4. **CacheRecordModel**: 跟踪缓存内容

## 模型详情

### StoryModel

故事模型存储生成的故事内容和元数据。

**主要属性**:
- `id`: 唯一标识符
- `title`: 故事标题
- `content`: 故事内容
- `createdDate`: 创建日期
- `theme`: 故事主题（太空冒险、海洋探险等）
- `characterName`: 角色名称
- `lengthType`: 故事长度（短篇、中篇、长篇）
- `isFavorite`: 是否收藏
- `readCount`: 阅读次数
- `speeches`: 关联的语音列表

**主要方法**:
- `incrementReadCount()`: 增加阅读次数
- `toggleFavorite()`: 切换收藏状态

### SpeechModel

语音模型存储故事的语音合成信息。

**主要属性**:
- `id`: 唯一标识符
- `fileURL`: 语音文件URL
- `voiceTypeString`: 语音类型（小明哥哥、小红姐姐等）
- `createdDate`: 创建日期
- `fileSize`: 文件大小
- `duration`: 持续时间
- `isLocalTTS`: 是否为本地TTS生成
- `story`: 关联的故事

**主要方法**:
- `formattedFileSize`: 格式化文件大小
- `formattedDuration`: 格式化持续时间

### UserSettingsModel

用户设置模型存储应用的全局设置。

**主要属性**:
- `id`: 唯一标识符（固定为"userSettings"）
- `defaultVoiceTypeString`: 默认语音类型
- `isOfflineModeEnabled`: 是否启用离线模式
- `autoDownloadNewStories`: 是否自动下载新故事
- `syncOnWifiOnly`: 是否仅在WiFi下同步
- `maxCacheSizeMB`: 最大缓存大小（MB）
- `cacheExpiryDays`: 缓存过期天数
- `lastUsedCharacterName`: 上次使用的角色名称
- `lastUpdated`: 最后更新日期

**主要方法**:
- `toggleOfflineMode()`: 切换离线模式
- `updateDefaultVoiceType()`: 更新默认语音类型
- `updateCacheSettings()`: 更新缓存设置

### CacheRecordModel

缓存记录模型跟踪应用的缓存内容。

**主要属性**:
- `id`: 唯一标识符
- `cacheTypeString`: 缓存类型（故事、语音、图像）
- `filePath`: 文件路径
- `createdDate`: 创建日期
- `lastAccessedDate`: 最后访问日期
- `fileSize`: 文件大小
- `priorityValue`: 优先级
- `relatedItemId`: 关联的故事或语音ID

**主要方法**:
- `updateLastAccessedDate()`: 更新最后访问日期
- `updateFileSize()`: 更新文件大小
- `updatePriority()`: 更新优先级
- `ageInDays`: 获取缓存年龄（天数）
- `daysSinceLastAccess`: 获取上次访问距今时间（天数）

## 模型容器设置

`ModelContainerSetup` 提供了创建和配置SwiftData模型容器的方法：

- `getModelContainer()`: 获取应用的模型容器
- `getPreviewModelContainer()`: 获取预览用的模型容器（内存存储）

## 模型管理器

`ModelManager` 提供了对模型的访问和操作方法：

- `getUserSettings()`: 获取或创建用户设置
- `getStories()`: 获取故事列表
- `getStoriesByTheme()`: 获取特定主题的故事
- `getStoriesByCharacter()`: 获取特定角色的故事
- `getCacheRecords()`: 获取缓存记录
- `getExpiredCacheRecords()`: 获取过期缓存记录
- `calculateTotalCacheSize()`: 计算缓存总大小

## 使用示例

`SwiftDataUsageExamples` 提供了在应用中使用这些模型的示例代码：

### 在SwiftUI视图中使用

```swift
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
    }
}
```

### 在代码中使用

```swift
// 获取用户设置
let settings = ModelManager.shared.getUserSettings(context: modelContext)

// 获取收藏的故事
let favoriteStories = ModelManager.shared.getStories(context: modelContext, isFavoriteOnly: true)

// 添加新故事
let newStory = StoryModel(
    title: "新故事",
    content: "这是一个新故事的内容...",
    theme: .space,
    characterName: "小明",
    lengthType: .medium
)
modelContext.insert(newStory)
try? modelContext.save()
```

## 应用入口点设置

在应用的入口点设置模型容器：

```swift
@main
struct BaobaoApp: App {
    let modelContainer: ModelContainer
    
    init() {
        modelContainer = ModelContainerSetup.getModelContainer()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

## 最佳实践

1. 使用`@Query`在SwiftUI视图中获取数据
2. 使用`@Environment(\.modelContext)`获取模型上下文
3. 在修改数据后调用`try? modelContext.save()`保存更改
4. 使用`ModelManager`提供的方法进行复杂查询
5. 使用计算属性处理枚举值的存储和获取 