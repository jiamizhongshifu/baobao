import Foundation
import os.log
import WebKit

// 确保导入所有必要的自定义类型
// 这些import语句会在编译时被解析
// 项目有正确的组织结构时不需要这些导入
// @_exported import StoryModels
// @_exported import DataServices
// @_exported import SpeechServices

// MARK: - API控制器
class APIController: NSObject {
    // 单例模式
    static let shared = APIController()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "api-controller")
    
    // 服务
    private let storyService = StoryService.shared
    private let speechService = SpeechService.shared
    private let dataService = DataService.shared
    
    // 私有初始化方法
    private override init() {
        super.init()
        logger.info("API控制器初始化完成")
    }
    
    // MARK: - 注册WebView消息处理
    func registerMessageHandlers(for webView: WKWebView) {
        // 清理之前的消息处理器
        let userContentController = webView.configuration.userContentController
        
        // 添加API消息处理器
        userContentController.add(self, name: "generateStory")
        userContentController.add(self, name: "synthesizeSpeech")
        userContentController.add(self, name: "playAudio")
        userContentController.add(self, name: "stopAudio")
        userContentController.add(self, name: "saveStory")
        userContentController.add(self, name: "getStories")
        userContentController.add(self, name: "getStoryDetail")
        userContentController.add(self, name: "deleteStory")
        userContentController.add(self, name: "saveChild")
        userContentController.add(self, name: "getChildren")
        userContentController.add(self, name: "deleteChild")
        
        logger.info("✅ 注册WebView消息处理器完成")
    }
    
    // MARK: - 辅助方法
    
    // 解析JSON数据
    private func parseJSON<T: Decodable>(_ json: Any, as type: T.Type) -> T? {
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("❌ JSON解析失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 发送响应到WebView
    private func sendResponse(to webView: WKWebView, callbackID: String, data: Any?, error: Error? = nil) {
        // 构建响应
        var response: [String: Any] = ["callbackID": callbackID]
        
        if let error = error {
            response["success"] = false
            response["error"] = error.localizedDescription
        } else {
            response["success"] = true
            if let data = data {
                response["data"] = data
            }
        }
        
        // 序列化响应
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                // 发送响应到WebView
                let js = "window.handleNativeResponse(\(jsonString))"
                webView.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        self.logger.error("❌ 发送响应失败: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            logger.error("❌ 响应序列化失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - WKScriptMessageHandler
extension APIController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else {
            logger.error("❌ 无法获取WebView实例")
            return
        }
        
        logger.info("📥 收到WebView消息: \(message.name)")
        
        // 解析消息体
        guard let body = message.body as? [String: Any],
              let callbackID = body["callbackID"] as? String else {
            logger.error("❌ 无效的消息体格式")
            return
        }
        
        // 根据消息名称处理请求
        switch message.name {
        case "generateStory":
            handleGenerateStory(webView: webView, body: body, callbackID: callbackID)
            
        case "synthesizeSpeech":
            handleSynthesizeSpeech(webView: webView, body: body, callbackID: callbackID)
            
        case "playAudio":
            handlePlayAudio(webView: webView, body: body, callbackID: callbackID)
            
        case "stopAudio":
            handleStopAudio(webView: webView, body: body, callbackID: callbackID)
            
        case "saveStory":
            handleSaveStory(webView: webView, body: body, callbackID: callbackID)
            
        case "getStories":
            handleGetStories(webView: webView, body: body, callbackID: callbackID)
            
        case "getStoryDetail":
            handleGetStoryDetail(webView: webView, body: body, callbackID: callbackID)
            
        case "deleteStory":
            handleDeleteStory(webView: webView, body: body, callbackID: callbackID)
            
        case "saveChild":
            handleSaveChild(webView: webView, body: body, callbackID: callbackID)
            
        case "getChildren":
            handleGetChildren(webView: webView, body: body, callbackID: callbackID)
            
        case "deleteChild":
            handleDeleteChild(webView: webView, body: body, callbackID: callbackID)
            
        default:
            logger.warning("⚠️ 未知的消息名称: \(message.name)")
            let error = NSError(domain: "com.baobao.app", code: 404, userInfo: [NSLocalizedDescriptionKey: "未知的API请求"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
        }
    }
    
    // MARK: - 消息处理方法
    
    // 处理生成故事请求
    private func handleGenerateStory(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let themeString = params["theme"] as? String,
              let childName = params["childName"] as? String,
              let childAge = params["childAge"] as? Int,
              let lengthString = params["length"] as? String else {
            logger.error("❌ 生成故事参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 解析主题
        guard let theme = StoryTheme.allCases.first(where: { $0.rawValue == themeString }) else {
            logger.error("❌ 无效的故事主题: \(themeString)")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的故事主题"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 解析长度
        guard let length = StoryLength.allCases.first(where: { $0.rawValue == lengthString }) else {
            logger.error("❌ 无效的故事长度: \(lengthString)")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的故事长度"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 获取兴趣爱好（可选）
        let childInterests = params["childInterests"] as? [String] ?? []
        
        // 生成故事
        storyService.generateStory(
            theme: theme,
            childName: childName,
            childAge: childAge,
            childInterests: childInterests,
            length: length
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let story):
                // 转换为字典
                var storyDict: [String: Any] = [
                    "id": story.id,
                    "title": story.title,
                    "content": story.content,
                    "theme": story.theme,
                    "childName": story.childName,
                    "createdAt": ISO8601DateFormatter().string(from: story.createdAt)
                ]
                
                if let audioURL = story.audioURL {
                    storyDict["audioURL"] = audioURL
                }
                
                // 发送响应
                self.sendResponse(to: webView, callbackID: callbackID, data: storyDict)
                
            case .failure(let error):
                self.sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            }
        }
    }
    
    // 处理语音合成请求
    private func handleSynthesizeSpeech(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let text = params["text"] as? String,
              let voiceTypeString = params["voiceType"] as? String else {
            logger.error("❌ 语音合成参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 解析语音类型
        guard let voiceType = VoiceType.allCases.first(where: { $0.rawValue == voiceTypeString }) else {
            logger.error("❌ 无效的语音类型: \(voiceTypeString)")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的语音类型"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 合成语音
        speechService.synthesizeSpeech(text: text, voiceType: voiceType) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let url):
                // 发送响应
                self.sendResponse(to: webView, callbackID: callbackID, data: ["audioURL": url.absoluteString])
                
            case .failure(let error):
                self.sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            }
        }
    }
    
    // 处理播放音频请求
    private func handlePlayAudio(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let audioURLString = params["audioURL"] as? String,
              let audioURL = URL(string: audioURLString) else {
            logger.error("❌ 播放音频参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 播放音频
        speechService.playAudio(from: audioURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.sendResponse(to: webView, callbackID: callbackID, data: ["success": true])
            case .failure(let error):
                let nsError = error as NSError
                self.sendResponse(to: webView, callbackID: callbackID, data: nil, error: nsError)
            }
        }
    }
    
    // 处理停止音频请求
    private func handleStopAudio(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 停止音频
        speechService.stopAudio()
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["success": true])
    }
    
    // 处理保存故事请求
    private func handleSaveStory(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let storyDict = params["story"] as? [String: Any],
              let title = storyDict["title"] as? String,
              let content = storyDict["content"] as? String,
              let theme = storyDict["theme"] as? String,
              let childName = storyDict["childName"] as? String else {
            logger.error("❌ 保存故事参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 获取可选参数
        let audioURLString = storyDict["audioURL"] as? String
        let audioURL = audioURLString != nil ? URL(string: audioURLString!) : nil
        
        // 创建故事对象
        let story = Story(
            title: title,
            content: content,
            theme: theme,
            childName: childName,
            childAge: 8, // 默认年龄，可以从请求参数中获取实际值
            audioURL: audioURL?.absoluteString
        )
        
        // 保存故事
        dataService.addStory(story)
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["id": story.id])
    }
    
    // 处理获取故事请求
    private func handleGetStories(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        let params = body["params"] as? [String: Any]
        let childName = params?["childName"] as? String
        
        // 获取故事
        let stories: [Story]
        if let childName = childName {
            stories = dataService.getStories(forChildName: childName)
        } else {
            stories = dataService.getAllStories()
        }
        
        // 转换为字典数组
        let storiesDict = stories.map { story -> [String: Any] in
            var dict: [String: Any] = [
                "id": story.id,
                "title": story.title,
                "content": story.content,
                "theme": story.theme,
                "childName": story.childName,
                "createdAt": ISO8601DateFormatter().string(from: story.createdAt)
            ]
            
            if let audioURL = story.audioURL {
                dict["audioURL"] = audioURL
            }
            
            return dict
        }
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["stories": storiesDict])
    }
    
    // 处理获取故事详情请求
    private func handleGetStoryDetail(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let storyId = params["storyId"] as? String else {
            logger.error("❌ 获取故事详情参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 获取故事详情
        if let story = dataService.getStory(withId: storyId) {
            // 转换为字典
            var storyDict: [String: Any] = [
                "id": story.id,
                "title": story.title,
                "content": story.content,
                "theme": story.theme,
                "childName": story.childName,
                "createdAt": ISO8601DateFormatter().string(from: story.createdAt)
            ]
            
            if let audioURL = story.audioURL {
                storyDict["audioURL"] = audioURL
            }
            
            // 发送响应
            sendResponse(to: webView, callbackID: callbackID, data: ["story": storyDict])
        } else {
            // 故事不存在
            let error = NSError(domain: "com.baobao.app", code: 404, userInfo: [NSLocalizedDescriptionKey: "故事不存在"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
        }
    }
    
    // 处理删除故事请求
    private func handleDeleteStory(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let storyId = params["storyId"] as? String else {
            logger.error("❌ 删除故事参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 删除故事
        dataService.deleteStory(withId: storyId)
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["success": true])
    }
    
    // 处理保存宝宝请求
    private func handleSaveChild(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let childDict = params["child"] as? [String: Any],
              let name = childDict["name"] as? String,
              let age = childDict["age"] as? Int,
              let genderString = childDict["gender"] as? String else {
            logger.error("❌ 保存宝宝参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 解析性别
        guard let gender = Child.Gender.allCases.first(where: { $0.rawValue == genderString }) else {
            logger.error("❌ 无效的性别: \(genderString)")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的性别"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 获取可选参数
        let id = childDict["id"] as? String ?? UUID().uuidString
        let interests = childDict["interests"] as? [String] ?? []
        
        // 创建宝宝对象
        let child = Child(
            id: id,
            name: name,
            age: age,
            gender: gender,
            interests: interests
        )
        
        // 保存宝宝
        dataService.addChild(child)
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["id": child.id])
    }
    
    // 处理获取宝宝请求
    private func handleGetChildren(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 获取所有宝宝
        let children = dataService.getAllChildren()
        
        // 转换为字典数组
        let childrenDict = children.map { child -> [String: Any] in
            [
                "id": child.id,
                "name": child.name,
                "age": child.age,
                "gender": child.gender.rawValue,
                "interests": child.interests,
                "createdAt": ISO8601DateFormatter().string(from: child.createdAt)
            ]
        }
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["children": childrenDict])
    }
    
    // 处理删除宝宝请求
    private func handleDeleteChild(webView: WKWebView, body: [String: Any], callbackID: String) {
        // 解析参数
        guard let params = body["params"] as? [String: Any],
              let childId = params["childId"] as? String else {
            logger.error("❌ 删除宝宝参数无效")
            let error = NSError(domain: "com.baobao.app", code: 400, userInfo: [NSLocalizedDescriptionKey: "参数无效"])
            sendResponse(to: webView, callbackID: callbackID, data: nil, error: error)
            return
        }
        
        // 删除宝宝
        dataService.deleteChild(withId: childId)
        
        // 发送响应
        sendResponse(to: webView, callbackID: callbackID, data: ["success": true])
    }
} 