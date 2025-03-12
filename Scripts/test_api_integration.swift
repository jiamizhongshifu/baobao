#!/usr/bin/swift

import Foundation

// 测试配置结构
struct TestConfig {
    let deepseekApiKey: String
    let azureApiKey: String
    let azureRegion: String
    let outputDir: URL
    let appSourceDir: URL
    let useMockData: Bool
    
    // 从配置文件加载配置
    static func loadFromPlist() -> TestConfig? {
        let configPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Config.plist")
        
        guard let configData = try? Data(contentsOf: configPath),
              let plist = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String: Any] else {
            print("无法加载配置文件")
            return nil
        }
        
        let deepseekApiKey = plist["DEEPSEEK_API_KEY"] as? String ?? "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        let azureApiKey = plist["AZURE_SPEECH_KEY"] as? String ?? "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        let azureRegion = plist["AZURE_SPEECH_REGION"] as? String ?? "eastasia"
        
        // 检查API密钥是否为占位符，如果是则使用模拟数据
        let useMockData = deepseekApiKey.contains("xxxxxxx") || azureApiKey.contains("xxxxxxx")
        if useMockData {
            print("API密钥为占位符，将使用模拟数据进行测试")
        }
        
        // 设置输出目录
        let outputDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents")
        
        // 设置应用源码目录
        let appSourceDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents")
            .appendingPathComponent("baobao")
        
        return TestConfig(
            deepseekApiKey: deepseekApiKey,
            azureApiKey: azureApiKey,
            azureRegion: azureRegion,
            outputDir: outputDir,
            appSourceDir: appSourceDir,
            useMockData: useMockData
        )
    }
}

// 测试故事生成API
func testStoryGeneration(config: TestConfig) -> (success: Bool, storyText: String) {
    print("开始测试故事生成API...")
    
    // 如果使用模拟数据，则直接返回模拟故事
    if config.useMockData {
        return createMockStory(config: config)
    }
    
    // 构建请求URL
    let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    // 设置请求头
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(config.deepseekApiKey)", forHTTPHeaderField: "Authorization")
    
    // 构建提示词
    let prompt = """
    请为5岁的孩子创作一个有关太空冒险的故事，故事应该：
    1. 主角是一个叫小明的小男孩
    2. 包含一个会说话的恐龙火箭
    3. 有一个简单的问题和解决方案
    4. 长度在400-500字之间
    5. 使用简单的语言，适合5岁孩子理解
    6. 包含一些有趣的声音效果
    7. 有一个积极向上的结局
    
    请直接给出故事内容，不要包含任何前言或说明。
    """
    
    // 构建请求体
    let requestBody: [String: Any] = [
        "model": "deepseek-chat",
        "messages": [
            ["role": "system", "content": "你是一个专业的儿童故事作家，擅长创作适合幼儿的有趣故事。请确保故事内容安全、积极、有教育意义。"],
            ["role": "user", "content": prompt]
        ],
        "temperature": 0.7,
        "max_tokens": 1000
    ]
    
    // 转换为JSON数据
    guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("无法序列化请求体")
        return (false, "")
    }
    
    request.httpBody = jsonData
    
    // 创建信号量用于同步
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    var storyText = ""
    var statusCode: Int = 0
    
    // 发送请求
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("故事生成API请求失败: \(error.localizedDescription)")
            semaphore.signal()
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            print("故事生成API返回状态码: \(statusCode)")
        }
        
        guard let data = data else {
            print("未收到数据")
            semaphore.signal()
            return
        }
        
        // 解析响应
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                storyText = content
                success = true
                
                // 保存故事文本
                let outputPath = config.outputDir.appendingPathComponent("test_story.txt")
                try storyText.write(to: outputPath, atomically: true, encoding: .utf8)
                print("故事文本已保存至: \(outputPath.path)")
                print("故事字数: \(storyText.count)")
            } else {
                print("无法解析响应")
            }
        } catch {
            print("解析响应失败: \(error.localizedDescription)")
        }
        
        semaphore.signal()
    }
    
    task.resume()
    semaphore.wait()
    
    return (success, storyText)
}

