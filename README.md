# 宝宝故事应用

宝宝故事应用是一款专为儿童设计的故事生成和讲述应用，使用DeepSeek AI生成个性化故事，并通过Azure语音服务将故事转换为语音。

## 功能特点

- **个性化故事生成**：根据孩子的名字、故事主题和长度生成定制故事
- **多种语音选择**：提供多种语音角色，包括小明哥哥、小红姐姐、萍萍阿姨、老王爷爷和机器人
- **离线模式支持**：预下载故事和语音，在无网络环境下也能使用
- **智能缓存管理**：自动管理缓存大小和过期时间，优化存储空间
- **网络状态感知**：根据网络状态自动调整应用行为，确保最佳用户体验

## 最新优化

我们对应用进行了全面优化，主要包括以下方面：

1. **统一配置管理**：
   - 创建了`ConfigurationManager`类，统一管理所有配置项
   - 支持从多个位置加载配置，提高灵活性
   - 添加了丰富的配置选项，支持自定义应用行为

2. **增强的缓存系统**：
   - 实现了`CacheManager`类，提供统一的缓存接口
   - 支持多种缓存类型（故事、语音、图像）
   - 自动管理缓存大小和过期时间
   - 提供高效的缓存查询和存储方法

3. **网络状态管理**：
   - 添加了`NetworkManager`类，实时监控网络状态
   - 支持WiFi和蜂窝网络区分
   - 提供离线模式控制接口
   - 根据网络状态自动调整应用行为

4. **服务层优化**：
   - 重构了`StoryService`和`SpeechService`，支持离线模式
   - 添加了重试机制和错误处理
   - 实现了预生成和预合成功能
   - 添加了本地TTS备选方案

5. **离线体验增强**：
   - 创建了`OfflineManager`类，提供全面的离线体验管理
   - 支持预下载常用故事和语音
   - 提供离线内容管理和查询功能
   - 实现了网络恢复自动处理

这些优化大大提升了应用的稳定性、性能和用户体验，特别是在网络不稳定或无网络环境下的使用体验。

## 系统架构

应用采用模块化设计，主要包含以下服务组件：

### 配置管理

`ConfigurationManager` 负责加载和管理应用配置，支持从多个位置加载配置文件：
- 应用包内的配置文件
- 文档目录中的配置文件
- 应用支持目录中的配置文件
- 开发环境中的项目根目录配置文件

### 缓存管理

`CacheManager` 提供统一的缓存管理机制，支持以下功能：
- 多种缓存类型（故事、语音、图像）
- 自动清理过期缓存
- 缓存大小限制和自动清理
- 高效的缓存查询和存储

### 网络管理

`NetworkManager` 负责监控网络状态和管理离线模式：
- 实时监控网络连接状态
- 支持WiFi和蜂窝网络区分
- 离线模式控制
- 网络请求和同步策略管理

### 故事服务

`StoryService` 负责故事生成和管理：
- 支持多种故事主题和长度
- 智能缓存机制，避免重复生成
- 离线模式支持，优先使用缓存内容
- 重试机制和错误处理
- 预生成功能，支持离线使用

### 语音服务

`SpeechService` 负责语音合成和管理：
- 支持多种语音角色
- Azure语音服务集成
- 本地TTS备选方案
- 智能缓存机制
- 离线模式支持

### 离线模式管理

`OfflineManager` 提供全面的离线体验管理：
- 预下载常用故事和语音
- 离线内容管理和查询
- 缓存统计和分析
- 网络恢复自动处理

## 离线模式支持

应用提供全面的离线模式支持，主要包括以下功能：

1. **手动离线模式**：用户可以手动启用离线模式，应用将不再尝试网络连接
2. **自动离线检测**：应用自动检测网络状态，在网络不可用时切换到离线模式
3. **预下载内容**：用户可以预先下载常用故事和语音，以便在离线时使用
4. **智能缓存**：应用智能管理缓存内容，确保最常用的内容保留在缓存中
5. **本地备选方案**：当网络不可用时，使用本地TTS作为备选方案

### 预下载功能

预下载功能允许用户提前下载内容以便离线使用：

1. 用户可以选择要预下载的角色名称
2. 应用会为每个角色和主题组合生成故事
3. 然后为每个故事合成语音
4. 预下载过程在后台进行，用户可以继续使用应用
5. 预下载进度实时显示，用户可以随时取消

### 离线内容管理

应用提供离线内容管理功能：

1. 查看已缓存的故事和语音
2. 查看缓存大小和统计信息
3. 清理缓存
4. 优先显示可离线使用的内容

## 配置选项

应用提供多种配置选项，可以通过`Config.plist`文件进行设置：

- `DEEPSEEK_API_KEY`：DeepSeek API密钥
- `AZURE_SPEECH_KEY`：Azure语音服务密钥
- `AZURE_SPEECH_REGION`：Azure语音服务区域
- `DEFAULT_VOICE_TYPE`：默认语音类型
- `CACHE_EXPIRY_DAYS`：缓存过期天数
- `MAX_CACHE_SIZE_MB`：最大缓存大小（MB）
- `USE_LOCAL_FALLBACK`：是否使用本地备选方案
- `USE_LOCAL_TTS_BY_DEFAULT`：是否默认使用本地TTS
- `AUTO_DOWNLOAD_NEW_STORIES`：是否自动下载新故事
- `SYNC_ON_WIFI_ONLY`：是否仅在WiFi下同步

