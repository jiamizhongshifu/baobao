# 宝宝故事应用 - 认证服务

## 概述

宝宝故事应用的认证服务提供了完整的用户认证和数据同步功能，支持多种登录方式和CloudKit同步。本文档详细介绍了认证服务的功能、架构和使用方法。

## 功能特点

- **多种登录方式**：支持Apple ID登录、微信登录和游客登录
- **CloudKit同步**：与iOS原生CloudKit集成，实现跨设备数据同步
- **用户资料管理**：支持查看和编辑用户资料
- **宝宝档案管理**：支持添加、编辑和管理多个宝宝的信息
- **游客账号升级**：支持将游客账号升级为正式账号
- **安全退出**：提供安全的退出登录功能

## 文件结构

- `js/auth.js` - 认证服务核心文件
- `js/api.js` - API调用服务
- `js/common.js` - 通用工具函数
- `pages/login.html` - 登录页面
- `pages/profile.html` - 用户资料页面
- `pages/welcome.html` - 欢迎页面
- `pages/baby_management.html` - 宝宝管理页面

## 认证服务API

### 初始化

```javascript
// 页面加载时自动初始化
document.addEventListener('DOMContentLoaded', function() {
    auth.init();
});

// 手动初始化
auth.init();
```

### 登录方法

```javascript
// Apple ID登录
const success = await auth.loginWithApple();

// 微信登录
const success = await auth.loginWithWeChat();

// 游客登录
const success = await auth.loginWithGuest();
```

### 用户信息管理

```javascript
// 获取当前用户
const user = auth.getCurrentUser();

// 检查是否已登录
const isLoggedIn = auth.isLoggedIn();

// 检查是否是游客
const isGuest = auth.isGuestUser();

// 更新用户信息
const success = await auth.updateUserInfo({
    name: '新昵称',
    email: 'new@example.com'
});

// 将游客账号升级为正式账号
const success = await auth.upgradeGuestAccount('apple'); // 或 'wechat'
```

### CloudKit同步

```javascript
// 初始化CloudKit同步
const success = await auth.initCloudKitSync();

// 禁用CloudKit同步
const success = await auth.disableCloudKitSync();

// 手动触发同步
const success = await auth.triggerCloudKitSync();

// 获取CloudKit状态
const status = auth.getCloudKitStatus(); // 'available', 'unavailable', 'syncing', 'unknown'
```

### 退出登录

```javascript
const success = await auth.logout();
```

### 事件监听

```javascript
// 登录成功事件
document.addEventListener('userLogin', function(event) {
    const user = event.detail;
    console.log('用户登录成功:', user);
});

// 退出登录事件
document.addEventListener('userLogout', function() {
    console.log('用户已退出登录');
});

// CloudKit同步就绪事件
document.addEventListener('cloudKitSyncReady', function() {
    console.log('CloudKit同步已准备就绪');
});

// CloudKit同步失败事件
document.addEventListener('cloudKitSyncFailed', function(event) {
    console.error('CloudKit同步失败:', event.detail.error);
});

// CloudKit同步完成事件
document.addEventListener('cloudKitSyncCompleted', function() {
    console.log('CloudKit同步已完成');
});

// CloudKit同步禁用事件
document.addEventListener('cloudKitSyncDisabled', function() {
    console.log('CloudKit同步已禁用');
});
```

## 与iOS原生应用集成

认证服务通过WebKit消息处理程序与iOS原生应用进行通信。iOS应用需要实现以下消息处理程序：

```swift
// 在WKWebView配置中添加消息处理程序
let contentController = WKUserContentController()
contentController.add(self, name: "auth")

// 处理来自JavaScript的消息
func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any],
          let action = body["action"] as? String else {
        return
    }
    
    switch action {
    case "loginWithApple":
        // 处理Apple登录
        handleAppleLogin(message)
    case "loginWithWeChat":
        // 处理微信登录
        handleWeChatLogin(message)
    case "logout":
        // 处理退出登录
        handleLogout(message)
    case "updateUserInfo":
        // 处理更新用户信息
        if let userInfo = body["userInfo"] as? [String: Any] {
            handleUpdateUserInfo(userInfo, message)
        }
    case "initCloudKitSync":
        // 初始化CloudKit同步
        handleInitCloudKitSync(message)
    case "disableCloudKitSync":
        // 禁用CloudKit同步
        handleDisableCloudKitSync(message)
    case "triggerCloudKitSync":
        // 触发CloudKit同步
        handleTriggerCloudKitSync(message)
    case "userLoggedIn":
        // 处理用户登录通知
        if let user = body["user"] as? [String: Any] {
            handleUserLoggedIn(user)
        }
    default:
        break
    }
}

// 向JavaScript发送回调结果
func sendCallbackResult(success: Bool, data: Any? = nil, error: String? = nil, callbackName: String) {
    let result: [String: Any] = [
        "success": success,
        "data": data ?? NSNull(),
        "error": error ?? NSNull()
    ]
    
    let js = "\(callbackName)(\(result.jsonString))"
    webView.evaluateJavaScript(js, completionHandler: nil)
}
```

