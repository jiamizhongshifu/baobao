# 宝宝故事应用配置指南

本文档详细说明了宝宝故事应用的配置文件使用方法，包括API密钥设置、语音服务配置和其他应用参数。

## 配置文件位置

配置文件位于应用根目录下的`Config.plist`文件中。这是一个标准的Property List文件，可以使用Xcode或任何文本编辑器进行编辑。

## 配置项说明

### API密钥配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `DEEPSEEK_API_KEY` | DeepSeek API密钥，用于故事生成 | 空 |
| `AZURE_SPEECH_KEY` | Azure语音服务密钥，用于语音合成 | 空 |
| `AZURE_SPEECH_REGION` | Azure语音服务区域，如eastasia、westus等 | eastasia |
| `AZURE_CUSTOM_VOICE_ID` | 自定义语音ID，由语音训练API返回 | 空 |

### 应用配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `APP_VERSION` | 应用版本号 | 1.0.0 |
| `DEFAULT_VOICE_TYPE` | 默认语音类型，可选值：萍萍阿姨、大卫叔叔、故事爷爷、甜甜姐姐、活泼童声 | 萍萍阿姨 |
| `DEFAULT_STORY_LENGTH` | 默认故事长度，可选值：短篇、中篇、长篇 | 中篇 |

### 缓存配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `CACHE_EXPIRY_DAYS` | 缓存过期天数，超过此天数的语音缓存将被自动清理 | 7 |

### 故事生成配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `MAX_STORY_RETRIES` | 故事生成API调用失败时的最大重试次数 | 5 |

### 安全配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `CONTENT_SAFETY_ENABLED` | 是否启用内容安全检查 | true |
| `ALLOW_CUSTOM_VOICE_TRAINING` | 是否允许自定义语音训练 | true |

### CloudKit同步配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `CLOUDKIT_SYNC_ENABLED` | 是否启用CloudKit同步功能 | true |
| `SYNC_ON_WIFI_ONLY` | 是否仅在Wi-Fi网络下进行同步 | true |
| `SYNC_FREQUENCY_HOURS` | 自动同步频率（小时） | 24 |
| `AUTO_DOWNLOAD_NEW_STORIES` | 是否自动下载其他设备上的新故事 | true |

### 开发配置

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `DEBUG_LOGGING_ENABLED` | 是否启用调试日志 | true |
| `USE_LOCAL_FALLBACK` | 当云服务不可用时，是否使用本地备用方案 | true |

## 获取API密钥

### DeepSeek API密钥

1. 访问 [DeepSeek官网](https://www.deepseek.com/)
2. 注册并创建一个API密钥
3. 将获取到的密钥填入`DEEPSEEK_API_KEY`配置项

### Azure语音服务密钥

1. 登录 [Azure门户](https://portal.azure.com/)
2. 创建一个"语音服务"资源
3. 在资源的"密钥和终结点"页面获取密钥
4. 将获取到的密钥填入`AZURE_SPEECH_KEY`配置项
5. 将资源所在区域填入`AZURE_SPEECH_REGION`配置项

## 配置示例

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DEEPSEEK_API_KEY</key>
    <string>sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>
    <key>AZURE_SPEECH_KEY</key>
    <string>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>
    <key>AZURE_SPEECH_REGION</key>
    <string>eastasia</string>
    <key>AZURE_CUSTOM_VOICE_ID</key>
    <string></string>
    <key>APP_VERSION</key>
    <string>1.0.0</string>
    <key>DEFAULT_VOICE_TYPE</key>
    <string>萍萍阿姨</string>
    <key>CACHE_EXPIRY_DAYS</key>
    <integer>7</integer>
    <key>DEFAULT_STORY_LENGTH</key>
    <string>中篇</string>
    <key>MAX_STORY_RETRIES</key>
    <integer>5</integer>
    <key>CONTENT_SAFETY_ENABLED</key>
    <true/>
    <key>ALLOW_CUSTOM_VOICE_TRAINING</key>
    <true/>
    <key>CLOUDKIT_SYNC_ENABLED</key>
    <true/>
    <key>SYNC_ON_WIFI_ONLY</key>
    <true/>
    <key>SYNC_FREQUENCY_HOURS</key>
    <integer>24</integer>
    <key>AUTO_DOWNLOAD_NEW_STORIES</key>
    <true/>
    <key>DEBUG_LOGGING_ENABLED</key>
    <true/>
    <key>USE_LOCAL_FALLBACK</key>
    <true/>
</dict>
</plist>
```

## 配置管理器使用方法

在代码中，可以通过`ConfigurationManager`类访问配置项：

```swift
// 获取DeepSeek API密钥
let apiKey = ConfigurationManager.shared.deepseekApiKey

// 获取默认语音类型
let defaultVoice = ConfigurationManager.shared.defaultVoiceType

// 检查是否允许自定义语音训练
if ConfigurationManager.shared.allowCustomVoiceTraining {
    // 执行语音训练
}

// 更新自定义语音ID
ConfigurationManager.shared.setCustomVoiceId("new-voice-id")
```

## 注意事项

1. 请勿将API密钥直接提交到版本控制系统中，建议使用环境变量或其他安全方式管理密钥
2. 在开发环境中，可以将`DEBUG_LOGGING_ENABLED`设置为`true`以获取更详细的日志
3. 在生产环境中，建议将`DEBUG_LOGGING_ENABLED`设置为`false`以提高性能
4. 如果不需要自定义语音功能，可以将`ALLOW_CUSTOM_VOICE_TRAINING`设置为`false`
5. 若要禁用CloudKit同步，将`CLOUDKIT_SYNC_ENABLED`设置为`false`
6. 使用CloudKit同步功能要求用户登录iCloud账户
7. 在移动网络下，若设置了`SYNC_ON_WIFI_ONLY`为`true`，则不会进行同步操作
8. 自动同步会按照`SYNC_FREQUENCY_HOURS`设置的时间间隔进行，也可以手动触发同步 