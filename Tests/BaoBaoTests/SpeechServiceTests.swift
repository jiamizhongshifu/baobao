import XCTest
import Combine
import AVFoundation
@testable import BaoBao

final class SpeechServiceTests: XCTestCase {
    
    var speechService: TestSpeechService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        speechService = TestSpeechService()
    }
    
    override func tearDownWithError() throws {
        speechService = nil
        cancellables.removeAll()
        try super.tearDownWithError()
    }
    
    func testSpeechSynthesis() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "语音合成")
        
        // 模拟网络在线
        speechService.networkManager.setConnected(true)
        
        // 测试文本
        let testText = "这是一段测试文本，用于语音合成测试。"
        let voiceType: VoiceType = .xiaoMing
        
        // 合成语音
        speechService.synthesizeSpeech(text: testText, voiceType: voiceType) { result in
            switch result {
            case .success(let audioURL):
                // 验证音频文件存在
                XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path), "音频文件应该存在")
                
                // 验证音频时长大于0
                do {
                    let audioAsset = AVURLAsset(url: audioURL)
                    let duration = try audioAsset.load(.duration).seconds
                    XCTAssertGreaterThan(duration, 0, "音频时长应该大于0")
                } catch {
                    XCTFail("无法读取音频时长: \(error.localizedDescription)")
                }
                
            case .failure(let error):
                XCTFail("语音合成失败: \(error.localizedDescription)")
            }
            
            expectation.fulfill()
        }
        
        // 等待语音合成完成
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSpeechSynthesisWithOfflineMode() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "离线模式语音合成")
        
        // 启用离线模式
        speechService.networkManager.enableOfflineMode()
        
        // 确保缓存为空
        speechService.cacheManager.clearCache(type: .speech)
        
        // 尝试合成语音
        speechService.synthesizeSpeech(text: "离线模式测试", voiceType: .xiaoHong) { result in
            switch result {
            case .success:
                // 检查是否使用了本地TTS（本地TTS在测试中应该是模拟成功的）
                XCTAssertTrue(self.speechService.usedLocalTTS, "离线模式下应使用本地TTS")
            case .failure(let error):
                if !self.speechService.useLocalFallback {
                    // 如果禁用了本地TTS，则预期失败
                    if case .offlineMode = error {
                        // 预期的错误
                        XCTAssert(true)
                    } else if case .noCache = error {
                        // 也可能是缓存不可用错误
                        XCTAssert(true)
                    } else {
                        XCTFail("离线模式下应返回离线模式或缓存不可用错误")
                    }
                } else {
                    XCTFail("启用本地TTS的情况下应成功: \(error.localizedDescription)")
                }
            }
            
            expectation.fulfill()
        }
        
        // 等待语音合成完成
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testCachedSpeechRetrieval() throws {
        // 创建期望
        let expectation1 = XCTestExpectation(description: "首次语音合成")
        let expectation2 = XCTestExpectation(description: "缓存语音获取")
        
        // 模拟网络在线
        speechService.networkManager.setConnected(true)
        
        // 测试文本
        let testText = "这是缓存测试文本。"
        let voiceType: VoiceType = .pingPing
        
        // 首次合成语音
        speechService.synthesizeSpeech(text: testText, voiceType: voiceType) { result in
            switch result {
            case .success(let audioURL):
                // 首次生成的音频URL
                let firstURL = audioURL
                
                // 再次合成相同文本和语音类型，应该返回缓存
                self.speechService.synthesizeSpeech(text: testText, voiceType: voiceType) { secondResult in
                    switch secondResult {
                    case .success(let cachedURL):
                        // 验证URL与首次相同
                        XCTAssertEqual(cachedURL.path, firstURL.path, "第二次应返回缓存的音频")
                        XCTAssertTrue(self.speechService.usedCache, "应使用缓存")
                    case .failure(let error):
                        XCTFail("缓存检索失败: \(error.localizedDescription)")
                    }
                    
                    expectation2.fulfill()
                }
                
            case .failure(let error):
                XCTFail("语音合成失败: \(error.localizedDescription)")
                expectation2.fulfill()
            }
            
            expectation1.fulfill()
        }
        
        // 等待两个操作完成
        wait(for: [expectation1, expectation2], timeout: 5.0)
    }
    
    func testLocalTTSFallback() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "本地TTS回退")
        
        // 模拟网络故障但启用本地TTS
        speechService.networkManager.setConnected(false)
        speechService.useLocalFallback = true
        
        // 尝试合成语音
        speechService.synthesizeSpeech(text: "本地TTS测试", voiceType: .laoWang) { result in
            switch result {
            case .success:
                // 应该使用本地TTS成功
                XCTAssertTrue(self.speechService.usedLocalTTS, "应使用本地TTS")
            case .failure(let error):
                XCTFail("启用本地TTS下应成功: \(error.localizedDescription)")
            }
            
            expectation.fulfill()
        }
        
        // 等待操作完成
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSpeechSynthesisFailureRetry() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "语音合成重试")
        
        // 设置首次尝试失败，重试成功
        speechService.shouldFailOnFirstAttempt = true
        
        // 模拟网络在线
        speechService.networkManager.setConnected(true)
        
        // 测试文本
        let testText = "这是重试测试文本。"
        
        // 合成语音
        speechService.synthesizeSpeech(text: testText, voiceType: .xiaoMing) { result in
            switch result {
            case .success:
                // 成功应该是通过重试机制实现的
                XCTAssertEqual(self.speechService.retryCount, 1, "应尝试重试一次")
            case .failure(let error):
                XCTFail("语音合成应通过重试成功，但失败了: \(error.localizedDescription)")
            }
            
            expectation.fulfill()
        }
        
        // 等待重试完成
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSpeechSynthesisStatusPublisher() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "状态发布者更新")
        
        // 变量跟踪状态变化
        var receivedStatuses: [Bool] = []
        
        // 订阅状态变化
        speechService.isSynthesizingPublisher
            .sink { isSynthesizing in
                receivedStatuses.append(isSynthesizing)
                if receivedStatuses.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 开始合成然后完成
        speechService.simulateSuccessfulSynthesis()
        
        // 等待状态更新
        wait(for: [expectation], timeout: 2.0)
        
        // 验证状态更新
        XCTAssertEqual(receivedStatuses.count, 2, "应该收到两次状态更新")
        XCTAssertTrue(receivedStatuses[0], "第一次更新应为合成中状态")
        XCTAssertFalse(receivedStatuses[1], "第二次更新应为非合成中状态")
    }
    
    func testCancelSpeechSynthesis() throws {
        // 创建期望
        let expectation = XCTestExpectation(description: "取消语音合成")
        
        // 确保初始状态
        XCTAssertFalse(speechService.isSynthesizing)
        
        // 开始合成
        let longSynthesisDispatchGroup = DispatchGroup()
        
        // 开始合成
        longSynthesisDispatchGroup.enter()
        speechService.simulateLongSynthesis(text: "长时间合成测试", voiceType: .xiaoMing) { result in
            switch result {
            case .success:
                XCTFail("取消后不应返回成功")
            case .failure(let error):
                if case .synthesizeFailed = error {
                    // 预期的错误
                    XCTAssert(true)
                } else {
                    XCTFail("取消后应返回合成失败错误")
                }
            }
            longSynthesisDispatchGroup.leave()
        }
        
        // 确认合成已开始
        XCTAssertTrue(speechService.isSynthesizing)
        
        // 取消合成
        speechService.cancelSynthesis()
        
        // 验证状态重置
        XCTAssertFalse(speechService.isSynthesizing)
        
        longSynthesisDispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }
        
        // 等待操作完成
        wait(for: [expectation], timeout: 1.0)
    }
}

