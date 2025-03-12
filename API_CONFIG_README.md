# 宝宝故事应用 API 配置指南

本文档提供关于宝宝故事应用API密钥配置的详细指导，确保安全且正确地设置所有必要的API密钥。

## API密钥安全管理

### 🔑 为什么API密钥需要安全管理？

API密钥是敏感信息，泄露可能导致：
- 未授权使用造成的费用增加
- 滥用您的API配额
- 可能的数据泄露或服务中断

### 🛡️ 安全最佳实践

1. **永远不要提交真实API密钥到代码仓库**
2. **不要在团队间通过未加密渠道分享API密钥**
3. **定期轮换API密钥**
4. **为不同环境使用不同密钥**

## 配置步骤

### 1️⃣ 初始设置

1. 复制模板配置文件：
   ```bash
   cp Config.template.plist Config.plist
   ```

2. 编辑`Config.plist`文件，填入真实API密钥：
   - DeepSeek API密钥
   - Azure语音服务密钥和区域

3. 确认`.gitignore`文件已经包含`Config.plist`，防止意外提交

### 2️⃣ 获取API密钥

#### DeepSeek API

1. 访问[DeepSeek AI官网](https://www.deepseek.com/)
2. 注册/登录账户
3. 导航至API部分创建新密钥
4. 复制生成的密钥

#### Azure语音服务

1. 访问[Azure门户](https://portal.azure.com/)
2. 创建或选择一个语音服务资源
3. 在"密钥和终结点"部分获取密钥
4. 注意区域设置

## 本地配置示例

`Config.plist`文件示例（不要提交此文件）:

```xml
<key>DEEPSEEK_API_KEY</key>
<string>sk-xxxxxxxxxxxxxxxxxxxx</string>
<key>AZURE_SPEECH_KEY</key>
<string>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>
<key>AZURE_SPEECH_REGION</key>
<string>eastasia</string>
```

## 验证配置

启动应用后，可通过以下方式验证API密钥是否正确配置：

1. 生成新故事测试DeepSeek API
2. 使用语音朗读功能测试Azure语音服务
3. 使用CloudKit诊断工具检查同步功能

如果遇到"API密钥不正确"或类似错误，请检查：
- 密钥是否正确复制（无额外空格）
- 区域设置是否正确
- 账户是否有效和活跃

## 故障排除

遇到API问题时，可尝试：

1. 在配置管理器中打印当前使用的密钥（调试时）:
   ```swift
   print("DeepSeek密钥前10位: \(String(ConfigurationManager.shared.deepseekApiKey.prefix(10)))...")
   ```

2. 确认配置文件已正确放置:
   - 项目根目录
   - 或文档目录

3. 检查API服务状态:
   - [Azure状态页面](https://status.azure.com)
   - DeepSeek状态页面

## 生产环境建议

对于生产环境，建议：

1. 使用环境变量或加密存储
2. 实现API密钥轮换机制
3. 监控API使用情况
4. 设置API使用限制
5. 考虑使用API密钥管理服务

---

⚠️ **请记住**: 永远不要在GitHub或任何公共存储库中分享真实API密钥，即使是在截图中也不要包含。 