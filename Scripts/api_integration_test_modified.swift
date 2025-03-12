#!/usr/bin/swift

import Foundation

// MARK: - 测试配置

struct TestConfig {
    let deepseekApiKey: String
    let azureSpeechKey: String
    let azureSpeechRegion: String
    let testOutputDir: URL
    let useLocalFallback: Bool
    let useLocalTTSByDefault: Bool
}

// 从环境变量或配置文件加载配置
func loadConfig() -> TestConfig? {
    // 获取配置文件路径
    let configPath = ProcessInfo.processInfo.environment["CONFIG_PATH"] 
        ?? "/Users/zhongqingbiao/Documents/baobao/Config.plist"
    
    // 解析配置文件
    guard let configData = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let configDict = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String: Any] else {
        print("❌ 无法解析配置文件")
        return nil
    }
    
    // 提取API密钥
    let deepseekApiKey = configDict["DEEPSEEK_API_KEY"] as? String ?? ""
    let azureSpeechKey = configDict["AZURE_SPEECH_KEY"] as? String ?? ""
    let azureSpeechRegion = configDict["AZURE_SPEECH_REGION"] as? String ?? "eastasia"
    let useLocalFallback = configDict["USE_LOCAL_FALLBACK"] as? Bool ?? true
    let useLocalTTSByDefault = configDict["USE_LOCAL_TTS_BY_DEFAULT"] as? Bool ?? false
    
    // 创建测试输出目录
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let testOutputDir = documentsDirectory.appendingPathComponent("api_test_output")
    
    // 确保输出目录存在
    do {
        try FileManager.default.createDirectory(at: testOutputDir, withIntermediateDirectories: true)
    } catch {
        print("❌ 创建测试输出目录失败: \(error.localizedDescription)")
        return nil
    }
    
    return TestConfig(
        deepseekApiKey: deepseekApiKey,
        azureSpeechKey: azureSpeechKey,
        azureSpeechRegion: azureSpeechRegion,
        testOutputDir: testOutputDir,
        useLocalFallback: useLocalFallback,
        useLocalTTSByDefault: useLocalTTSByDefault
    )
}

// MARK: - 故事服务测试