## 页面说明

### 登录页面 (login.html)

登录页面提供了三种登录方式：Apple ID登录、微信登录和游客登录。用户可以选择任意一种方式进行登录。

### 用户资料页面 (profile.html)

用户资料页面显示用户的基本信息，并提供以下功能：

- 编辑用户资料
- 管理CloudKit同步设置
- 查看账号信息
- 升级游客账号
- 退出登录

### 宝宝管理页面 (baby_management.html)

宝宝管理页面允许用户管理多个宝宝的信息，提供以下功能：

- 查看所有宝宝的基本信息（姓名、年龄、性别）
- 查看宝宝的兴趣标签
- 添加新的宝宝信息
- 编辑现有宝宝信息
- 删除宝宝信息
- 上传和管理宝宝头像照片
- 数据持久化存储，使用浏览器的localStorage保存宝宝信息

宝宝管理页面使用了现代化的UI设计和交互体验，包括：
- 卡片式布局展示宝宝信息
- 头像上传与预览功能
- 弹窗表单进行添加和编辑操作
- 删除确认对话框防止误操作
- 空状态提示，引导用户添加第一个宝宝信息
- 响应式设计，适配不同屏幕尺寸

### 欢迎页面 (welcome.html)

欢迎页面是应用的入口页面，提供快速登录选项和创建故事的入口。

## 安全考虑

- 敏感信息（如API密钥）不应存储在客户端代码中
- 用户密码和认证令牌应通过安全通道传输
- 应用应实现适当的会话管理和令牌刷新机制
- 对于生产环境，应考虑实现更强大的安全措施，如HTTPS、CSRF保护等

## 本地存储

认证服务使用localStorage存储用户信息，以便在页面刷新后保持登录状态。存储的信息包括：

- 用户ID
- 用户名称
- 登录类型
- 电子邮件（如果有）
- 头像URL（如果有）

## 调试与日志

认证服务集成了应用的日志系统，可以通过以下方式查看日志：

```javascript
// 启用调试模式
Logger.init({ level: Logger.LEVELS.DEBUG, pageOutput: true });
```

## 未来改进

- 添加更多第三方登录选项（如Google、Facebook等）
- 实现双因素认证
- 添加密码重置功能
- 改进错误处理和用户反馈
- 实现更强大的数据同步冲突解决机制

## 贡献

欢迎对认证服务进行改进和扩展。请遵循项目的代码风格和贡献指南。

## 功能使用说明

### 宝宝管理功能

宝宝管理功能允许用户管理多个宝宝的信息档案，方便为不同的宝宝创建和管理故事。以下是使用步骤：

#### 访问宝宝管理页面

有以下几种方式可以访问宝宝管理页面：
1. 从主页点击侧边栏中的"宝宝管理"选项
2. 从主页点击侧边栏头部的宝宝名称
3. 从主页点击宝宝信息区域

#### 添加宝宝信息

1. 在宝宝管理页面，点击"添加宝宝"按钮
2. 在弹出的表单中，可以选择上传宝宝头像（可选）
3. 填写宝宝的昵称、年龄信息
4. 选择宝宝的性别（男宝宝/女宝宝）
5. 添加宝宝的兴趣标签（可选，可添加多个）
   - 在输入框中输入标签名称，按回车键添加
   - 可点击已添加标签旁的"×"按钮删除
6. 点击"保存"按钮完成添加

#### 编辑宝宝信息

1. 在宝宝信息卡片上，点击右上角的编辑按钮（铅笔图标）
2. 在弹出的表单中修改宝宝信息
3. 点击"保存"按钮完成编辑

#### 删除宝宝信息

1. 在宝宝信息卡片上，点击右上角的删除按钮（垃圾桶图标）
2. 在弹出的确认对话框中，点击"删除"按钮确认删除，或点击"取消"取消操作

#### 数据存储

宝宝信息会自动保存在浏览器的本地存储（localStorage）中，即使关闭浏览器或刷新页面，数据也不会丢失。

**注意**：清除浏览器缓存会导致保存的宝宝信息被删除。在生产环境中，建议实现与云端的数据同步功能，确保数据安全。

## 许可证

本项目采用MIT许可证。详情请参阅LICENSE文件。 