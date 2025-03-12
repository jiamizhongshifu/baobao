import UIKit
import WebKit
import os.log
import Network
// 导入API服务
import Foundation

class HomeViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    private var webView: WKWebView!
    private let logger = Logger(subsystem: "com.example.baobao", category: "HomeViewController")
    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable = true
    private var loadingView: UIView?
    private var retryButton: UIButton?
    private var loadingIndicator: UIActivityIndicatorView?
    private var errorLabel: UILabel?
    private var navigationStartTime: TimeInterval?
    private var resourceCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("🚀 HomeViewController - viewDidLoad")
        
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logger.info("HomeViewController - viewDidAppear")
    }
    
    // MARK: - 设置UI
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // 配置WebView
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // 注册消息处理器
        userContentController.add(self, name: "log")
        userContentController.add(self, name: "pageLoaded")
        
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptEnabled = true
        
        // 创建WebView
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isHidden = true // 初始隐藏WebView，直到加载完成
        view.addSubview(webView)
        
        // 注册API控制器的消息处理器
        APIController.shared.registerMessageHandlers(for: webView)
        
        // 创建加载视图
        setupLoadingView()
    }
    
    // MARK: - 设置加载视图
    
    private func setupLoadingView() {
        loadingView = UIView(frame: view.bounds)
        loadingView?.backgroundColor = .white
        loadingView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 创建加载指示器
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator?.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY - 50)
        loadingIndicator?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        loadingIndicator?.startAnimating()
        
        // 创建加载标签
        let loadingLabel = UILabel()
        loadingLabel.text = "正在加载宝宝故事..."
        loadingLabel.textAlignment = .center
        loadingLabel.textColor = .darkGray
        loadingLabel.font = UIFont.systemFont(ofSize: 16)
        loadingLabel.frame = CGRect(x: 0, y: view.bounds.midY, width: view.bounds.width, height: 30)
        loadingLabel.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        
        // 创建错误标签（初始隐藏）
        errorLabel = UILabel()
        errorLabel?.text = "加载失败，请检查网络连接"
        errorLabel?.textAlignment = .center
        errorLabel?.textColor = .red
        errorLabel?.font = UIFont.systemFont(ofSize: 16)
        errorLabel?.frame = CGRect(x: 0, y: view.bounds.midY + 40, width: view.bounds.width, height: 30)
        errorLabel?.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        errorLabel?.isHidden = true
        
        // 创建重试按钮（初始隐藏）
        retryButton = UIButton(type: .system)
        retryButton?.setTitle("重试", for: .normal)
        retryButton?.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        retryButton?.backgroundColor = UIColor(red: 0, green: 122/255, blue: 1, alpha: 1)
        retryButton?.setTitleColor(.white, for: .normal)
        retryButton?.layer.cornerRadius = 20
        retryButton?.frame = CGRect(x: view.bounds.midX - 50, y: view.bounds.midY + 80, width: 100, height: 40)
        retryButton?.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        retryButton?.addTarget(self, action: #selector(retryLoading), for: .touchUpInside)
        retryButton?.isHidden = true
        
        // 添加到加载视图
        loadingView?.addSubview(loadingIndicator!)
        loadingView?.addSubview(loadingLabel)
        loadingView?.addSubview(errorLabel!)
        loadingView?.addSubview(retryButton!)
        
        // 添加到主视图
        view.addSubview(loadingView!)
    }
    
    // MARK: - 网络监控
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let isAvailable = path.status == .satisfied
                if self?.isNetworkAvailable != isAvailable {
                    self?.isNetworkAvailable = isAvailable
                    if isAvailable {
                        self?.logger.info("📶 网络连接恢复")
                        // 如果WebView加载失败，尝试重新加载
                        if self?.webView.isHidden == true {
                            self?.retryLoading()
                        }
                    } else {
                        self?.logger.warning("📵 网络连接断开")
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor?.start(queue: queue)
    }
    
    // MARK: - WebView加载
    
    private func loadWebView() {
        // 显示加载视图
        loadingView?.isHidden = false
        loadingIndicator?.startAnimating()
        errorLabel?.isHidden = true
        retryButton?.isHidden = true
        
        logger.info("📱 加载WebView开始")
        
        // 获取HTML文件路径
        logger.info("🔍 获取HTML文件路径")
        
        // 直接从文档目录获取HTML文件路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let htmlPath = documentsPath.appendingPathComponent("baobao_prototype/pages/test.html")
        
        if FileManager.default.fileExists(atPath: htmlPath.path) {
            logger.info("✅ 在文档目录中找到测试HTML文件: \(htmlPath.path)")
            
            // 获取基础URL（用于相对路径解析）
            let baseURL = htmlPath.deletingLastPathComponent().deletingLastPathComponent()
            logger.info("📂 基础目录: \(baseURL)")
            
            // 读取文件内容进行检查
            do {
                let htmlContent = try String(contentsOf: htmlPath, encoding: .utf8)
                logger.info("📄 HTML文件内容长度: \(htmlContent.count) 字符")
                logger.info("📄 HTML文件内容前100字符: \(String(htmlContent.prefix(100)))")
                
                // 注入调试脚本
                let debugScript = WKUserScript(
                    source: """
                    console.originalLog = console.log;
                    console.log = function(message) {
                        console.originalLog(message);
                        try {
                            window.webkit.messageHandlers.log.postMessage({
                                level: 'info',
                                message: message
                            });
                        } catch(e) {}
                    };
                    
                    console.originalError = console.error;
                    console.error = function(message) {
                        console.originalError(message);
                        try {
                            window.webkit.messageHandlers.log.postMessage({
                                level: 'error',
                                message: message
                            });
                        } catch(e) {}
                    };
                    
                    window.onerror = function(message, source, lineno, colno, error) {
                        try {
                            window.webkit.messageHandlers.logError.postMessage({
                                message: message,
                                source: source,
                                lineno: lineno,
                                colno: colno,
                                stack: error ? error.stack : 'No stack trace'
                            });
                        } catch(e) {}
                        return false;
                    };
                    """,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
                
                webView.configuration.userContentController.addUserScript(debugScript)
                logger.info("✅ 注入错误捕获脚本完成")
                
                // 加载HTML文件
                logger.info("📄 加载本地文件: \(htmlPath)")
                webView.loadFileURL(htmlPath, allowingReadAccessTo: baseURL)
            } catch {
                logger.error("❌ 读取HTML文件内容失败: \(error.localizedDescription)")
                showError(message: "无法读取HTML文件内容")
            }
        } else {
            logger.error("❌ 在文档目录中未找到测试HTML文件，尝试加载home.html")
            
            // 尝试加载home.html
            let homeHtmlPath = documentsPath.appendingPathComponent("baobao_prototype/pages/home.html")
            
            if FileManager.default.fileExists(atPath: homeHtmlPath.path) {
                logger.info("✅ 在文档目录中找到home.html文件: \(homeHtmlPath.path)")
                let baseURL = homeHtmlPath.deletingLastPathComponent().deletingLastPathComponent()
                webView.loadFileURL(homeHtmlPath, allowingReadAccessTo: baseURL)
            } else {
                logger.error("❌ 在文档目录中也未找到home.html文件")
                
                // 创建一个简单的HTML内容
                let simpleHTML = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>宝宝故事</title>
                    <style>
                        body { font-family: -apple-system, sans-serif; margin: 20px; color: #333; background-color: #F2E9DE; }
                        h1 { color: #000; }
                        .card { background: #fff; border-radius: 10px; padding: 20px; margin: 20px 0; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                        button { background: #000; color: #fff; border: none; padding: 10px 20px; border-radius: 5px; font-size: 16px; }
                    </style>
                </head>
                <body>
                    <h1>宝宝故事</h1>
                    <div class="card">
                        <h2>资源加载错误</h2>
                        <p>无法找到必要的HTML文件。请确保应用安装正确。</p>
                        <button onclick="location.reload()">刷新页面</button>
                    </div>
                    <script>
                        // 通知原生代码页面已加载
                        try {
                            window.webkit.messageHandlers.pageLoaded.postMessage({
                                page: 'error',
                                status: 'error'
                            });
                        } catch (e) {
                            console.log('无法通知原生代码页面已加载');
                        }
                    </script>
                </body>
                </html>
                """
                
                logger.info("📄 加载简单HTML内容")
                webView.loadHTMLString(simpleHTML, baseURL: nil)
            }
        }
    }
    
    @objc private func retryLoading() {
        logger.info("🔄 重试加载WebView")
        loadWebView()
    }
    
    private func showError(message: String) {
        logger.error("❌ 错误: \(message)")
        
        // 更新UI显示错误
        loadingIndicator?.stopAnimating()
        errorLabel?.text = message
        errorLabel?.isHidden = false
        retryButton?.isHidden = false
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
        let loadTime = Date().timeIntervalSince1970 - (navigationStartTime ?? Date().timeIntervalSince1970)
        logger.info("✅ WebView加载完成，耗时: \(String(format: "%.2f", loadTime))秒，加载资源数: \(resourceCount)")
        
        // 执行JavaScript获取页面标题
        webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
            if let title = result as? String {
                self?.logger.info("📄 页面标题: \(title)")
            }
        }
        
        // 执行JavaScript检查页面内容
        webView.evaluateJavaScript("document.body.innerHTML.length") { [weak self] (result, error) in
            if let length = result as? Int {
                self?.logger.info("📄 页面内容长度: \(length) 字符")
            }
        }
        
        // 检查CSS是否加载
        webView.evaluateJavaScript("document.styleSheets.length") { [weak self] (result, error) in
            if let count = result as? Int {
                self?.logger.info("📄 加载的样式表数量: \(count)")
            }
        }
        
        // 检查JS是否加载
        webView.evaluateJavaScript("document.scripts.length") { [weak self] (result, error) in
            if let count = result as? Int {
                self?.logger.info("📄 加载的脚本数量: \(count)")
            }
        }
        
        // 延迟显示WebView，确保内容已完全渲染
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.webView.isHidden = false
            self?.loadingView?.isHidden = true
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("❌ 页面加载失败: \(error.localizedDescription)")
        showError(message: "页面加载失败，请重试")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("❌ 页面预加载失败: \(error.localizedDescription)")
        showError(message: "页面加载失败，请检查网络连接")
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // 处理来自WebView的消息
        switch message.name {
        case "log":
            if let body = message.body as? [String: Any],
               let logMessage = body["message"] as? String,
               let level = body["level"] as? String {
                let logPrefix = "📱 WebView日志"
                switch level {
                case "error":
                    logger.error("\(logPrefix) [ERROR]: \(logMessage)")
                case "warn":
                    logger.warning("\(logPrefix) [WARN]: \(logMessage)")
                case "debug":
                    logger.debug("\(logPrefix) [DEBUG]: \(logMessage)")
                default:
                    logger.info("\(logPrefix) [INFO]: \(logMessage)")
                }
            }
        case "pageLoaded":
            logger.info("📥 收到WebView消息: pageLoaded")
            // 页面加载完成，可以执行其他操作
        default:
            logger.info("📥 收到WebView消息: \(message.name)")
        }
    }
    
    // MARK: - 内存管理
    
    deinit {
        // 停止网络监控
        networkMonitor?.cancel()
        
        // 移除消息处理器
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "log")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "pageLoaded")
        
        logger.info("🧹 HomeViewController 已释放")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 接受所有证书，简化开发过程
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            logger.info("🔗 WebView导航请求: \(url)")
            navigationStartTime = Date().timeIntervalSince1970
            resourceCount = 0
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            logger.info("📥 WebView响应: \(response.statusCode)")
        }
        resourceCount += 1
        decisionHandler(.allow)
    }
} 