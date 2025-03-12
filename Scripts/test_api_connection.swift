#!/usr/bin/swift

import Foundation

// MARK: - 配置

struct APIConfig {
    let deepseekApiKey: String
    let azureSpeechKey: String
    let azureSpeechRegion: String
}

// 从配置文件读取API密钥
func loadConfig() -> APIConfig? {
    let configPath = ProcessInfo.processInfo.environment["CONFIG_PATH"] 
        ?? Bundle.main.path(forResource: "Config", ofType: "plist") 
        ?? "/Users/zhongqingbiao/Documents/baobao/Config.plist"
    
    guard let configData = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let configDict = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String: Any] else {
        print("❌ 无法解析配置文件")
        return nil
    }
    
    guard let deepseekApiKey = configDict["DEEPSEEK_API_KEY"] as? String,
          let azureSpeechKey = configDict["AZURE_SPEECH_KEY"] as? String,
          let azureSpeechRegion = configDict["AZURE_SPEECH_REGION"] as? String else {
        print("❌ 配置文件中缺少必要的API密钥")
        return nil
    }
    
    return APIConfig(
        deepseekApiKey: deepseekApiKey,
        azureSpeechKey: azureSpeechKey,
        azureSpeechRegion: azureSpeechRegion
    )
}

// MARK: - DeepSeek API测试

func testDeepSeekAPI(apiKey: String) {
    print("🔍 开始测试DeepSeek API...")
    
    // API请求URL
    let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 60 // 增加超时时间到60秒
    
    // 设置请求头
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    // 设置请求体
    let requestBody: [String: Any] = [
        "model": "deepseek-chat",
        "messages": [
            ["role": "system", "content": "[严禁暴力][适合5岁以下儿童]"],
            ["role": "user", "content": "请生成一个100字的简短儿童故事，主角名字是小明，主题是太空冒险。"]
        ],
        "max_tokens": 300,
        "temperature": 0.7
    ]
    
    guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("❌ 无法序列化请求体")
        return
    }
    
    request.httpBody = httpBody
    print("📤 发送请求到: \(url.absoluteString)")
    print("📤 请求体: \(String(data: httpBody, encoding: .utf8) ?? "无法读取")")
    
    // 创建任务并等待
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("❌ 网络错误: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的HTTP响应")
            return
        }
        
        print("🌐 HTTP状态码: \(httpResponse.statusCode)")
        print("🌐 响应头: \(httpResponse.allHeaderFields)")
        
        if let data = data {
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ DeepSeek API连接成功!")
                    print("📝 完整响应: \(json)")
                    
                    if let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        print("📝 生成的故事:\n\(content)")
                    } else {
                        print("⚠️ 无法解析响应中的故事内容")
                    }
                } else {
                    print("⚠️ 无法解析API响应为JSON")
                    if let jsonStr = String(data: data, encoding: .utf8) {
                        print("📄 原始响应: \(jsonStr)")
                    }
                }
            } else {
                if let jsonStr = String(data: data, encoding: .utf8) {
                    print("❌ API错误: \(jsonStr)")
                }
            }
        } else {
            print("❌ 响应数据为空")
        }
    }
    
    task.resume()
    print("⏳ 等待DeepSeek API响应，最长60秒...")
    _ = semaphore.wait(timeout: .now() + 60) // 增加等待时间到60秒
}

// MARK: - Azure语音API测试

func testAzureSpeechAPI(apiKey: String, region: String) {
    print("\n🔊 开始测试Azure语音API...")
    
    // 构建SSML
    let ssml = """
    <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
        <voice name='zh-CN-XiaoxiaoNeural'>
            你好，这是一个测试。我是宝宝故事应用的语音助手。
        </voice>
    </speak>
    """
    
    // API请求URL
    let url = URL(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    // 设置请求头
    request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
    request.addValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
    
    // 设置请求体
    request.httpBody = ssml.data(using: .utf8)
    
    // 创建任务并等待
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("❌ 网络错误: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的HTTP响应")
            return
        }
        
        print("🌐 HTTP状态码: \(httpResponse.statusCode)")
        
        if let data = data, httpResponse.statusCode == 200 {
            print("✅ Azure语音API连接成功!")
            print("📊 音频数据大小: \(data.count) 字节")
            
            // 保存音频文件用于测试
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("test_speech.mp3")
            
            do {
                try data.write(to: fileURL)
                print("💾 音频文件已保存至: \(fileURL.path)")
            } catch {
                print("❌ 保存音频文件失败: \(error.localizedDescription)")
            }
        } else {
            if let errorData = data, let errorMessage = String(data: errorData, encoding: .utf8) {
                print("❌ API错误: \(errorMessage)")
            } else {
                print("❌ API请求失败，状态码: \(httpResponse.statusCode)")
            }
        }
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .now() + 20)
}

// MARK: - 主函数

func main() {
    print("🚀 开始API连接测试...")
    
    guard let config = loadConfig() else {
        print("❌ 无法加载配置，测试终止")
        return
    }
    
    print("✅ 配置文件加载成功")
    print("📝 DeepSeek API密钥: \(String(config.deepseekApiKey.prefix(5)))...\(String(config.deepseekApiKey.suffix(5)))")
    print("📝 Azure语音密钥: \(String(config.azureSpeechKey.prefix(5)))...\(String(config.azureSpeechKey.suffix(5)))")
    print("📝 Azure区域: \(config.azureSpeechRegion)")
    
    // 测试DeepSeek API
    testDeepSeekAPI(apiKey: config.deepseekApiKey)
    
    // 测试Azure语音API
    testAzureSpeechAPI(apiKey: config.azureSpeechKey, region: config.azureSpeechRegion)
    
    print("\n🏁 API连接测试完成")
}

// 执行主函数
main() 