#!/usr/bin/swift

import Foundation

// API密钥
let azureKey = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
let azureRegion = "eastasia"

// 测试文本
let text = "这是一个测试，用于验证Azure语音服务API是否正常工作。"

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
guard let url = URL(string: "https://\(azureRegion).tts.speech.microsoft.com/cognitiveservices/v1") else {
    print("❌ 无效的Azure语音服务URL")
    exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.timeoutInterval = 30

// 设置请求头
request.addValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
request.addValue(azureKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
request.addValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
request.addValue("zh-CN", forHTTPHeaderField: "Accept-Language")

// 打印请求详情
print("🔍 请求URL: \(url.absoluteString)")
print("🔍 请求头:")
for (key, value) in request.allHTTPHeaderFields ?? [:] {
    print("   \(key): \(value)")
}
print("🔍 请求体: \(ssml)")

// 设置请求体
request.httpBody = ssml.data(using: .utf8)

// 创建信号量
let semaphore = DispatchSemaphore(value: 0)

// 发送请求
print("📤 发送Azure语音合成请求...")
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
    print("🌐 响应头:")
    for (key, value) in httpResponse.allHeaderFields {
        print("   \(key): \(value)")
    }
    
    // 处理响应数据
    if let audioData = data, httpResponse.statusCode == 200 {
        print("✅ 语音合成成功!")
        print("📊 音频数据大小: \(audioData.count) 字节")
        
        // 保存音频文件
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFile = documentsDirectory.appendingPathComponent("test_azure_speech.mp3")
        
        do {
            try audioData.write(to: audioFile)
            print("💾 音频文件已保存至: \(audioFile.path)")
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
_ = semaphore.wait(timeout: .now() + 30) 