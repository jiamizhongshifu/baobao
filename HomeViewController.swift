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
        
        // 获取HTML文件路径
        guard let fileHelper = try? FileHelper() else {
            showError(message: "无法初始化文件助手")
            return
        }
        
        do {
            logger.info("📄 从文档目录加载home.html")
            let htmlPath = try fileHelper.getFilePathInDocuments(fileName: "baobao_prototype/pages/home.html")
            let htmlURL = URL(fileURLWithPath: htmlPath)
            
            // 读取文件内容
            let htmlContent = try String(contentsOf: htmlURL, encoding: .utf8)
            logger.info("📄 文件内容长度: \(htmlContent.count) 字符")
            logger.info("📄 文件内容前100字符: \(String(htmlContent.prefix(100)))")
            
            // 获取基础URL
            let baseURL = htmlURL.deletingLastPathComponent()
            
            // 加载HTML
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
        } catch {
            logger.error("❌ 加载HTML文件失败: \(error.localizedDescription)")
            showError(message: "加载页面失败: \(error.localizedDescription)")
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
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("✅ 页面加载完成")
        logger.info("📄 页面标题: \(webView.title ?? "无标题")")
        
        // 延迟显示WebView，确保内容已完全渲染
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
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
} 