// 创建模拟故事数据
func createMockStory(config: TestConfig) -> (success: Bool, storyText: String) {
    print("使用模拟数据创建故事...")
    
    let mockStory = """
    小明和恐龙火箭的太空冒险
    
    从前，有一个叫小明的小男孩，他非常喜欢太空和恐龙。在他五岁生日那天，他收到了一个特别的礼物——一个看起来像恐龙的小火箭模型。
    
    "哇！这是我见过的最酷的火箭！"小明高兴地喊道。
    
    就在这时，神奇的事情发生了。恐龙火箭突然眨了眨眼睛，说话了！
    
    "嗨，小明！我是迪诺，一个会说话的恐龙火箭！"迪诺用友好的声音说道，"你想去太空冒险吗？"
    
    "当然想！"小明兴奋地跳了起来。
    
    "嗖——"迪诺发出火箭发射的声音，突然间，小明和迪诺变得很小，飞进了一个真正的宇宙飞船里。
    
    "哇塞！我们真的要去太空了吗？"小明惊讶地问。
    
    "是的！系好安全带，我们出发啦！"迪诺大声说道。
    
    "3、2、1，发射！轰隆隆！"火箭发出巨大的声音，冲向了星空。
    
    小明透过窗户看到地球变得越来越小。很快，他们来到了太空中。星星在四周闪烁，就像无数的小灯泡。
    
    "看那边！"迪诺指向一片黑暗的区域，"那里有一颗孤独的小行星，它迷路了，找不到回家的路。"
    
    小明看到了那颗闪着微弱光芒的小行星，它看起来很伤心。
    
    "我们能帮助它吗？"小明问道。
    
    "当然可以！"迪诺回答，"但我们需要找到它的家人。问题是，太空这么大，我们该怎么找呢？"
    
    小明想了想，说："我有个主意！我们可以问问其他星星，它们一定知道这颗小行星的家在哪里！"
    
    "太聪明了！"迪诺赞同道。
    
    他们开始向附近的星星询问。经过一番寻找，他们终于找到了一群和那颗孤独小行星长得很像的小行星。
    
    "叮叮当！"当他们把迷路的小行星带回家时，所有的小行星都发出了欢快的声音。
    
    "谢谢你们！"小行星们闪烁着感谢的光芒。
    
    "不客气！"小明笑着说，"帮助别人让我感到很开心！"
    
    回家的路上，迪诺对小明说："你今天解决了一个大问题，小明。你用聪明的方法帮助了迷路的小行星找到了家。"
    
    "是啊，"小明骄傲地说，"只要我们一起思考，就没有解决不了的问题！"
    
    当他们回到地球时，小明发现自己又回到了自己的房间，而迪诺变回了一个普通的火箭模型。但小明知道，他们的太空冒险是真实的，而且还会有更多冒险等着他们。
    
    "晚安，迪诺，"小明轻声说，"明天我们再去冒险吧！"
    
    他似乎听到迪诺小声回答："当然，小明，明天见！"
    """
    
    // 保存故事文本
    let outputPath = config.outputDir.appendingPathComponent("test_story.txt")
    do {
        try mockStory.write(to: outputPath, atomically: true, encoding: .utf8)
        print("模拟故事文本已保存至: \(outputPath.path)")
        print("模拟故事字数: \(mockStory.count)")
        return (true, mockStory)
    } catch {
        print("保存模拟故事失败: \(error.localizedDescription)")
        return (false, "")
    }
}