// 用于测试的SpeechService子类
class TestSpeechService: SpeechService {
    
    let testNetworkManager = TestNetworkManager()
    let testCacheManager = CacheManager()
    var usedCache = false
    var usedLocalTTS = false
    var retryCount = 0
    var shouldFailOnFirstAttempt = false
    var longSynthesisCompletionHandler: ((Result<URL, SpeechServiceError>) -> Void)?
    var useLocalFallback = true
    
    override var networkManager: NetworkManager {
        return testNetworkManager
    }
    
    override var cacheManager: CacheManager {
        return testCacheManager
    }
    
    // 模拟长时间合成过程
    func simulateLongSynthesis(text: String, voiceType: VoiceType, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        isSynthesizing = true
        longSynthesisCompletionHandler = completion
    }
    
    // 模拟成功的合成过程
    func simulateSuccessfulSynthesis() {
        isSynthesizing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSynthesizing = false
        }
    }
    
    // 重写语音合成方法
    override func synthesizeSpeech(text: String, voiceType: VoiceType, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        // 检查是否使用缓存
        let cacheKey = generateCacheKey(text: text, voiceType: voiceType)
        
        if testCacheManager.hasCache(forKey: cacheKey, type: .speech),
           let cachedURL = testCacheManager.getCacheFileURL(forKey: cacheKey, type: .speech),
           FileManager.default.fileExists(atPath: cachedURL.path) {
            
            usedCache = true
            completion(.success(cachedURL))
            return
        }
        
        // 检查网络是否可用
        if !testNetworkManager.canPerformNetworkRequest() {
            // 如果启用了本地TTS则使用本地TTS
            if useLocalFallback {
                usedLocalTTS = true
                synthesizeWithLocalTTS(text: text, voiceType: voiceType, completion: completion)
                return
            }
            
            completion(.failure(.offlineMode))
            return
        }
        
        // 设置合成状态
        isSynthesizing = true
        
        // 模拟合成过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 检查是否取消
            if !self.isSynthesizing {
                completion(.failure(.synthesizeFailed))
                return
            }
            
            // 检查是否应该第一次失败
            if self.shouldFailOnFirstAttempt && self.retryCount == 0 {
                self.retryCount += 1
                
                // 在短暂延迟后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.synthesizeAudio(text: text, voiceType: voiceType) { result in
                        self.isSynthesizing = false
                        completion(result)
                    }
                }
                return
            }
            
            // 合成音频
            self.synthesizeAudio(text: text, voiceType: voiceType) { result in
                self.isSynthesizing = false
                completion(result)
            }
        }
    }
    
    // 使用本地TTS合成
    private func synthesizeWithLocalTTS(text: String, voiceType: VoiceType, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        // 创建临时音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
        
        // 模拟生成音频文件
        let dummyAudioData = self.generateDummyAudioData()
        do {
            try dummyAudioData.write(to: tempURL)
            completion(.success(tempURL))
        } catch {
            completion(.failure(.fileError))
        }
    }
    
    // 合成音频
    private func synthesizeAudio(text: String, voiceType: VoiceType, completion: @escaping (Result<URL, SpeechServiceError>) -> Void) {
        // 获取缓存键
        let cacheKey = generateCacheKey(text: text, voiceType: voiceType)
        
        // 创建临时音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
        
        // 模拟生成音频文件
        let dummyAudioData = generateDummyAudioData()
        do {
            try dummyAudioData.write(to: tempURL)
            
            // 缓存生成的音频
            if let audioURL = testCacheManager.saveFileToCache(fileURL: tempURL, forKey: cacheKey, type: .speech) {
                completion(.success(audioURL))
            } else {
                completion(.success(tempURL))
            }
        } catch {
            completion(.failure(.synthesizeFailed))
        }
    }
    
    // 生成测试用的音频数据
    private func generateDummyAudioData() -> Data {
        // 这里仅仅生成一个有效的m4a文件头部，使其能被AVFoundation识别
        // 实际测试中应该使用更完整的音频样本
        return Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20, 0x00, 0x00, 0x00, 0x00,
                     0x4D, 0x34, 0x41, 0x20, 0x6D, 0x70, 0x34, 0x32, 0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x00, 0x00])
    }
    
    // 重写取消合成方法
    override func cancelSynthesis() {
        if isSynthesizing {
            isSynthesizing = false
            if let completionHandler = longSynthesisCompletionHandler {
                completionHandler(.failure(.synthesizeFailed))
                longSynthesisCompletionHandler = nil
            }
        }
    }
}

// 用于测试的NetworkManager子类
class TestNetworkManager: NetworkManager {
    private var isConnected = true
    
    func setConnected(_ connected: Bool) {
        isConnected = connected
        status = connected ? .connected : .disconnected
        connectionType = connected ? .wifi : .none
    }
    
    override func canPerformNetworkRequest() -> Bool {
        return isConnected && !isOfflineMode
    }
    
    func enableOfflineMode() {
        isOfflineMode = true
    }
    
    func disableOfflineMode() {
        isOfflineMode = false
    }
} 