// 测试故事生成
func testStoryGeneration(config: TestConfig) {
    print("\n🔍 开始测试故事生成服务...")
    
    // 检查API密钥
    if config.deepseekApiKey.isEmpty {
        print("⚠️ DeepSeek API密钥为空，跳过故事生成测试")
        return
    }
    
    // 设置环境变量
    setenv("DEEPSEEK_API_KEY", config.deepseekApiKey, 1)
    
    // 构建提示词
    let prompt = """
    [严禁暴力][适合5岁以下儿童][主角名称：小明]
    请创作一个适合5岁儿童的太空冒险主题故事，主角是小明，喜欢恐龙、火箭。
    故事应该有趣、积极向上，包含适当的教育意义，字数约300字。
    请使用简单易懂的语言，适合5岁儿童理解。
    故事需要有明确的开始、中间和结尾。
    请以故事标题开始，格式为"## 《故事标题》"。
    """
    
    // 创建URL请求
    guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
        print("❌ 无效的API URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    
    // 设置请求头
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(config.deepseekApiKey)", forHTTPHeaderField: "Authorization")
    
    // 设置请求体
    let requestBody: [String: Any] = [
        "model": "deepseek-chat",
        "messages": [
            ["role": "user", "content": prompt]
        ],
        "max_tokens": 2000,
        "temperature": 0.7
    ]
    
    // 序列化请求体
    guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("❌ 无法序列化请求体")
        return
    }
    
    request.httpBody = httpBody
    
    // 创建信号量
    let semaphore = DispatchSemaphore(value: 0)
    var storyContent: String?
    var storyTitle: String?
    
    // 发送请求
    print("📤 发送故事生成请求...")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        // 处理网络错误
        if let error = error {
            print("❌ 网络错误: \(error.localizedDescription)")
            return
        }
        
        // 检查HTTP响应
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的HTTP响应")
            return
        }
        
        print("🌐 HTTP状态码: \(httpResponse.statusCode)")
        
        // 处理响应数据
        if let data = data, httpResponse.statusCode == 200 {
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    print("❌ 解析响应失败")
                    return
                }
                
                print("✅ 故事生成成功!")
                
                // 提取标题和内容
                let titlePattern = "##\\s*《(.+?)》"
                let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [])
                let titleRange = NSRange(content.startIndex..., in: content)
                
                if let titleMatch = titleRegex?.firstMatch(in: content, options: [], range: titleRange),
                   let titleRange = Range(titleMatch.range(at: 1), in: content) {
                    storyTitle = String(content[titleRange])
                    
                    // 移除标题行
                    if let fullTitleRange = Range(titleMatch.range, in: content) {
                        let afterTitle = content.index(after: content.index(fullTitleRange.upperBound, offsetBy: -1))
                        storyContent = String(content[afterTitle...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        storyContent = content
                    }
                } else {
                    storyTitle = "未命名故事"
                    storyContent = content
                }
                
                // 保存故事到文件
                let storyFile = config.testOutputDir.appendingPathComponent("test_story.txt")
                try content.write(to: storyFile, atomically: true, encoding: .utf8)
                print("💾 故事已保存至: \(storyFile.path)")
                
            } catch {
                print("❌ 处理响应失败: \(error.localizedDescription)")
            }
        } else {
            if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ API错误: \(errorMessage)")
            } else {
                print("❌ API请求失败，状态码: \(httpResponse.statusCode)")
            }
            
            // 使用本地备份故事
            if config.useLocalFallback {
                print("⚠️ 使用本地备份故事")
                storyTitle = "小明的太空冒险"
                storyContent = """
                小明是一个喜欢恐龙和火箭的小男孩。一天晚上，他在床上翻看着恐龙图鉴，突然听到窗外有奇怪的声音。

                "嗖——嗖——"小明好奇地走到窗前，看到一艘小火箭停在他家的院子里。火箭门打开了，一只绿色的小恐龙探出头来："小明，快上来，我们要去太空冒险啦！"

                小明惊喜地穿上衣服，带上他最喜欢的恐龙玩具，跳上了火箭。"系好安全带，我们要起飞啦！"小恐龙说道。

                火箭飞向星空，穿过云层，小明看到了闪烁的星星和美丽的月亮。"哇，太空真美啊！"小明惊叹道。

                他们降落在一个奇特的星球上，这里有许多不同的恐龙。"这是恐龙星球，"小恐龙解释道，"这里的恐龙都很友好。"

                小明和恐龙们一起玩耍，学习如何照顾植物，还参观了星球上的科学实验室。

                天色渐晚，是时候回家了。小恐龙送小明回到地球，并送给他一颗会发光的星星作为纪念。

                回到床上，小明抱着发光的星星，做了一个甜甜的梦。他知道，只要他勇敢、善良，宇宙中还有更多奇妙的冒险等着他。
                """
                
                // 保存本地备份故事到文件
                let storyFile = config.testOutputDir.appendingPathComponent("test_story.txt")
                let fullContent = "## 《\(storyTitle!)》\n\n\(storyContent!)"
                do {
                    try fullContent.write(to: storyFile, atomically: true, encoding: .utf8)
                    print("💾 本地备份故事已保存至: \(storyFile.path)")
                } catch {
                    print("❌ 保存本地备份故事失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .now() + 60)
    
    // 如果成功生成故事，测试语音合成
    if let storyContent = storyContent, let storyTitle = storyTitle {
        print("\n📝 生成的故事标题: \(storyTitle)")
        print("📝 故事内容预览: \(String(storyContent.prefix(100)))...")
        
        // 测试语音合成
        testSpeechSynthesis(config: config, text: "《\(storyTitle)》\n\(storyContent.prefix(200))")
    }
}

// MARK: - 语音服务测试

// 测试语音合成
func testSpeechSynthesis(config: TestConfig, text: String) {
    print("\n🔊 开始测试语音合成服务...")
    
    // 检查是否默认使用本地TTS
    if config.useLocalTTSByDefault {
        print("⚠️ 配置为默认使用本地TTS")
        testLocalTTS(config: config, text: text)
        return
    }
    
    // 检查API密钥
    if config.azureSpeechKey.isEmpty {
        print("⚠️ Azure语音服务密钥为空，使用本地TTS")
        testLocalTTS(config: config, text: text)
        return
    }
    
    // 设置环境变量
    setenv("AZURE_SPEECH_KEY", config.azureSpeechKey, 1)
    
    // 构建SSML
    let ssml = """
    <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
        <voice name='zh-CN-XiaoxiaoNeural'>
            <prosody rate='0.9' pitch='0'>
                \(text)
            </prosody>
        </voice>
    </speak>
    """
    
    // 创建URL请求
    guard let url = URL(string: "https://\(config.azureSpeechRegion).tts.speech.microsoft.com/cognitiveservices/v1") else {
        print("❌ 无效的Azure语音服务URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    
    // 设置请求头
    request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
    request.addValue(config.azureSpeechKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
    
    // 设置请求体
    request.httpBody = ssml.data(using: .utf8)
    
    // 创建信号量
    let semaphore = DispatchSemaphore(value: 0)
    
    // 发送请求
    print("📤 发送语音合成请求...")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        // 处理网络错误
        if let error = error {
            print("❌ 网络错误: \(error.localizedDescription)")
            
            // 使用本地TTS作为备选方案
            if config.useLocalFallback {
                print("⚠️ 使用本地TTS作为备选方案")
                testLocalTTS(config: config, text: text)
            }
            return
        }
        
        // 检查HTTP响应
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的HTTP响应")
            return
        }
        
        print("🌐 HTTP状态码: \(httpResponse.statusCode)")
        
        // 处理响应数据
        if let audioData = data, httpResponse.statusCode == 200 {
            print("✅ 语音合成成功!")
            print("📊 音频数据大小: \(audioData.count) 字节")
            
            // 保存音频文件
            let audioFile = config.testOutputDir.appendingPathComponent("test_speech.mp3")
            do {
                try audioData.write(to: audioFile)
                print("💾 音频文件已保存至: \(audioFile.path)")
                
                // 测试缓存机制
                testCacheMechanism(config: config, audioData: audioData)
            } catch {
                print("❌ 保存音频文件失败: \(error.localizedDescription)")
            }
        } else {
            if let errorData = data, let errorMessage = String(data: errorData, encoding: .utf8) {
                print("❌ API错误: \(errorMessage)")
            } else {
                print("❌ API请求失败，状态码: \(httpResponse.statusCode)")
            }
            
            // 使用本地TTS作为备选方案
            if config.useLocalFallback {
                print("⚠️ 使用本地TTS作为备选方案")
                testLocalTTS(config: config, text: text)
            }
        }
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .now() + 30)
}

// 测试本地TTS
func testLocalTTS(config: TestConfig, text: String) {
    print("\n🔊 使用本地TTS生成语音...")
    
    // 创建一个简单的文本文件作为模拟音频文件
    let audioFile = config.testOutputDir.appendingPathComponent("test_speech_local.txt")
    do {
        try text.write(to: audioFile, atomically: true, encoding: .utf8)
        print("💾 本地TTS文本已保存至: \(audioFile.path)")
        
        // 模拟音频数据
        let mockAudioData = Data(text.utf8)
        
        // 测试缓存机制
        testCacheMechanism(config: config, audioData: mockAudioData)
    } catch {
        print("❌ 保存本地TTS文本失败: \(error.localizedDescription)")
    }
}

// MARK: - 缓存机制测试

// 测试缓存机制
func testCacheMechanism(config: TestConfig, audioData: Data) {
    print("\n💾 开始测试缓存机制...")
    
    // 创建缓存目录
    let cacheDir = config.testOutputDir.appendingPathComponent("cache")
    do {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    } catch {
        print("❌ 创建缓存目录失败: \(error.localizedDescription)")
        return
    }
    
    // 生成缓存键
    let cacheKey = "test_cache_\(Date().timeIntervalSince1970)"
    let cacheFile = cacheDir.appendingPathComponent("\(cacheKey).mp3")
    
    // 写入缓存文件
    do {
        try audioData.write(to: cacheFile)
        print("✅ 缓存文件写入成功: \(cacheFile.path)")
    } catch {
        print("❌ 写入缓存文件失败: \(error.localizedDescription)")
        return
    }
    
    // 验证缓存文件
    if FileManager.default.fileExists(atPath: cacheFile.path) {
        print("✅ 缓存文件验证成功")
        
        // 读取缓存文件
        do {
            let cachedData = try Data(contentsOf: cacheFile)
            print("✅ 缓存文件读取成功，大小: \(cachedData.count) 字节")
            
            // 验证数据一致性
            if cachedData == audioData {
                print("✅ 缓存数据一致性验证成功")
            } else {
                print("❌ 缓存数据一致性验证失败")
            }
        } catch {
            print("❌ 读取缓存文件失败: \(error.localizedDescription)")
        }
    } else {
        print("❌ 缓存文件验证失败")
    }
}

// MARK: - 错误处理测试

// 测试错误处理机制
func testErrorHandling(config: TestConfig) {
    print("\n⚠️ 开始测试错误处理机制...")
    
    // 测试无效的API密钥
    print("🔍 测试无效的API密钥...")
    
    // 创建URL请求
    guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
        print("❌ 无效的API URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    
    // 设置请求头（使用无效的API密钥）
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer invalid_api_key", forHTTPHeaderField: "Authorization")
    
    // 设置请求体
    let requestBody: [String: Any] = [
        "model": "deepseek-chat",
        "messages": [
            ["role": "user", "content": "测试错误处理"]
        ],
        "max_tokens": 100
    ]
    
    // 序列化请求体
    guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("❌ 无法序列化请求体")
        return
    }
    
    request.httpBody = httpBody
    
    // 创建信号量
    let semaphore = DispatchSemaphore(value: 0)
    
    // 发送请求
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        // 处理网络错误
        if let error = error {
            print("✅ 成功捕获网络错误: \(error.localizedDescription)")
            return
        }
        
        // 检查HTTP响应
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的HTTP响应")
            return
        }
        
        print("🌐 HTTP状态码: \(httpResponse.statusCode)")
        
        // 验证是否返回401错误
        if httpResponse.statusCode == 401 {
            print("✅ 成功捕获认证错误 (401)")
            
            if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                print("📄 错误信息: \(errorMessage)")
            }
        } else {
            print("❌ 未能捕获预期的认证错误")
        }
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .now() + 30)
    
    // 测试请求超时
    print("\n🔍 测试请求超时...")
    
    // 创建一个指向不存在的服务器的请求
    guard let timeoutUrl = URL(string: "https://example.invalid") else {
        print("❌ 无效的URL")
        return
    }
    
    var timeoutRequest = URLRequest(url: timeoutUrl)
    timeoutRequest.httpMethod = "GET"
    timeoutRequest.timeoutInterval = 5 // 设置较短的超时时间
    
    // 创建信号量
    let timeoutSemaphore = DispatchSemaphore(value: 0)
    
    // 发送请求
    let timeoutTask = URLSession.shared.dataTask(with: timeoutRequest) { data, response, error in
        defer { timeoutSemaphore.signal() }
        
        // 验证是否捕获到超时错误
        if let error = error as NSError? {
            if error.domain == NSURLErrorDomain && 
               (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorCannotFindHost) {
                print("✅ 成功捕获超时/连接错误: \(error.localizedDescription)")
            } else {
                print("✅ 成功捕获其他网络错误: \(error.localizedDescription)")
            }
        } else if let httpResponse = response as? HTTPURLResponse {
            print("❌ 未能捕获预期的超时错误，收到HTTP响应: \(httpResponse.statusCode)")
        } else {
            print("❌ 未能捕获预期的超时错误，且没有收到HTTP响应")
        }
    }
    
    timeoutTask.resume()
    _ = timeoutSemaphore.wait(timeout: .now() + 10)
}

// MARK: - 主函数

func main() {
    print("🚀 开始API集成测试...")
    
    // 加载配置
    guard let config = loadConfig() else {
        print("❌ 无法加载配置，测试终止")
        return
    }
    
    print("✅ 配置加载成功")
    print("📝 测试输出目录: \(config.testOutputDir.path)")
    
    // 测试故事生成
    testStoryGeneration(config: config)
    
    // 测试错误处理
    testErrorHandling(config: config)
    
    print("\n🏁 API集成测试完成")
}

// 执行主函数
main() 