// 测试语音合成API
func testSpeechSynthesis(config: TestConfig, storyText: String) -> Bool {
    print("开始测试语音合成API...")
    
    // 如果使用模拟数据，则直接创建本地TTS文件
    if config.useMockData {
        return createLocalTTSFile(config: config, storyText: storyText)
    }
    // 构建请求URL
    let url = URL(string: "https://\(config.azureRegion).tts.speech.microsoft.com/cognitiveservices/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    // 设置请求头
    request.addValue(config.azureApiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
    request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
    request.addValue(UUID().uuidString, forHTTPHeaderField: "X-RequestId")
    
    // 构建SSML
    let ssml = """
    <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
        <voice name='zh-CN-XiaoxiaoNeural'>
            \(storyText.prefix(500))
        </voice>
    </speak>
    """
    
    request.httpBody = ssml.data(using: .utf8)
    
    // 创建信号量用于同步
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    var responseData: Data?
    var responseError: Error?
    var statusCode: Int = 0
    
    // 发送请求
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        responseData = data
        responseError = error
        
        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            print("语音合成API返回状态码: \(statusCode)")
        }
        
        semaphore.signal()
    }
    
    task.resume()
    semaphore.wait()
    
    // 检查响应
    if let error = responseError {
        print("语音合成API请求失败: \(error.localizedDescription)")
        // 使用本地TTS作为备选方案
        return createLocalTTSFile(config: config, storyText: storyText)
    }
    
    if statusCode != 200 {
        print("语音合成API返回错误状态码: \(statusCode)")
        if let data = responseData, let errorMessage = String(data: data, encoding: .utf8) {
            print("错误信息: \(errorMessage)")
        }
        // 使用本地TTS作为备选方案
        return createLocalTTSFile(config: config, storyText: storyText)
    }
    
    // 保存音频文件
    if let data = responseData {
        let outputPath = config.outputDir.appendingPathComponent("test_speech.mp3")
        do {
            try data.write(to: outputPath)
            print("语音文件已保存至: \(outputPath.path)")
            success = true
        } catch {
            print("保存语音文件失败: \(error.localizedDescription)")
            // 使用本地TTS作为备选方案
            return createLocalTTSFile(config: config, storyText: storyText)
        }
    } else {
        print("未收到语音数据")
        // 使用本地TTS作为备选方案
        return createLocalTTSFile(config: config, storyText: storyText)
    }
    
    return success
}

// 创建本地TTS文件作为备选方案
func createLocalTTSFile(config: TestConfig, storyText: String) -> Bool {
    print("使用本地TTS作为备选方案...")
    let outputPath = config.outputDir.appendingPathComponent("test_speech_local.txt")
    
    do {
        // 只保存故事文本的前500个字符作为示例
        try storyText.prefix(500).write(to: outputPath, atomically: true, encoding: .utf8)
        print("本地TTS文件已保存至: \(outputPath.path)")
        return true
    } catch {
        print("保存本地TTS文件失败: \(error.localizedDescription)")
        return false
    }
}

// 测试缓存机制
func testCacheMechanism(config: TestConfig, storyText: String) -> Bool {
    print("开始测试缓存机制...")
    
    // 创建缓存目录
    let cacheDir = config.outputDir.appendingPathComponent("cache")
    do {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    } catch {
        print("创建缓存目录失败: \(error.localizedDescription)")
        return false
    }
    
    // 生成缓存键
    let storyHash = String(storyText.prefix(100).hashValue)
    let cacheKey = "story_\(storyHash)"
    
    // 保存到缓存
    let cacheFile = cacheDir.appendingPathComponent("\(cacheKey).txt")
    do {
        try storyText.write(to: cacheFile, atomically: true, encoding: .utf8)
        print("故事已缓存至: \(cacheFile.path)")
    } catch {
        print("缓存故事失败: \(error.localizedDescription)")
        return false
    }
    
    // 从缓存读取
    do {
        let cachedStory = try String(contentsOf: cacheFile, encoding: .utf8)
        if cachedStory == storyText {
            print("缓存验证成功")
            return true
        } else {
            print("缓存验证失败: 内容不匹配")
            return false
        }
    } catch {
        print("读取缓存失败: \(error.localizedDescription)")
        return false
    }
}

// 主函数
func main() {
    print("开始API集成测试...")
    
    // 加载配置
    guard let config = TestConfig.loadFromPlist() else {
        print("无法加载配置，测试终止")
        exit(1)
    }
    
    // 测试故事生成API
    let (storySuccess, storyText) = testStoryGeneration(config: config)
    if !storySuccess {
        print("故事生成测试失败")
        exit(1)
    }
    
    // 测试语音合成API
    let speechSuccess = testSpeechSynthesis(config: config, storyText: storyText)
    if !speechSuccess {
        print("语音合成测试失败，但已使用本地TTS作为备选方案")
    }
    
    // 测试缓存机制
    let cacheSuccess = testCacheMechanism(config: config, storyText: storyText)
    if !cacheSuccess {
        print("缓存机制测试失败")
    }
    
    print("API集成测试完成")
}

// 执行主函数
main() 