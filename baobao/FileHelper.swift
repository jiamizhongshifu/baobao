import Foundation
import os.log

class FileHelper {
    
    // 创建专用的日志记录器
    private static let logger = Logger(subsystem: "com.baobao.app", category: "file-helper")
    
    /// 获取文档目录URL
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// 获取Bundle中baobao_prototype目录的URL
    static var bundlePrototypeURL: URL? {
        // 首先尝试直接从Bundle中获取
        if let url = Bundle.main.url(forResource: "baobao_prototype", withExtension: nil) {
            logger.info("✅ 在Bundle中找到baobao_prototype目录: \(url.path)")
            return url
        }
        
        logger.error("❌ 无法在Bundle中找到baobao_prototype目录")
        logger.info("📂 Bundle路径: \(Bundle.main.bundlePath)")
        
        // 尝试在Bundle路径中查找
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let potentialURL = bundleURL.appendingPathComponent("baobao_prototype")
        
        if FileManager.default.fileExists(atPath: potentialURL.path) {
            logger.info("✅ 在Bundle路径中找到baobao_prototype目录: \(potentialURL.path)")
            return potentialURL
        }
        
        // 尝试在项目根目录中查找
        let projectURL = bundleURL.deletingLastPathComponent()
        let projectPotentialURL = projectURL.appendingPathComponent("baobao_prototype")
        
        if FileManager.default.fileExists(atPath: projectPotentialURL.path) {
            logger.info("✅ 在项目根目录中找到baobao_prototype目录: \(projectPotentialURL.path)")
            return projectPotentialURL
        }
        
        return nil
    }
    
