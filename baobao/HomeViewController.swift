@preconcurrency
import UIKit
@preconcurrency
import WebKit
import os.log
import Network
// 导入API服务
import Foundation

// 定义错误类型枚举
enum WebViewError: Error {
    case invalidURL
    case networkError(Error)
    case loadingFailed(Error)
    case javascriptError(Error)
    case apiError(String)
    case processTerminated(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL地址"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .loadingFailed(let error):
            return "页面加载失败: \(error.localizedDescription)"
        case .javascriptError(let error):
            return "JavaScript执行错误: \(error.localizedDescription)"
        case .apiError(let message):
            return "API错误: \(message)"
        case .processTerminated(let reason):
            return "WebView进程终止: \(reason)"
        }
    }
}

class HomeViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    private var webView: WKWebView!
    private let logger = Logger(subsystem: "com.example.baobao", category: "HomeViewController")
    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable = true
    private var loadingView: UIView?
    private var retryButton: UIButton?
    private var loadingIndicator: UIActivityIndicatorView?
    private var errorLabel: UILabel?
    private var resourceLoadCount = 0
    
    // 添加性能指标追踪
    private var pageLoadStartTime: Date?
    private var jsErrorCount = 0
    private var processTerminationCount = 0
    private var lastProcessTerminationTime: Date?
    private var isRecoveringFromCrash = false
    
    // 配置常量
    private let maxProcessTerminationRetries = 3
    private let processTerminationCooldown: TimeInterval = 5 // 秒
    private let memoryWarningThreshold: Float = 0.8 // 80%
    
    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("🚀 HomeViewController - viewDidLoad")
        
        // 设置内存压力观察
        setupMemoryPressureHandling()
        
        // 设置网络监控
        setupNetworkMonitoring()
        
        // 设置用户界面
        setupUI()
        
        // 加载WebView
        loadWebView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logger.info("HomeViewController - viewWillAppear")
        
        // 隐藏导航栏
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        logger.info("HomeViewController - viewWillDisappear")
        
        // 显示导航栏（如果需要）
        // navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - 内存压力处理
    
    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        logger.warning("⚠️ 收到内存警告")
        
        // 清理WebView缓存
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [weak self] in
            self?.logger.info("✅ WebView缓存已清理")
        }
        
        // 如果内存使用率超过阈值，重新加载WebView
        if let memoryUsage = getMemoryUsage(), memoryUsage > memoryWarningThreshold {
            logger.warning("⚠️ 内存使用率过高: \(String(format: "%.1f%%", memoryUsage * 100))")
            recreateWebView()
        }
    }
    
    private func getMemoryUsage() -> Float? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Float(info.resident_size) / Float(ProcessInfo.processInfo.physicalMemory)
        }
        return nil
    }
    
    private func recreateWebView() {
        logger.info("🔄 重新创建WebView")
        
        // 保存当前URL
        let currentURL = webView.url
        
        // 移除旧的WebView
        webView.stopLoading()
        webView.removeFromSuperview()
        
        // 创建新的WebView配置
        let configuration = createWebViewConfiguration()
        
        // 创建新的WebView
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.allowsBackForwardNavigationGestures = false
        
        // 添加到视图
        view.insertSubview(webView, at: 0)
        
        // 重新加载之前的URL
        if let url = currentURL {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            webView.load(request)
        } else {
            loadWebView()
        }
    }
    
    // MARK: - WebView配置
    
    private func createWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // 添加消息处理器
        contentController.add(self, name: "api")
        contentController.add(self, name: "pageLoaded")
        contentController.add(self, name: "logError")
        
        configuration.userContentController = contentController
        
        // 优化WebView性能和安全设置
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            configuration.preferences.javaScriptEnabled = true
        }
        
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 允许本地文件访问
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // 使用持久化数据存储
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // 设置进程池配置
        configuration.processPool = WKProcessPool()
        
        // 设置内存配置
        if #available(iOS 13.0, *) {
            configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        
        configuration.suppressesIncrementalRendering = false
        
        return configuration
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        logger.info("设置用户界面")
        
        // 设置视图背景色
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        // 创建WebView配置
        let configuration = createWebViewConfiguration()
        
        // 创建WebView
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 优化WebView性能
        webView.allowsBackForwardNavigationGestures = false
        
        // 添加WebView到视图
        view.addSubview(webView)
        
        // 创建加载视图
        createLoadingView()
        
        // 注入错误捕获脚本
        injectErrorCatchingScript()
    }
    
    // MARK: - WebView Loading
    
    private func loadWebView() {
        logger.info("📱 加载WebView开始")
        
        // 如果正在从崩溃中恢复，等待一段时间
        if isRecoveringFromCrash {
            logger.info("⏳ 等待进程恢复...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isRecoveringFromCrash = false
                self?.loadWebView()
            }
            return
        }
        
        // 记录开始加载时间
        pageLoadStartTime = Date()
        resourceLoadCount = 0
        
        // 显示加载视图
        showLoadingView()
        
        // 获取HTML文件路径
        let htmlPath = getHTMLPath()
        
        // 创建文件URL并设置正确的访问权限
        let fileURL = URL(fileURLWithPath: htmlPath)
        // 获取项目根目录（baobao_prototype的父目录）
        let baseURL = fileURL.deletingLastPathComponent().deletingLastPathComponent()
        
        logger.info("📄 加载本地文件: \(fileURL.absoluteString)")
        logger.info("📂 基础目录: \(baseURL.absoluteString)")
        
        // 配置 WKWebView 的文件访问权限
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // 使用 loadFileURL 方法并允许读取整个项目目录
        webView.loadFileURL(fileURL, allowingReadAccessTo: baseURL)
    }
    
    private func getHTMLPath() -> String {
        logger.info("🔍 获取HTML文件路径")
        
        // 首先尝试从文档目录获取
        let documentsPath = FileHelper.documentsDirectory.appendingPathComponent("baobao_prototype/pages/home.html").path
        
        if FileManager.default.fileExists(atPath: documentsPath) {
            logger.info("✅ 在文档目录中找到HTML文件: \(documentsPath)")
            return documentsPath
        }
        
        // 然后尝试从Bundle获取
        if let bundlePath = Bundle.main.path(forResource: "home", ofType: "html", inDirectory: "baobao_prototype/pages") {
            logger.info("✅ 在Bundle中找到HTML文件: \(bundlePath)")
            return bundlePath
        }
        
        // 最后尝试从工作目录获取
        let workingPath = FileManager.default.currentDirectoryPath + "/baobao_prototype/pages/home.html"
        
        if FileManager.default.fileExists(atPath: workingPath) {
            logger.info("✅ 在工作目录中找到HTML文件: \(workingPath)")
            return workingPath
        }
        
        // 如果都找不到，返回测试HTML
        logger.warning("⚠️ 未找到HTML文件，使用测试HTML")
        return Bundle.main.path(forResource: "test", ofType: "html") ?? ""
    }
    
    // MARK: - Loading View
    
    private func createLoadingView() {
        loadingView = UIView(frame: view.bounds)
        loadingView?.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        loadingView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 创建加载指示器
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator?.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY - 50)
        loadingIndicator?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        loadingIndicator?.hidesWhenStopped = true
        loadingIndicator?.color = .gray
        
        // 创建错误标签
        errorLabel = UILabel(frame: CGRect(x: 20, y: view.bounds.midY, width: view.bounds.width - 40, height: 40))
        errorLabel?.textAlignment = .center
        errorLabel?.textColor = .darkGray
        errorLabel?.font = UIFont.systemFont(ofSize: 16)
        errorLabel?.numberOfLines = 0
        errorLabel?.isHidden = true
        errorLabel?.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        
        // 创建重试按钮
        retryButton = UIButton(type: .system)
        retryButton?.frame = CGRect(x: view.bounds.midX - 50, y: view.bounds.midY + 50, width: 100, height: 44)
        retryButton?.setTitle("重试", for: .normal)
        retryButton?.backgroundColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        retryButton?.setTitleColor(.white, for: .normal)
        retryButton?.layer.cornerRadius = 22
        retryButton?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        retryButton?.addTarget(self, action: #selector(retryLoading), for: .touchUpInside)
        retryButton?.isHidden = true
        
        // 添加到加载视图
        if let loadingIndicator = loadingIndicator, let errorLabel = errorLabel, let retryButton = retryButton, let loadingView = loadingView {
            loadingView.addSubview(loadingIndicator)
            loadingView.addSubview(errorLabel)
            loadingView.addSubview(retryButton)
        }
        
        // 添加到主视图但不显示
        if let loadingView = loadingView {
            view.addSubview(loadingView)
            loadingView.isHidden = true
        }
    }
    
    private func showLoadingView() {
        loadingView?.isHidden = false
        errorLabel?.isHidden = true
        retryButton?.isHidden = true
        loadingIndicator?.startAnimating()
    }
    
    private func hideLoadingView() {
        loadingIndicator?.stopAnimating()
        loadingView?.isHidden = true
    }
    
    private func showError(message: String) {
        loadingIndicator?.stopAnimating()
        errorLabel?.text = message
        errorLabel?.isHidden = false
        retryButton?.isHidden = false
        
        // 记录错误日志
        logger.error("🛑 显示错误: \(message)")
    }
    
    @objc private func retryLoading() {
        logger.info("🔄 重试加载WebView")
        loadWebView()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let oldStatus = self?.isNetworkAvailable ?? false
                self?.isNetworkAvailable = path.status == .satisfied
                
                // 记录网络状态变化
                if oldStatus != self?.isNetworkAvailable {
                    if self?.isNetworkAvailable == true {
                        self?.logger.info("🌐 网络状态变更: 已连接")
                        
                        // 如果网络恢复且WebView未加载，尝试重新加载
                        if self?.webView.url == nil {
                            self?.loadWebView()
                        }
                    } else {
                        self?.logger.warning("⚠️ 网络状态变更: 已断开")
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor?.start(queue: queue)
        logger.info("🌐 网络监控已启动")
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        logger.info("🔄 WebView开始加载")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        logger.info("📄 WebView已开始接收内容")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 计算加载时间
        if let startTime = pageLoadStartTime {
            let loadTime = Date().timeIntervalSince(startTime)
            logger.info("✅ WebView加载完成，耗时: \(String(format: "%.2f", loadTime))秒，加载资源数: \(self.resourceLoadCount)")
        } else {
            logger.info("✅ WebView加载完成")
        }
        
        hideLoadingView()
        
        // 注入性能监控脚本
        injectPerformanceMonitoringScript()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("❌ WebView加载失败: \(error.localizedDescription)")
        showError(message: "页面加载失败，请重试")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("❌ WebView预加载失败: \(error.localizedDescription)")
        
        // 检查是否是进程终止错误
        if (error as NSError).code == WKError.webContentProcessTerminated.rawValue {
            handleProcessTermination()
        } else {
            showError(message: "无法连接到页面，请检查网络连接")
        }
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        logger.error("❌ WebView进程已终止")
        handleProcessTermination()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 记录导航请求
        if let url = navigationAction.request.url {
            logger.info("🔗 WebView导航请求: \(url.absoluteString)")
        }
        
        // 允许所有导航
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // 记录导航响应
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            logger.info("📥 WebView导航响应: \(httpResponse.statusCode) \(navigationResponse.response.url?.absoluteString ?? "")")
            
            // 检查HTTP状态码
            if httpResponse.statusCode >= 400 {
                logger.error("⚠️ HTTP错误: \(httpResponse.statusCode)")
            }
        }
        
        // 允许所有响应
        decisionHandler(.allow)
    }
    
    // MARK: - 性能监控
    
    private func injectPerformanceMonitoringScript() {
        let script = """
        // 收集性能指标
        if (window.performance) {
            setTimeout(function() {
                var perfData = {
                    navigationStart: window.performance.timing.navigationStart,
                    domComplete: window.performance.timing.domComplete,
                    loadEventEnd: window.performance.timing.loadEventEnd,
                    resources: []
                };
                
                // 收集资源加载信息
                var resources = window.performance.getEntriesByType('resource');
                resources.forEach(function(resource) {
                    perfData.resources.push({
                        name: resource.name,
                        duration: resource.duration,
                        size: resource.transferSize || 0
                    });
                });
                
                // 发送性能数据到原生代码
                window.webkit.messageHandlers.api.postMessage({
                    callbackID: 'performance_' + Date.now(),
                    params: {
                        action: 'reportPerformance',
                        data: perfData
                    }
                });
            }, 1000);
        }
        """
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                self.logger.error("❌ 注入性能监控脚本失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.info("📩 收到JavaScript消息: \(message.name)")
        
        if message.name == "api" {
            handleAPIMessage(message)
        } else if message.name == "pageLoaded" {
            handlePageLoadedMessage(message)
        } else if message.name == "logError" {
            handleJavaScriptLogError(message)
        }
    }
    
    private func handleAPIMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let callbackID = body["callbackID"] as? String,
              let params = body["params"] as? [String: Any] else {
            logger.error("❌ 无效的API消息格式")
            return
        }
        
        logger.info("🔄 处理API消息: \(callbackID)")
        
        // 检查是否是性能报告
        if callbackID.starts(with: "performance_"),
           let action = params["action"] as? String,
           action == "reportPerformance",
           let perfData = params["data"] as? [String: Any] {
            handlePerformanceReport(perfData)
            return
        }
        
        // 在这里处理API请求
        // ...
        
        // 模拟API响应
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let response = ["success": true, "data": ["message": "API请求成功"]]
            self.sendResponse(callbackID: callbackID, response: response)
        }
    }
    
    private func handlePerformanceReport(_ perfData: [String: Any]) {
        // 解析性能数据
        if let navigationStart = perfData["navigationStart"] as? Int,
           let domComplete = perfData["domComplete"] as? Int,
           let loadEventEnd = perfData["loadEventEnd"] as? Int,
           let resources = perfData["resources"] as? [[String: Any]] {
            
            let domCompleteTime = Double(domComplete - navigationStart) / 1000.0
            let loadEventTime = Double(loadEventEnd - navigationStart) / 1000.0
            
            logger.info("📊 页面性能指标 - DOM完成: \(String(format: "%.2f", domCompleteTime))秒, 加载完成: \(String(format: "%.2f", loadEventTime))秒")
            
            // 记录资源加载情况
            var totalSize = 0
            for resource in resources {
                if let size = resource["size"] as? Int {
                    totalSize += size
                }
            }
            
            logger.info("📊 资源加载 - 数量: \(resources.count), 总大小: \(String(format: "%.2f", Double(totalSize) / 1024.0))KB")
        }
    }
    
    private func handleJavaScriptLogError(_ message: WKScriptMessage) {
        guard let errorInfo = message.body as? [String: Any] else {
            logger.error("❌ 无效的JavaScript错误消息格式")
            return
        }
        
        // 记录JavaScript错误
        if let type = errorInfo["type"] as? String {
            if type == "console.error" {
                if let args = errorInfo["arguments"] as? String {
                    logger.error("🔴 JavaScript console.error: \(args)")
                    
                    // 检查是否是资源加载错误
                    if args.contains("加载失败") || args.contains("Failed to load") {
                        handleResourceLoadError()
                    }
                }
            } else if type == "unhandledrejection" {
                if let reason = errorInfo["reason"] as? String {
                    logger.error("🔴 JavaScript未处理的Promise错误: \(reason)")
                }
            } else if type == "performance" {
                if let data = errorInfo["data"] as? [String: Any] {
                    handlePerformanceData(data)
                }
            }
        } else {
            // 常规JavaScript错误
            let errorMessage = errorInfo["message"] as? String ?? "未知错误"
            let source = errorInfo["source"] as? String ?? "未知来源"
            let line = errorInfo["lineno"] as? Int ?? 0
            let column = errorInfo["colno"] as? Int ?? 0
            
            logger.error("🔴 JavaScript错误: \(errorMessage) at \(source):\(line):\(column)")
            
            if let stack = errorInfo["stack"] as? String {
                logger.error("🔍 JavaScript错误堆栈: \(stack)")
            }
            
            // 处理Script error
        }
    }
    
    private func handlePageLoadedMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let page = body["page"] as? String,
              let status = body["status"] as? String else {
            logger.error("❌ 无效的页面加载消息格式")
            return
        }
        
        logger.info("✅ 页面加载完成: \(page), 状态: \(status)")
    }
    
    private func sendResponse(callbackID: String, response: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let script = "window.handleNativeResponse('\(callbackID)', \(jsonString));"
                webView.evaluateJavaScript(script) { (result, error) in
                    if let error = error {
                        self.logger.error("❌ 发送响应失败: \(error.localizedDescription)")
                    } else {
                        self.logger.info("✅ 成功发送响应: \(callbackID)")
                    }
                }
            }
        } catch {
            logger.error("❌ JSON序列化失败: \(error.localizedDescription)")
        }
    }
    
    private func handleProcessTermination() {
        processTerminationCount += 1
        lastProcessTerminationTime = Date()
        
        let error = WebViewError.processTerminated("进程终止次数: \(processTerminationCount)")
        logger.error("❌ \(error.localizedDescription)")
        
        if processTerminationCount >= maxProcessTerminationRetries {
            logger.error("⛔️ 达到最大重试次数，显示错误信息")
            showError(message: "页面加载失败，请重新启动应用")
            return
        }
        
        // 设置恢复标志
        isRecoveringFromCrash = true
        
        // 延迟重新加载
        DispatchQueue.main.asyncAfter(deadline: .now() + processTerminationCooldown) { [weak self] in
            guard let self = self else { return }
            
            self.logger.info("🔄 尝试恢复WebView进程...")
            self.recreateWebView()
        }
    }
    
    // MARK: - 错误处理和JavaScript注入
    
    private func injectErrorCatchingScript() {
        let script = """
        // 全局错误处理
        window.onerror = function(message, source, lineno, colno, error) {
            window.webkit.messageHandlers.logError.postMessage({
                message: message,
                source: source,
                lineno: lineno,
                colno: colno,
                stack: error ? error.stack : null
            });
            return true;
        };
        
        // 增强console.error
        (function() {
            var originalConsoleError = console.error;
            console.error = function() {
                var args = Array.prototype.slice.call(arguments);
                window.webkit.messageHandlers.logError.postMessage({
                    type: 'console.error',
                    arguments: args.map(function(arg) { 
                        return String(arg);
                    }).join(' ')
                });
                originalConsoleError.apply(console, arguments);
            };
        })();
        
        // 捕获未处理的Promise错误
        window.addEventListener('unhandledrejection', function(event) {
            window.webkit.messageHandlers.logError.postMessage({
                type: 'unhandledrejection',
                reason: String(event.reason)
            });
        });
        
        // 增加性能监控
        window.addEventListener('load', function() {
            if (window.performance && window.performance.timing) {
                setTimeout(function() {
                    var timing = window.performance.timing;
                    var loadTime = timing.loadEventEnd - timing.navigationStart;
                    window.webkit.messageHandlers.logError.postMessage({
                        type: 'performance',
                        data: {
                            loadTime: loadTime,
                            domReadyTime: timing.domContentLoadedEventEnd - timing.navigationStart
                        }
                    });
                }, 0);
            }
        });
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
        
        logger.info("✅ 注入错误捕获脚本完成")
    }
    
    // MARK: - 资源加载错误处理
    
    private func handleResourceLoadError() {
        logger.warning("⚠️ 检测到资源加载错误，尝试重新加载")
        
        // 注入资源重试脚本
        let script = """
        // 重新加载所有样式表
        function reloadStylesheets() {
            var links = document.getElementsByTagName('link');
            for (var i = 0; i < links.length; i++) {
                if (links[i].rel === 'stylesheet') {
                    var href = links[i].href;
                    links[i].href = '';
                    setTimeout(function() {
                        links[i].href = href;
                    }, 10);
                }
            }
        }
        
        // 重新加载所有脚本
        function reloadScripts() {
            var scripts = document.getElementsByTagName('script');
            for (var i = 0; i < scripts.length; i++) {
                if (scripts[i].src) {
                    var src = scripts[i].src;
                    scripts[i].src = '';
                    setTimeout(function() {
                        scripts[i].src = src;
                    }, 10);
                }
            }
        }
        
        reloadStylesheets();
        reloadScripts();
        """
        
        webView.evaluateJavaScript(script) { [weak self] (result, error) in
            if let error = error {
                self?.logger.error("❌ 资源重新加载失败: \(error.localizedDescription)")
            } else {
                self?.logger.info("✅ 已触发资源重新加载")
            }
        }
    }
    
    // MARK: - 性能数据处理
    
    private func handlePerformanceData(_ data: [String: Any]) {
        if let loadTime = data["loadTime"] as? Double {
            let loadTimeSeconds = loadTime / 1000.0
            logger.info("📊 页面加载时间: \(String(format: "%.2f", loadTimeSeconds))秒")
        }
        
        if let domReadyTime = data["domReadyTime"] as? Double {
            let domReadySeconds = domReadyTime / 1000.0
            logger.info("📊 DOM准备时间: \(String(format: "%.2f", domReadySeconds))秒")
            
            // 如果DOM加载时间过长，记录警告
            if domReadySeconds > 3.0 {
                logger.warning("⚠️ DOM加载时间过长: \(String(format: "%.2f", domReadySeconds))秒")
            }
        }
        
        // 记录到性能监控系统
        let performanceMetrics: [String: Double] = [
            "loadTime": (data["loadTime"] as? Double) ?? 0.0,
            "domReadyTime": (data["domReadyTime"] as? Double) ?? 0.0,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 可以在这里添加性能数据上报逻辑
        logger.info("📊 性能指标: \(performanceMetrics)")
    }
    
    // MARK: - 内存管理
    
    deinit {
        // 清理资源
        networkMonitor?.cancel()
        NotificationCenter.default.removeObserver(self)
        
        // 清理WebView
        webView.stopLoading()
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "api")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "pageLoaded")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "logError")
        
        // 清理WebKit缓存
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { }
        
        logger.info("🧹 HomeViewController已释放")
    }
} 