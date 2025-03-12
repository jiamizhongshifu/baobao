# 宝宝故事应用 API 集成测试工具

这个目录包含用于测试宝宝故事应用 API 集成的脚本和工具。

## 文件说明

- `test_api_integration.swift`: API 集成测试脚本，用于测试 DeepSeek 故事生成 API 和 Azure 语音合成 API
- `integrate_api_results.swift`: 结果整合脚本，用于生成 API 集成测试报告
- `Config.plist`: 配置文件，用于存储 API 密钥和区域设置

## 使用方法

### 配置

1. 编辑 `Config.plist` 文件，设置以下参数：
   - `DEEPSEEK_API_KEY`: DeepSeek API 密钥
   - `AZURE_SPEECH_KEY`: Azure 语音服务 API 密钥
   - `AZURE_SPEECH_REGION`: Azure 语音服务区域（如 eastasia）

### 运行测试

1. 确保脚本具有执行权限：
   ```bash
   chmod +x test_api_integration.swift
   chmod +x integrate_api_results.swift
   ```

2. 运行 API 集成测试：
   ```bash
   ./test_api_integration.swift
   ```

3. 生成测试报告：
   ```bash
   ./integrate_api_results.swift
   ```

4. 查看测试报告：
   ```bash
   cat ~/Documents/api_integration_report.md
   ```

## 模拟测试模式

如果没有有效的 API 密钥，脚本会自动使用模拟数据进行测试。这对于开发和测试非常有用，可以在没有 API 访问的情况下验证应用逻辑。

## 测试内容

1. **故事生成 API 测试**：测试 DeepSeek API 生成儿童故事的能力
2. **语音合成 API 测试**：测试 Azure 语音服务将文本转换为语音的能力
3. **缓存机制测试**：测试故事和语音文件的缓存功能

## 服务实现

测试成功后，我们已经实现了以下服务类：

1. **StoryService**：用于生成故事，包含以下功能：
   - 故事主题和长度选择
   - 缓存机制
   - 错误处理和重试逻辑

2. **SpeechService**：用于合成语音，包含以下功能：
   - 多种语音类型选择
   - 缓存机制
   - 本地 TTS 作为备选方案
   - 错误处理

## 下一步

1. 将 API 集成逻辑合并到应用代码中
2. 添加用户界面，允许用户选择故事主题和角色
3. 实现故事播放功能，包括语音播放和文本显示
4. 添加故事收藏和分享功能
5. 实现离线模式，允许用户在无网络环境下使用应用

## 故障排除

### API密钥问题

- **问题**：出现"API密钥无效"错误
- **解决方案**：检查`Config.plist`文件中的API密钥是否正确，确保没有多余的空格或换行符

### 网络连接问题

- **问题**：出现"网络错误"或"请求超时"
- **解决方案**：检查网络连接，确保可以访问DeepSeek和Azure服务器

### 语音合成失败

- **问题**：语音合成失败，但故事生成成功
- **解决方案**：
  1. 检查Azure语音服务区域设置是否正确
  2. 确认Azure语音服务密钥有效
  3. 如果问题持续，可以设置`useLocalTTS = true`使用本地TTS

### 缓存问题

- **问题**：缓存测试失败
- **解决方案**：
  1. 检查用户是否有写入权限
  2. 确保磁盘空间充足
  3. 手动清理缓存目录后重试

## 联系方式

如有问题或建议，请联系开发团队：

- 邮箱：support@baobao.com
- 问题追踪：https://github.com/baobao/issues 