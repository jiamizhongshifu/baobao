import UIKit
import WebKit
import os.log

class HomeViewController: UIViewController {
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "home-view")
    
    // MARK: - UI Components
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 添加输入系统相关配置
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        configuration.preferences = preferences
        
        // 禁用文本建议以避免RTIInputSystemClient警告
        let dataStore = WKWebsiteDataStore.nonPersistent()
        configuration.websiteDataStore = dataStore
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // 优化输入处理
        webView.allowsBackForwardNavigationGestures = true
        webView.configuration.userContentController.add(self, name: "inputHandler")
        
        return webView
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadHomePage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logger.info("HomeViewController - viewWillAppear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logger.info("HomeViewController - viewDidAppear")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 添加WebView
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 添加加载指示器
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "宝宝故事"
        
        // 添加刷新按钮（用于测试）
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshButtonTapped)
        )
        
        // 添加切换按钮（用于测试）
        let switchButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.triangle.2.circlepath"),
            style: .plain,
            target: self,
            action: #selector(switchButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [refreshButton, switchButton]
    }
    
    // MARK: - Page Loading
    private func loadHomePage() {
        loadingIndicator.startAnimating()
        
        // 首先尝试加载文档目录中的home.html
        let documentsURL = FileHelper.documentsPrototypeURL.appendingPathComponent("pages/home.html")
        
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            logger.info("📄 从文档目录加载home.html")
            logger.info("📄 文件路径: \(documentsURL.path)")
            
            // 检查文件内容
            do {
                let content = try String(contentsOf: documentsURL, encoding: .utf8)
                logger.info("📄 文件内容长度: \(content.count) 字符")
                logger.info("📄 文件内容前100字符: \(content.prefix(100))")
            } catch {
                logger.error("❌ 读取文件内容失败: \(error.localizedDescription)")
            }
            
            webView.loadFileURL(documentsURL, allowingReadAccessTo: FileHelper.documentsDirectory)
            return
        }
        
        // 如果home.html不存在，尝试加载测试页面
        logger.info("⚠️ home.html不存在，加载测试页面")
        let testHtmlURL = FileHelper.createTestHtmlInDocuments()
        webView.loadFileURL(testHtmlURL, allowingReadAccessTo: FileHelper.documentsDirectory)
    }
    
    // 加载自定义页面
    private func loadCustomPage() {
        loadingIndicator.startAnimating()
        
        // 创建自定义HTML内容
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>宝宝故事 - 自定义页面</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #f0f0f5;
                    color: #333;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                    background-color: white;
                    border-radius: 12px;
                    padding: 30px;
                    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                }
                header {
                    text-align: center;
                    margin-bottom: 30px;
                }
                h1 {
                    color: #007aff;
                    font-size: 28px;
                    margin-bottom: 10px;
                }
                .story-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                    gap: 20px;
                    margin-bottom: 30px;
                }
                .story-card {
                    border: 1px solid #e0e0e0;
                    border-radius: 8px;
                    overflow: hidden;
                    transition: transform 0.3s, box-shadow 0.3s;
                }
                .story-card:hover {
                    transform: translateY(-5px);
                    box-shadow: 0 10px 20px rgba(0,0,0,0.1);
                }
                .story-image {
                    height: 120px;
                    background-color: #f5f5f7;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    color: #999;
                    font-size: 40px;
                }
                .story-content {
                    padding: 15px;
                }
                .story-title {
                    font-weight: bold;
                    font-size: 16px;
                    margin-bottom: 5px;
                }
                .story-desc {
                    font-size: 14px;
                    color: #666;
                    margin-bottom: 10px;
                }
                .story-button {
                    background-color: #007aff;
                    color: white;
                    border: none;
                    border-radius: 4px;
                    padding: 6px 12px;
                    font-size: 14px;
                    cursor: pointer;
                    width: 100%;
                }
                .create-button {
                    display: block;
                    width: 100%;
                    background-color: #34c759;
                    color: white;
                    border: none;
                    border-radius: 8px;
                    padding: 15px;
                    font-size: 16px;
                    font-weight: bold;
                    cursor: pointer;
                    transition: background-color 0.3s;
                }
                .create-button:hover {
                    background-color: #2eb350;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>宝宝故事</h1>
                    <p>为您的宝宝创建个性化的故事体验</p>
                </header>
                
                <h2>最近的故事</h2>
                <div class="story-grid">
                    <div class="story-card">
                        <div class="story-image">🚀</div>
                        <div class="story-content">
                            <div class="story-title">太空冒险</div>
                            <div class="story-desc">小明踏上了一段奇妙的太空之旅...</div>
                            <button class="story-button" onclick="alert('正在播放: 太空冒险')">播放</button>
                        </div>
                    </div>
                    
                    <div class="story-card">
                        <div class="story-image">🌊</div>
                        <div class="story-content">
                            <div class="story-title">海底世界</div>
                            <div class="story-desc">小红探索神秘的海底王国...</div>
                            <button class="story-button" onclick="alert('正在播放: 海底世界')">播放</button>
                        </div>
                    </div>
                    
                    <div class="story-card">
                        <div class="story-image">🏰</div>
                        <div class="story-content">
                            <div class="story-title">魔法城堡</div>
                            <div class="story-desc">勇敢的小骑士前往魔法城堡...</div>
                            <button class="story-button" onclick="alert('正在播放: 魔法城堡')">播放</button>
                        </div>
                    </div>
                    
                    <div class="story-card">
                        <div class="story-image">🌳</div>
                        <div class="story-content">
                            <div class="story-title">森林探险</div>
                            <div class="story-desc">小动物们在森林中展开了一场冒险...</div>
                            <button class="story-button" onclick="alert('正在播放: 森林探险')">播放</button>
                        </div>
                    </div>
                </div>
                
                <button class="create-button" onclick="alert('即将创建新故事...')">创建新故事</button>
            </div>
            
            <script>
                console.log('自定义页面加载完成');
                document.addEventListener('DOMContentLoaded', function() {
                    console.log('DOM内容加载完成');
                });
            </script>
        </body>
        </html>
        """
        
        // 将HTML内容写入临时文件
        let tempURL = FileHelper.documentsDirectory.appendingPathComponent("custom.html")
        do {
            try htmlContent.write(to: tempURL, atomically: true, encoding: .utf8)
            logger.info("✅ 成功创建自定义页面")
            webView.loadFileURL(tempURL, allowingReadAccessTo: FileHelper.documentsDirectory)
        } catch {
            logger.error("❌ 创建自定义页面失败: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }
    
    // MARK: - Actions
    @objc private func refreshButtonTapped() {
        logger.info("🔄 刷新按钮点击")
        loadHomePage()
    }
    
    @objc private func switchButtonTapped() {
        logger.info("🔄 切换按钮点击")
        loadCustomPage()
    }
    
    // MARK: - Error Handling
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "加载失败",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "重试",
            style: .default,
            handler: { [weak self] _ in
                self?.loadHomePage()
            }
        ))
        
        alert.addAction(UIAlertAction(
            title: "确定",
            style: .cancel
        ))
        
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate
extension HomeViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
        logger.info("✅ 页面加载完成")
        
        // 注入处理输入相关的JavaScript
        let inputScript = """
            document.addEventListener('focusin', function(e) {
                if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                    window.webkit.messageHandlers.inputHandler.postMessage({
                        type: 'focus',
                        id: e.target.id
                    });
                }
            });
        """
        
        webView.evaluateJavaScript(inputScript) { (result, error) in
            if let error = error {
                self.logger.error("❌ 注入输入处理脚本失败: \(error.localizedDescription)")
            }
        }
        
        // 执行JavaScript获取页面标题
        webView.evaluateJavaScript("document.title") { (result, error) in
            if let title = result as? String {
                self.logger.info("📄 页面标题: \(title)")
            }
            if let error = error {
                self.logger.error("❌ 获取页面标题失败: \(error.localizedDescription)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        logger.error("❌ 页面加载失败: \(error.localizedDescription)")
        showError(error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        logger.error("❌ 页面加载失败（初始化阶段）: \(error.localizedDescription)")
        showError(error.localizedDescription)
    }
}

// MARK: - WKUIDelegate
extension HomeViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// 添加WKScriptMessageHandler扩展
extension HomeViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // 处理来自网页的消息
        if message.name == "inputHandler" {
            logger.info("📝 收到网页输入消息: \(message.body)")
        }
    }
} 