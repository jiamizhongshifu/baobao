#!/usr/bin/swift

import Foundation

// API密钥
let apiKey = "sk-5cc05eb59de1476792e079d19130c274"

// 创建URL请求
guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
    print("❌ 无效的API URL")
    exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.timeoutInterval = 30

// 设置请求头
request.addValue("application/json", forHTTPHeaderField: "Content-Type")
request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

// 设置请求体
let requestBody: [String: Any] = [
    "model": "deepseek-chat",
    "messages": [
        ["role": "user", "content": "你好，这是一个测试"]
    ],
    "max_tokens": 100
]

// 序列化请求体
guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
    print("❌ 无法序列化请求体")
    exit(1)
}

request.httpBody = httpBody

// 创建信号量
let semaphore = DispatchSemaphore(value: 0)

// 发送请求
print("📤 发送API请求...")
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
    if let data = data {
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                print("✅ API请求成功!")
                print("📝 响应内容: \(content)")
            } else {
                print("❌ 解析响应失败")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 原始响应: \(responseString)")
                }
            }
        } else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ API错误: \(errorMessage)")
            }
        }
    }
}

task.resume()
_ = semaphore.wait(timeout: .now() + 30) 