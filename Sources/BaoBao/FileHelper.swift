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
        
        // 尝试在Bundle的上级目录中查找
        let parentURL = bundleURL.deletingLastPathComponent()
        let potentialParentURL = parentURL.appendingPathComponent("baobao_prototype")
        
        if FileManager.default.fileExists(atPath: potentialParentURL.path) {
            logger.info("✅ 在Bundle的上级目录中找到baobao_prototype目录: \(potentialParentURL.path)")
            return potentialParentURL
        }
        
        // 列出Bundle中的所有资源
        if let resourcePaths = Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil) as [String]? {
            logger.info("📂 Bundle中的资源列表 (\(resourcePaths.count) 个):")
            for path in resourcePaths.prefix(20) {
                logger.info("- \(path)")
            }
            if resourcePaths.count > 20 {
                logger.info("... 还有 \(resourcePaths.count - 20) 个资源未显示")
            }
        }
        
        // 尝试查找包含 "baobao_prototype" 的资源
        if let resourcePaths = Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil) as [String]? {
            for path in resourcePaths {
                if path.contains("baobao_prototype") {
                    logger.info("✅ 找到包含 baobao_prototype 的资源: \(path)")
                    return URL(fileURLWithPath: path)
                }
            }
        }
        
        return nil
    }
    
    /// 获取文档目录中baobao_prototype目录的URL
    static var documentsPrototypeURL: URL {
        documentsDirectory.appendingPathComponent("baobao_prototype")
    }
    
    /// 复制baobao_prototype目录到文档目录
    static func copyBaoBaoPrototypeToDocuments() {
        // 检查Bundle中是否存在baobao_prototype目录
        if let bundleURL = bundlePrototypeURL {
            let fileManager = FileManager.default
            let destinationURL = documentsPrototypeURL
            
            do {
                // 如果目标目录已存在，先删除
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                    logger.info("🗑️ 已删除旧的baobao_prototype目录")
                }
                
                // 复制目录
                try fileManager.copyItem(at: bundleURL, to: destinationURL)
                logger.info("✅ 成功复制baobao_prototype目录到文档目录")
                
                // 列出复制的文件
                logDirectoryContents(at: destinationURL)
                
            } catch {
                logger.error("❌ 复制baobao_prototype目录失败: \(error.localizedDescription)")
                // 如果复制失败，创建测试资源
                createTestResources()
            }
        } else {
            logger.error("❌ 无法在Bundle中找到baobao_prototype目录")
            // 如果目录不存在，创建测试资源
            createTestResources()
        }
    }
    
    /// 创建测试资源
    static func createTestResources() {
        logger.info("🔨 开始创建测试资源")
        let fileManager = FileManager.default
        
        // 创建baobao_prototype目录结构
        let prototypeURL = documentsPrototypeURL
        let pagesURL = prototypeURL.appendingPathComponent("pages")
        let cssURL = prototypeURL.appendingPathComponent("css")
        let jsURL = prototypeURL.appendingPathComponent("js")
        let imgURL = prototypeURL.appendingPathComponent("img")
        
        do {
            // 创建目录结构
            try fileManager.createDirectory(at: prototypeURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: pagesURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: cssURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: jsURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: imgURL, withIntermediateDirectories: true)
            
            // 创建首页
            createHomePage(at: pagesURL.appendingPathComponent("home.html"))
            
            // 创建CSS文件
            createStyleSheet(at: cssURL.appendingPathComponent("style.css"))
            
            // 创建JS文件
            createJavaScript(at: jsURL.appendingPathComponent("main.js"))
            
            logger.info("✅ 测试资源创建成功")
        } catch {
            logger.error("❌ 创建测试资源失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建测试HTML文件
    static func createTestHtmlInDocuments() -> URL {
        let testHtmlURL = documentsDirectory.appendingPathComponent("test.html")
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>测试页面</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #f5f5f7;
                    color: #1d1d1f;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    background-color: white;
                    padding: 30px;
                    border-radius: 12px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                h1 {
                    color: #1d1d1f;
                    font-size: 24px;
                    margin-bottom: 16px;
                }
                p {
                    color: #424245;
                    line-height: 1.5;
                    margin-bottom: 12px;
                }
                .success {
                    color: #00b300;
                    font-weight: 500;
                }
                .time {
                    color: #86868b;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>WebView 测试页面</h1>
                <p class="success">✅ WebView 配置成功！</p>
                <p>页面加载时间：<span class="time" id="loadTime"></span></p>
                <script>
                    document.getElementById('loadTime').textContent = new Date().toLocaleString();
                </script>
            </div>
        </body>
        </html>
        """
        
        do {
            try htmlContent.write(to: testHtmlURL, atomically: true, encoding: .utf8)
            logger.info("✅ 成功创建测试HTML文件")
            return testHtmlURL
        } catch {
            logger.error("❌ 创建测试HTML文件失败: \(error.localizedDescription)")
            return testHtmlURL
        }
    }
    
    /// 创建首页
    private static func createHomePage(at url: URL) {
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>宝宝故事</title>
            <link rel="stylesheet" href="../css/style.css">
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>宝宝故事</h1>
                    <p>为您的宝宝创建个性化的故事</p>
                </header>
                
                <section class="story-cards">
                    <h2>最近的故事</h2>
                    <div class="card-container">
                        <div class="card">
                            <div class="card-title">太空冒险</div>
                            <div class="card-content">小明踏上了一段奇妙的太空之旅...</div>
                            <button class="play-button">播放</button>
                        </div>
                        
                        <div class="card">
                            <div class="card-title">海底世界</div>
                            <div class="card-content">小红探索神秘的海底王国...</div>
                            <button class="play-button">播放</button>
                        </div>
                    </div>
                    
                    <button class="create-button">创建新故事</button>
                </section>
            </div>
            
            <script src="../js/main.js"></script>
        </body>
        </html>
        """
        
        do {
            try htmlContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 成功创建首页")
        } catch {
            logger.error("❌ 创建首页失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建样式表
    private static func createStyleSheet(at url: URL) {
        let cssContent = """
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f7;
            color: #1d1d1f;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        
        header {
            text-align: center;
            margin-bottom: 30px;
        }
        
        h1 {
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        h2 {
            font-size: 24px;
            margin-bottom: 20px;
        }
        
        .story-cards {
            background-color: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .card-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .card {
            flex: 1;
            min-width: 200px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 15px;
            background-color: #f9f9f9;
        }
        
        .card-title {
            font-weight: bold;
            font-size: 18px;
            margin-bottom: 10px;
        }
        
        .card-content {
            font-size: 14px;
            color: #666;
            margin-bottom: 15px;
        }
        
        .play-button {
            background-color: #007aff;
            color: white;
            border: none;
            border-radius: 4px;
            padding: 8px 12px;
            cursor: pointer;
        }
        
        .create-button {
            display: block;
            width: 100%;
            background-color: #34c759;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px;
            font-size: 16px;
            cursor: pointer;
        }
        """
        
        do {
            try cssContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 成功创建样式表")
        } catch {
            logger.error("❌ 创建样式表失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建JavaScript文件
    private static func createJavaScript(at url: URL) {
        let jsContent = """
        document.addEventListener('DOMContentLoaded', function() {
            // 播放按钮点击事件
            const playButtons = document.querySelectorAll('.play-button');
            playButtons.forEach(button => {
                button.addEventListener('click', function() {
                    const card = this.closest('.card');
                    const title = card.querySelector('.card-title').textContent;
                    alert('正在播放: ' + title);
                });
            });
            
            // 创建新故事按钮点击事件
            const createButton = document.querySelector('.create-button');
            if (createButton) {
                createButton.addEventListener('click', function() {
                    alert('即将创建新故事...');
                });
            }
            
            console.log('页面初始化完成');
        });
        """
        
        do {
            try jsContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("✅ 成功创建JavaScript文件")
        } catch {
            logger.error("❌ 创建JavaScript文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 列出指定目录的内容
    private static func logDirectoryContents(at url: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            logger.info("📄 目录内容 (\(url.lastPathComponent)):")
            contents.forEach { fileURL in
                logger.info("- \(fileURL.lastPathComponent)")
            }
        } catch {
            logger.error("❌ 无法列出目录内容: \(error.localizedDescription)")
        }
    }
    
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    static func listFilesInDirectory(directoryPath: String) -> [String] {
        let fileManager = FileManager.default
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(atPath: directoryPath)
            return fileURLs
        } catch {
            print("列出目录内容失败: \(error.localizedDescription)")
            return []
        }
    }
} 