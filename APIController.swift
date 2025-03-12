import Foundation
import WebKit
import os.log
import AVFoundation

class APIController: NSObject {
    static let shared = APIController()
    private let logger = Logger(subsystem: "com.example.baobao", category: "APIController")
    private var webView: WKWebView?
    private let dataService = APIDataService.shared
    private let speechService = SpeechService.shared
    
    private override init() {
        super.init()
        logger.info("🚀 APIController初始化")
    }
    
    func registerMessageHandlers(for webView: WKWebView) {
        self.webView = webView
        
        // 注册消息处理器
        let handlers = [
            "generateStory",
            "synthesizeSpeech",
            "playAudio",
            "stopAudio",
            "pauseAudio",
            "resumeAudio",
            "seekAudio",
            "saveStory",
            "updateStory",
            "getStories",
            "getStoriesByChild",
            "searchStories",
            "getStoryDetail",
            "deleteStory",
            "saveChild",
            "getChildren",
            "deleteChild",
            "clearCache",
            "getSystemStatus"
        ]
        
        handlers.forEach { handler in
            webView.configuration.userContentController.add(self, name: handler)
        }
        
        logger.info("📝 注册了\(handlers.count)个消息处理器")
    }
}

// MARK: - WKScriptMessageHandler
extension APIController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.info("📥 收到WebView消息: \(message.name)")
        
        guard let body = message.body as? [String: Any],
              let callbackID = body["callbackID"] as? String else {
            logger.error("❌ 消息格式错误")
            return
        }
        
        let params = body["params"] as? [String: Any] ?? [:]
        
        // 处理不同类型的消息
        switch message.name {
        case "generateStory":
            handleGenerateStory(params: params, callbackID: callbackID)
        case "synthesizeSpeech":
            handleSynthesizeSpeech(params: params, callbackID: callbackID)
        case "playAudio":
            handlePlayAudio(params: params, callbackID: callbackID)
        case "stopAudio":
            handleStopAudio(callbackID: callbackID)
        case "pauseAudio":
            handlePauseAudio(callbackID: callbackID)
        case "resumeAudio":
            handleResumeAudio(callbackID: callbackID)
        case "seekAudio":
            handleSeekAudio(params: params, callbackID: callbackID)
        case "saveStory":
            handleSaveStory(params: params, callbackID: callbackID)
        case "updateStory":
            handleUpdateStory(params: params, callbackID: callbackID)
        case "getStories":
            handleGetStories(params: params, callbackID: callbackID)
        case "getStoriesByChild":
            handleGetStoriesByChild(params: params, callbackID: callbackID)
        case "searchStories":
            handleSearchStories(params: params, callbackID: callbackID)
        case "getStoryDetail":
            handleGetStoryDetail(params: params, callbackID: callbackID)
        case "deleteStory":
            handleDeleteStory(params: params, callbackID: callbackID)
        case "saveChild":
            handleSaveChild(params: params, callbackID: callbackID)
        case "getChildren":
            handleGetChildren(callbackID: callbackID)
        case "deleteChild":
            handleDeleteChild(params: params, callbackID: callbackID)
        case "clearCache":
            handleClearCache(callbackID: callbackID)
        case "getSystemStatus":
            handleGetSystemStatus(callbackID: callbackID)
        default:
            sendError(callbackID: callbackID, message: "未知的消息类型: \(message.name)")
        }
    }
    
    // MARK: - 消息处理方法
    
    private func handleGenerateStory(params: [String: Any], callbackID: String) {
        guard let theme = params["theme"] as? String,
              let childName = params["childName"] as? String,
              let childAge = params["childAge"] as? Int else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        let childInterests = params["childInterests"] as? [String] ?? []
        let length = params["length"] as? String ?? "中篇"
        
        // 使用 async/await 生成故事
        Task {
            do {
                let story = try await StoryGenerationService.shared.generateStory(
                    theme: theme,
                    childName: childName,
                    age: childAge,
                    interests: childInterests,
                    length: length
                )
                
                // 保存故事
                dataService.saveStory(story) { [weak self] error in
                    if let error = error {
                        self?.sendError(callbackID: callbackID, message: error.localizedDescription)
                    } else {
                        self?.sendSuccess(callbackID: callbackID, data: story.toDictionary())
                    }
                }
            } catch {
                sendError(callbackID: callbackID, message: error.localizedDescription)
            }
        }
    }
    
    private func handleSynthesizeSpeech(params: [String: Any], callbackID: String) {
        guard let text = params["text"] as? String,
              let storyId = params["storyId"] as? String else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        let voiceType = params["voiceType"] as? String ?? "萍萍阿姨"
        
        // 先获取故事信息
        dataService.getStory(id: storyId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var story):
                // 开始语音合成
                self.speechService.synthesize(text: text, voiceType: voiceType) { result in
                    switch result {
                    case .success(let url):
                        // 获取音频时长
                        do {
                            let player = try AVAudioPlayer(contentsOf: url)
                            let duration = player.duration
                            
                            // 更新故事的音频信息
                            story = story.updateAudioInfo(url: url.absoluteString, duration: duration)
                            
                            // 保存更新后的故事
                            self.dataService.saveStory(story) { error in
                                if let error = error {
                                    self.sendError(callbackID: callbackID, message: error.localizedDescription)
                                } else {
                                    self.sendSuccess(callbackID: callbackID, data: [
                                        "audioURL": url.absoluteString,
                                        "duration": duration
                                    ])
                                }
                            }
                        } catch {
                            self.sendError(callbackID: callbackID, message: error.localizedDescription)
                        }
                    case .failure(let error):
                        self.sendError(callbackID: callbackID, message: error.localizedDescription)
                    }
                }
            case .failure(let error):
                self.sendError(callbackID: callbackID, message: error.localizedDescription)
            }
        }
    }
    
    private func handlePlayAudio(params: [String: Any], callbackID: String) {
        guard let audioURLString = params["audioURL"] as? String,
              let audioURL = URL(string: audioURLString),
              let storyId = params["storyId"] as? String else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        let startPosition = params["startPosition"] as? TimeInterval ?? 0
        
        // 获取故事信息
        dataService.getStory(id: storyId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(var story):
                // 开始播放音频
                self.speechService.play(url: audioURL, from: startPosition) { [weak self] currentTime in
                    guard let self = self else { return }
                    
                    // 更新播放进度
                    story = story.updatePlayPosition(currentTime)
                    
                    // 发送进度更新消息给WebView
                    self.sendPlaybackProgress(storyId: storyId, currentTime: currentTime)
                    
                    // 每隔一段时间保存播放进度
                    if Int(currentTime) % 5 == 0 {
                        self.dataService.saveStory(story) { _ in }
                    }
                } completion: { error in
                    if let error = error {
                        self.sendError(callbackID: callbackID, message: error.localizedDescription)
                    } else {
                        self.sendSuccess(callbackID: callbackID, data: ["success": true])
                    }
                }
            case .failure(let error):
                self.sendError(callbackID: callbackID, message: error.localizedDescription)
            }
        }
    }
    
    private func handleStopAudio(callbackID: String) {
        speechService.stop()
        sendSuccess(callbackID: callbackID, data: ["success": true])
    }
    
    private func handleSaveStory(params: [String: Any], callbackID: String) {
        guard let storyData = params["story"] as? [String: Any],
              let story = Story(dictionary: storyData) else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        dataService.saveStory(story) { [weak self] error in
            if let error = error {
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            } else {
                self?.sendSuccess(callbackID: callbackID, data: ["id": story.id])
            }
        }
    }
    
    private func handleGetStories(params: [String: Any], callbackID: String) {
        let childName = params["childName"] as? String
        
        dataService.getStories(forChild: childName) { [weak self] result in
            switch result {
            case .success(let stories):
                let storiesData = stories.map { $0.toDictionary() }
                self?.sendSuccess(callbackID: callbackID, data: ["stories": storiesData])
            case .failure(let error):
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            }
        }
    }
    
    private func handleGetStoryDetail(params: [String: Any], callbackID: String) {
        guard let storyId = params["storyId"] as? String else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        dataService.getStory(id: storyId) { [weak self] result in
            switch result {
            case .success(let story):
                self?.sendSuccess(callbackID: callbackID, data: ["story": story.toDictionary()])
            case .failure(let error):
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            }
        }
    }
    
    private func handleDeleteStory(params: [String: Any], callbackID: String) {
        guard let storyId = params["storyId"] as? String else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        dataService.deleteStory(id: storyId) { [weak self] error in
            if let error = error {
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            } else {
                self?.sendSuccess(callbackID: callbackID, data: ["success": true])
            }
        }
    }
    
    private func handleSaveChild(params: [String: Any], callbackID: String) {
        guard let childData = params["child"] as? [String: Any],
              let child = Child(dictionary: childData) else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        dataService.saveChild(child) { [weak self] error in
            if let error = error {
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            } else {
                self?.sendSuccess(callbackID: callbackID, data: ["id": child.id])
            }
        }
    }
    
    private func handleGetChildren(callbackID: String) {
        dataService.getChildren { [weak self] result in
            switch result {
            case .success(let children):
                let childrenData = children.map { $0.toDictionary() }
                self?.sendSuccess(callbackID: callbackID, data: ["children": childrenData])
            case .failure(let error):
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            }
        }
    }
    
    private func handleDeleteChild(params: [String: Any], callbackID: String) {
        guard let childId = params["childId"] as? String else {
            sendError(callbackID: callbackID, message: "参数错误")
            return
        }
        
        dataService.deleteChild(id: childId) { [weak self] error in
            if let error = error {
                self?.sendError(callbackID: callbackID, message: error.localizedDescription)
            } else {
                self?.sendSuccess(callbackID: callbackID, data: ["success": true])
            }
        }
    }
    
    // MARK: - 播放进度更新
    
    private func sendPlaybackProgress(storyId: String, currentTime: TimeInterval) {
        guard let webView = webView else { return }
        
        let progressData: [String: Any] = [
            "type": "playbackProgress",
            "data": [
                "storyId": storyId,
                "currentTime": currentTime
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: progressData)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                DispatchQueue.main.async {
                    webView.evaluateJavaScript("window.handlePlaybackProgress(\(jsonString))") { _, error in
                        if let error = error {
                            self.logger.error("❌ 发送播放进度失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            logger.error("❌ JSON序列化失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助方法
    
    private func sendSuccess(callbackID: String, data: [String: Any]) {
        let response: [String: Any] = [
            "callbackID": callbackID,
            "success": true,
            "data": data
        ]
        
        sendResponse(response)
    }
    
    private func sendError(callbackID: String, message: String) {
        let response: [String: Any] = [
            "callbackID": callbackID,
            "success": false,
            "error": message
        ]
        
        sendResponse(response)
    }
    
    private func sendResponse(_ response: [String: Any]) {
        guard let webView = webView else {
            logger.error("❌ WebView未初始化")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                logger.error("❌ JSON序列化失败")
                return
            }
            
            DispatchQueue.main.async {
                webView.evaluateJavaScript("window.handleNativeResponse(\(jsonString))") { [weak self] (_, error) in
                    if let error = error {
                        self?.logger.error("❌ 发送响应失败: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            logger.error("❌ JSON序列化失败: \(error.localizedDescription)")
        }
    }
} 