## 开发指南

### 环境要求

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

### 依赖项

- AVFoundation：用于语音合成
- Network：用于网络状态监控
- Combine：用于响应式编程

### 配置文件

在项目根目录创建`Config.plist`文件，包含以下配置项：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DEEPSEEK_API_KEY</key>
    <string>your_deepseek_api_key</string>
    <key>AZURE_SPEECH_KEY</key>
    <string>your_azure_speech_key</string>
    <key>AZURE_SPEECH_REGION</key>
    <string>eastasia</string>
    <!-- 其他配置项 -->
</dict>
</plist>
```

## 使用示例

### 生成故事

```swift
// 生成故事
StoryService.shared.generateStory(
    theme: .space,
    characterName: "小明",
    length: .medium
) { result in
    switch result {
    case .success(let story):
        print("故事生成成功：\(story)")
    case .failure(let error):
        print("故事生成失败：\(error.localizedDescription)")
    }
}
```

### 合成语音

```swift
// 合成语音
SpeechService.shared.synthesizeSpeech(
    text: storyText,
    voiceType: .xiaoMing
) { result in
    switch result {
    case .success(let audioURL):
        print("语音合成成功：\(audioURL)")
    case .failure(let error):
        print("语音合成失败：\(error.localizedDescription)")
    }
}
```

### 预下载内容

```swift
// 预下载内容
OfflineManager.shared.preDownloadCommonContent(
    characterNames: ["小明", "小红"],
    progressCallback: { progress in
        print("预下载进度：\(progress * 100)%")
    }
) { success in
    if success {
        print("预下载完成")
    } else {
        print("预下载失败")
    }
}
```

### 启用离线模式

```swift
// 启用离线模式
OfflineManager.shared.enableOfflineMode()

// 禁用离线模式
OfflineManager.shared.disableOfflineMode()

// 切换离线模式
OfflineManager.shared.toggleOfflineMode()
```

## 未来计划

- 添加更多故事主题和语音角色
- 支持故事插图生成
- 实现用户自定义语音训练
- 添加家长控制功能
- 支持多语言故事生成

## 项目概述

宝宝故事应用旨在为3-8岁的儿童提供个性化的故事体验。家长可以输入孩子的名字、选择故事主题和长度，应用会自动生成一个以孩子为主角的有趣故事，并通过高质量的语音朗读出来。

### 主要功能

- **个性化故事生成**：以孩子为主角，生成适合儿童的有趣故事
- **多种故事主题**：太空冒险、海洋探险、森林奇遇、恐龙世界、童话王国等
- **语音朗读**：使用自然流畅的语音朗读故事
- **多种语音选择**：女声、男声、儿童声、机器人声等
- **离线模式**：保存故事和语音，支持离线阅读和收听
- **故事收藏**：收藏喜欢的故事，随时重温

## 技术架构

### 前端

- **SwiftUI**：构建现代化、响应式的用户界面
- **Combine**：处理异步事件和数据流
- **AVFoundation**：播放语音和音效

### 后端服务

- **DeepSeek AI**：生成个性化儿童故事
- **Azure语音服务**：将文本转换为自然流畅的语音
- **本地TTS**：作为在线服务的备选方案

### 数据存储

- **Core Data/SwiftData**：存储用户信息、故事内容和设置
- **文件系统**：缓存语音文件和故事内容

## 项目结构

```
baobao/
├── baobao/                  # 主应用代码
│   ├── App/                 # 应用入口和配置
│   ├── Models/              # 数据模型
│   ├── Views/               # 用户界面
│   ├── ViewModels/          # 视图模型
│   └── Services/            # 服务层
│       ├── Story/           # 故事生成服务
│       └── Speech/          # 语音合成服务
├── Scripts/                 # 测试和工具脚本
│   ├── test_api_integration.swift  # API集成测试
│   └── integrate_api_results.swift # 结果整合脚本
└── Resources/               # 资源文件
    ├── Sounds/              # 音效文件
    └── Images/              # 图像资源
```

## 开发进度

- [x] API集成测试
- [x] 故事生成服务实现
- [x] 语音合成服务实现
- [ ] 用户界面设计
- [ ] 数据存储实现
- [ ] 离线模式支持
- [ ] 故事收藏功能
- [ ] 应用测试和优化

## 安装和运行

### 环境要求

- macOS 13.0+
- Xcode 15.0+
- iOS 17.0+

### 配置

1. 克隆仓库
2. 在项目根目录创建`Config.plist`文件，包含以下内容：
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>DEEPSEEK_API_KEY</key>
       <string>your_deepseek_api_key</string>
       <key>AZURE_SPEECH_KEY</key>
       <string>your_azure_speech_key</string>
       <key>AZURE_SPEECH_REGION</key>
       <string>your_azure_region</string>
   </dict>
   </plist>
   ```
3. 打开`baobao.xcodeproj`
4. 构建并运行项目

## API集成测试

我们提供了API集成测试脚本，用于验证DeepSeek和Azure服务的集成。详细信息请参阅[Scripts/README.md](Scripts/README.md)。

## 贡献指南

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

## 许可证

本项目采用MIT许可证 - 详见[LICENSE](LICENSE)文件

## 联系方式

- 项目维护者：宝宝故事团队
- 邮箱：support@baobao.com 