    /// 创建测试资源
    static func createTestResources() {
        logger.info("创建测试资源")
        
        // 创建baobao_prototype目录
        let prototypeDir = documentsDirectory.appendingPathComponent("baobao_prototype")
        
        do {
            if !FileManager.default.fileExists(atPath: prototypeDir.path) {
                try FileManager.default.createDirectory(at: prototypeDir, withIntermediateDirectories: true)
                logger.info("✅ 创建baobao_prototype目录成功")
            }
            
            // 创建子目录
            let directories = ["css", "js", "images", "pages"]
            
            for dir in directories {
                let dirPath = prototypeDir.appendingPathComponent(dir)
                if !FileManager.default.fileExists(atPath: dirPath.path) {
                    try FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: true)
                    logger.info("✅ 创建\(dir)目录成功")
                }
            }
            
            // 创建测试HTML文件
            createTestHTMLFile(at: prototypeDir.appendingPathComponent("pages/home.html"))
            
            // 创建测试CSS文件
            createTestCSSFile(at: prototypeDir.appendingPathComponent("css/common.css"))
            
            // 创建测试JS文件
            createTestJSFile(at: prototypeDir.appendingPathComponent("js/common.js"))
            createTestAPIJSFile(at: prototypeDir.appendingPathComponent("js/api.js"))
            
            logger.info("✅ 测试资源创建完成")
        } catch {
            logger.error("❌ 创建测试资源失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建测试HTML文件
    private static func createTestHTMLFile(at url: URL) {
        let htmlContent = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>宝宝故事</title>
            <link rel="stylesheet" href="../css/common.css">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #F2E9DE;
                    color: #333;
                }
                
                h1 {
                    font-size: 24px;
                    text-align: center;
                    margin-bottom: 30px;
                }
                
                .card {
                    background-color: white;
                    border-radius: 15px;
                    padding: 20px;
                    margin-bottom: 20px;
                    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
                }
                
                .button {
                    display: block;
                    background-color: #000;
                    color: white;
                    text-align: center;
                    padding: 15px;
                    border-radius: 10px;
                    margin: 20px 0;
                    font-weight: bold;
                    text-decoration: none;
                }
            </style>
        </head>
        <body>
            <h1>宝宝故事</h1>
            
            <div class="card">
                <h2>测试页面</h2>
                <p>这是一个测试页面，用于验证WebView加载是否正常。</p>
                <p>如果你看到这个页面，说明WebView已经成功加载，但未能找到正确的资源文件。</p>
                <p>请检查baobao_prototype目录是否正确配置。</p>
            </div>
            
            <a href="#" class="button" id="testApiBtn">测试API</a>
            
            <script src="../js/common.js"></script>
            <script src="../js/api.js"></script>
            <script>
                document.getElementById('testApiBtn').addEventListener('click', function() {
                    // 测试API调用
                    if (typeof api !== 'undefined') {
                        api.getStories().then(function(result) {
                            alert('API调用成功: ' + JSON.stringify(result));
                        }).catch(function(error) {
                            alert('API调用失败: ' + error.message);
                        });
                    } else {
                        alert('API对象未定义，请检查api.js是否正确加载');
                    }
                });
                
                // 通知原生代码页面已加载
                try {
                    window.webkit.messageHandlers.pageLoaded.postMessage({
                        page: 'test',
                        status: 'success'
                    });
                } catch (e) {
                    console.log('无法通知原生代码页面已加载');
                }
            </script>
        </body>
        </html>
        """
        
        do {
            try htmlContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 创建测试HTML文件成功: \(url.path)")
        } catch {
            logger.error("❌ 创建测试HTML文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建测试CSS文件
    private static func createTestCSSFile(at url: URL) {
        let cssContent = """
        /* 基本样式 */
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #F2E9DE;
            color: #333;
        }
        
        /* 标题样式 */
        h1, h2, h3, h4, h5, h6 {
            margin-top: 0;
            font-weight: 700;
        }
        
        /* 链接样式 */
        a {
            color: #0066CC;
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        /* 按钮样式 */
        .button {
            display: inline-block;
            background-color: #000;
            color: white;
            padding: 12px 20px;
            border-radius: 10px;
            font-weight: 600;
            text-align: center;
            cursor: pointer;
            border: none;
            transition: background-color 0.3s;
        }
        
        .button:hover {
            background-color: #333;
        }
        
        /* 卡片样式 */
        .card {
            background-color: white;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
        }
        
        /* 加载动画 */
        .loading {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: rgba(255, 255, 255, 0.8);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 1000;
        }
        
        .loading-spinner {
            width: 50px;
            height: 50px;
            border: 5px solid #f3f3f3;
            border-top: 5px solid #3498db;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        /* Toast通知 */
        .toast {
            position: fixed;
            bottom: 50px;
            left: 50%;
            transform: translateX(-50%);
            background-color: rgba(0, 0, 0, 0.7);
            color: white;
            padding: 12px 20px;
            border-radius: 20px;
            font-size: 16px;
            z-index: 1000;
            opacity: 0;
            transition: opacity 0.3s;
            pointer-events: none;
        }
        
        .toast.show {
            opacity: 1;
        }
        """
        
        do {
            try cssContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 创建测试CSS文件成功: \(url.path)")
        } catch {
            logger.error("❌ 创建测试CSS文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建测试JS文件
    private static func createTestJSFile(at url: URL) {
        let jsContent = """
        // 页面加载完成后执行
        document.addEventListener('DOMContentLoaded', function() {
            console.log('页面加载完成');
        });
        
        // 显示加载动画
        function showLoading() {
            const loading = document.createElement('div');
            loading.className = 'loading';
            loading.id = 'loading';
            
            const spinner = document.createElement('div');
            spinner.className = 'loading-spinner';
            
            loading.appendChild(spinner);
            document.body.appendChild(loading);
        }
        
        // 隐藏加载动画
        function hideLoading() {
            const loading = document.getElementById('loading');
            if (loading) {
                loading.remove();
            }
        }
        
        // 显示Toast通知
        function showToast(message, duration = 2000) {
            // 获取或创建toast元素
            let toast = document.getElementById('toast');
            if (!toast) {
                toast = document.createElement('div');
                toast.id = 'toast';
                toast.className = 'toast';
                document.body.appendChild(toast);
            }
            
            // 设置消息
            toast.textContent = message;
            
            // 显示toast
            setTimeout(() => {
                toast.classList.add('show');
            }, 10);
            
            // 设置定时器，隐藏toast
            clearTimeout(toast.hideTimeout);
            toast.hideTimeout = setTimeout(() => {
                toast.classList.remove('show');
            }, duration);
        }
        
        // 处理来自原生代码的响应
        window.handleNativeResponse = function(callbackID, response) {
            console.log('收到原生响应:', callbackID, response);
            
            // 查找并执行回调
            if (window.api && window.api.callbacks && window.api.callbacks[callbackID]) {
                const callback = window.api.callbacks[callbackID];
                
                if (response.success) {
                    callback.resolve(response.data);
                } else {
                    callback.reject(new Error(response.error || '未知错误'));
                }
                
                // 删除回调
                delete window.api.callbacks[callbackID];
            } else {
                console.error('未找到回调:', callbackID);
            }
        };
        """
        
        do {
            try jsContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 创建测试JS文件成功: \(url.path)")
        } catch {
            logger.error("❌ 创建测试JS文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建测试API JS文件
    private static func createTestAPIJSFile(at url: URL) {
        let jsContent = """
        // API客户端
        class BaoBaoAPI {
            constructor() {
                // 回调存储
                this.callbacks = {};
                this.callbackIdCounter = 0;
                
                // 重试配置
                this.maxRetries = 3;
                this.retryDelay = 1000; // 毫秒
                
                // 网络状态
                this.isOnline = true;
                this.offlineQueue = [];
                
                // 检测是否在iOS环境中
                this.isInIOS = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.api;
                
                // 监听网络状态变化
                this.setupNetworkMonitoring();
            }
            
            // 设置网络监控
            setupNetworkMonitoring() {
                window.addEventListener('online', () => {
                    console.log('网络已连接');
                    this.isOnline = true;
                    this.processOfflineQueue();
                });
                
                window.addEventListener('offline', () => {
                    console.log('网络已断开');
                    this.isOnline = false;
                });
            }
            
            // 处理离线队列
            processOfflineQueue() {
                if (this.offlineQueue.length === 0) return;
                
                console.log(`处理离线队列，共${this.offlineQueue.length}个请求`);
                
                const queue = [...this.offlineQueue];
                this.offlineQueue = [];
                
                queue.forEach(item => {
                    this.sendMessage(item.action, item.params)
                        .then(item.callback.resolve)
                        .catch(item.callback.reject);
                });
            }
            
            // 判断操作是否需要网络
            requiresNetwork(action) {
                // 某些操作可能不需要网络
                const offlineActions = ['getLocalStories', 'getLocalSettings'];
                return !offlineActions.includes(action);
            }
            
            // 发送消息到原生API
            sendMessage(name, params = {}) {
                return new Promise((resolve, reject) => {
                    try {
                        // 生成回调ID
                        const callbackID = `callback_${Date.now()}_${this.callbackIdCounter++}`;
                        
                        // 保存回调函数
                        this.callbacks[callbackID] = { resolve, reject };
                        
                        // 构建消息
                        const message = {
                            callbackID,
                            params
                        };
                        
                        // 检查网络状态
                        if (!this.isOnline && this.requiresNetwork(name)) {
                            console.warn(`网络离线，将请求加入队列: ${name}`);
                            this.offlineQueue.push({
                                action: name,
                                params,
                                callback: { resolve, reject }
                            });
                            
                            // 显示离线提示
                            if (typeof showToast === 'function') {
                                showToast('当前处于离线状态，请求将在网络恢复后执行');
                            }
                            
                            return;
                        }
                        
                        // 如果在iOS环境中，发送消息到原生API
                        if (this.isInIOS) {
                            console.log(`发送API请求: ${name}`);
                            window.webkit.messageHandlers.api.postMessage(message);
                        } else {
                            // 否则，模拟响应（用于开发环境）
                            console.log(`模拟发送消息: ${name}`, message);
                            this.mockResponse(name, message);
                        }
                    } catch (e) {
                        console.error(`发送消息时出错: ${e.message}`);
                        reject(e);
                    }
                });
            }
            
            // 模拟响应（用于开发环境）
            mockResponse(name, message) {
                setTimeout(() => {
                    let response = {
                        success: true,
                        data: null
                    };
                    
                    try {
                        // 根据不同的API调用生成不同的模拟响应
                        switch (name) {
                            case 'getStories':
                                response.data = {
                                    stories: this.mockGetStories(message.params)
                                };
                                break;
                            default:
                                response.data = {
                                    message: `模拟响应: ${name} 调用成功`
                                };
                        }
                        
                        // 调用回调
                        window.handleNativeResponse(message.callbackID, response);
                    } catch (e) {
                        console.error(`生成模拟响应时出错: ${e.message}`);
                        window.handleNativeResponse(message.callbackID, {
                            success: false,
                            error: e.message
                        });
                    }
                }, 500); // 模拟网络延迟
            }
            
            // 模拟获取故事列表
            mockGetStories(params) {
                const { childName } = params || {};
                
                // 生成模拟故事列表
                const stories = [];
                const themes = ['魔法世界', '动物朋友', '太空冒险', '公主王子', '海底世界', '恐龙时代'];
                
                for (let i = 0; i < 5; i++) {
                    const theme = themes[Math.floor(Math.random() * themes.length)];
                    const name = childName || '小明';
                    
                    stories.push({
                        id: `story_${i}`,
                        title: `${name}的${theme}冒险`,
                        content: `这是一个关于${name}的${theme}冒险故事...`,
                        theme,
                        childName: name,
                        createdAt: new Date().toISOString()
                    });
                }
                
                return stories;
            }
            
            // API方法
            
            // 获取故事列表
            getStories(childName) {
                return this.sendMessage('getStories', { childName });
            }
            
            // 获取故事详情
            getStoryDetail(storyId) {
                return this.sendMessage('getStoryDetail', { storyId });
            }
            
            // 创建故事
            createStory(childName, theme) {
                return this.sendMessage('createStory', { childName, theme });
            }
        }
        
        // 创建API实例
        window.api = new BaoBaoAPI();
        """
        
        do {
            try jsContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 创建测试API JS文件成功: \(url.path)")
        } catch {
            logger.error("❌ 创建测试API JS文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 检查并解决文件冲突
    static func checkAndResolveConflicts() {
        logger.info("检查文件冲突")
        
        // 检查文档目录中是否存在baobao_prototype目录
        let documentsPrototypePath = documentsDirectory.appendingPathComponent("baobao_prototype").path
        
        if FileManager.default.fileExists(atPath: documentsPrototypePath) {
            logger.info("✅ 文档目录中存在baobao_prototype目录")
            return
        }
        
        // 如果不存在，尝试从Bundle中复制
        if let bundleURL = bundlePrototypeURL {
            do {
                try FileManager.default.copyItem(at: bundleURL, to: documentsDirectory.appendingPathComponent("baobao_prototype"))
                logger.info("✅ 成功从Bundle复制baobao_prototype目录到文档目录")
            } catch {
                logger.error("❌ 复制baobao_prototype目录失败: \(error.localizedDescription)")
                
                // 如果复制失败，创建测试资源
                createTestResources()
            }
        } else {
            logger.warning("⚠️ 未找到baobao_prototype目录，创建测试资源")
            createTestResources()
        }
    }
} 