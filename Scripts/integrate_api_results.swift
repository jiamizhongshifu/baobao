#!/usr/bin/swift

import Foundation

// MARK: - 配置

struct IntegrationConfig {
    let testOutputDir: URL
    let appSourceDir: URL
    let reportOutputPath: URL
    
    // 初始化配置
    static func createDefault() -> IntegrationConfig {
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let documentsDir = homeDir.appendingPathComponent("Documents")
        
        return IntegrationConfig(
            testOutputDir: documentsDir,
            appSourceDir: documentsDir.appendingPathComponent("baobao"),
            reportOutputPath: documentsDir.appendingPathComponent("api_integration_report.md")
        )
    }
}

// MARK: - 测试结果分析

// 分析故事生成测试结果
func analyzeStoryGenerationResults(config: IntegrationConfig) -> (success: Bool, details: String, title: String, wordCount: Int) {
    let storyFilePath = config.testOutputDir.appendingPathComponent("test_story.txt")
    
    // 检查故事文件是否存在
    guard FileManager.default.fileExists(atPath: storyFilePath.path) else {
        return (false, "故事文件不存在", "", 0)
    }
    
    // 读取故事内容
    guard let storyContent = try? String(contentsOf: storyFilePath, encoding: .utf8) else {
        return (false, "无法读取故事内容", "", 0)
    }
    
    // 计算字数
    let wordCount = storyContent.count
    
    // 提取标题（假设标题是第一行）
    let lines = storyContent.components(separatedBy: .newlines)
    let title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知标题"
    
    return (true, "故事生成成功，标题：\(title)，字数：\(wordCount)", title, wordCount)
}

// 分析语音合成测试结果
func analyzeSpeechSynthesisResults(config: IntegrationConfig) -> (success: Bool, details: String) {
    let speechFilePath = config.testOutputDir.appendingPathComponent("test_speech.mp3")
    let localSpeechFilePath = config.testOutputDir.appendingPathComponent("test_speech_local.txt")
    
    // 检查语音文件是否存在
    if FileManager.default.fileExists(atPath: speechFilePath.path) {
        // 获取文件大小
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: speechFilePath.path),
              let fileSize = fileAttributes[.size] as? Int else {
            return (false, "无法获取语音文件大小")
        }
        
        // 检查文件大小是否合理（至少10KB）
        if fileSize < 10 * 1024 {
            return (false, "语音文件大小异常：\(fileSize) 字节")
        }
        
        // 计算语音时长（粗略估计：128kbps MP3 约 1MB = 60秒）
        let estimatedDuration = Double(fileSize) / (128 * 1024 / 8) // 秒
        
        return (true, "语音合成成功，文件大小：\(fileSize / 1024) KB，估计时长：\(String(format: "%.1f", estimatedDuration)) 秒")
    } 
    // 检查本地TTS文件是否存在
    else if FileManager.default.fileExists(atPath: localSpeechFilePath.path) {
        // 获取文件大小
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: localSpeechFilePath.path),
              let fileSize = fileAttributes[.size] as? Int else {
            return (false, "无法获取本地TTS文件大小")
        }
        
        return (true, "使用本地TTS成功，文件大小：\(fileSize) 字节")
    }
    else {
        return (false, "语音文件不存在")
    }
}

// 分析缓存机制测试结果
func analyzeCacheMechanismResults(config: IntegrationConfig) -> (success: Bool, details: String) {
    let cacheDir = config.testOutputDir.appendingPathComponent("cache")
    
    // 检查缓存目录是否存在
    guard FileManager.default.fileExists(atPath: cacheDir.path) else {
        return (false, "缓存目录不存在")
    }
    
    // 检查缓存目录中是否有文件
    do {
        let cacheFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        if cacheFiles.isEmpty {
            return (false, "缓存目录为空")
        }
        
        return (true, "缓存机制测试成功，缓存文件数量：\(cacheFiles.count)")
    } catch {
        return (false, "无法读取缓存目录：\(error.localizedDescription)")
    }
}

// MARK: - 集成建议生成

// 生成StoryService集成建议
func generateStoryServiceIntegrationSuggestions(config: IntegrationConfig, storyTestSuccess: Bool) -> String {
    let storyServicePath = config.appSourceDir.appendingPathComponent("Services/Story/StoryService.swift")
    
    // 检查StoryService文件是否存在
    guard FileManager.default.fileExists(atPath: storyServicePath.path) else {
        return "⚠️ 无法找到StoryService文件，请手动创建"
    }
    
    var suggestions = [String]()
    
    if storyTestSuccess {
        suggestions.append("✅ 故事生成API测试成功，建议将测试脚本中的请求逻辑集成到StoryService中")
        suggestions.append("✅ 建议在StoryService中添加错误处理和重试机制")
        suggestions.append("✅ 建议在StoryService中添加缓存机制，减少API调用次数")
    } else {
        suggestions.append("⚠️ 故事生成API测试失败，请检查API密钥和网络连接")
        suggestions.append("⚠️ 建议在StoryService中添加错误处理和重试机制")
        suggestions.append("⚠️ 建议添加本地故事库作为备选方案")
    }
    
    return suggestions.joined(separator: "\n")
}

// 生成SpeechService集成建议
func generateSpeechServiceIntegrationSuggestions(config: IntegrationConfig, speechTestSuccess: Bool) -> String {
    let speechServicePath = config.appSourceDir.appendingPathComponent("Services/Speech/SpeechService.swift")
    
    // 检查SpeechService文件是否存在
    guard FileManager.default.fileExists(atPath: speechServicePath.path) else {
        return "⚠️ 无法找到SpeechService文件，请手动创建"
    }
    
    var suggestions = [String]()
    
    if speechTestSuccess {
        suggestions.append("✅ 语音合成测试成功，建议将测试脚本中的请求逻辑集成到SpeechService中")
        suggestions.append("✅ 建议在SpeechService中添加缓存机制，减少API调用次数")
        suggestions.append("✅ 建议在SpeechService中添加错误处理和本地TTS回退机制")
    } else {
        suggestions.append("⚠️ 语音合成API测试失败，请检查API密钥和网络连接")
        suggestions.append("⚠️ 建议在SpeechService中添加本地TTS作为备选方案")
        suggestions.append("⚠️ 建议添加USE_LOCAL_TTS_BY_DEFAULT配置选项，允许用户选择默认使用本地TTS")
    }
    
    return suggestions.joined(separator: "\n")
}

// 生成下一步建议
func generateNextStepsSuggestions(storyTestSuccess: Bool, speechTestSuccess: Bool, cacheTestSuccess: Bool) -> String {
    var suggestions = [String]()
    
    if storyTestSuccess && speechTestSuccess && cacheTestSuccess {
        suggestions.append("1. 将API集成逻辑合并到应用代码中")
        suggestions.append("2. 添加用户界面，允许用户选择故事主题和角色")
        suggestions.append("3. 实现故事播放功能，包括语音播放和文本显示")
        suggestions.append("4. 添加故事收藏和分享功能")
        suggestions.append("5. 实现离线模式，允许用户在无网络环境下使用应用")
    } else {
        if !storyTestSuccess {
            suggestions.append("1. 修复故事生成API集成问题")
        }
        if !speechTestSuccess {
            suggestions.append("2. 修复语音合成API集成问题或完善本地TTS功能")
        }
        if !cacheTestSuccess {
            suggestions.append("3. 修复缓存机制问题")
        }
        suggestions.append("4. 重新运行API集成测试")
    }
    
    return suggestions.joined(separator: "\n")
}

// MARK: - 报告生成

// 生成API集成测试报告
func generateApiIntegrationReport(config: IntegrationConfig) -> String {
    // 分析测试结果
    let (storyTestSuccess, storyDetails, storyTitle, storyWordCount) = analyzeStoryGenerationResults(config: config)
    let (speechTestSuccess, speechDetails) = analyzeSpeechSynthesisResults(config: config)
    let (cacheTestSuccess, cacheDetails) = analyzeCacheMechanismResults(config: config)
    
    // 生成集成建议
    let storyServiceSuggestions = generateStoryServiceIntegrationSuggestions(config: config, storyTestSuccess: storyTestSuccess)
    let speechServiceSuggestions = generateSpeechServiceIntegrationSuggestions(config: config, speechTestSuccess: speechTestSuccess)
    let nextStepsSuggestions = generateNextStepsSuggestions(storyTestSuccess: storyTestSuccess, speechTestSuccess: speechTestSuccess, cacheTestSuccess: cacheTestSuccess)
    
    // 构建报告
    let report = """
    # 宝宝故事应用 API 集成测试报告
    
    ## 测试结果摘要
    
    | 测试项目 | 结果 | 详情 |
    | --- | --- | --- |
    | 故事生成 | \(storyTestSuccess ? "✅ 成功" : "❌ 失败") | \(storyDetails) |
    | 语音合成 | \(speechTestSuccess ? "✅ 成功" : "❌ 失败") | \(speechDetails) |
    | 缓存机制 | \(cacheTestSuccess ? "✅ 成功" : "❌ 失败") | \(cacheDetails) |
    
    ## 故事生成结果
    
    - **标题**: \(storyTitle)
    - **字数**: \(storyWordCount)
    
    ## 集成建议
    
    ### StoryService 集成
    
    \(storyServiceSuggestions)
    
    ### SpeechService 集成
    
    \(speechServiceSuggestions)
    
    ## 下一步
    
    \(nextStepsSuggestions)
    
    ---
    
    报告生成时间: \(Date())
    """
    
    return report
}

// 保存报告到文件
func saveReportToFile(report: String, outputPath: URL) -> Bool {
    do {
        try report.write(to: outputPath, atomically: true, encoding: .utf8)
        print("报告已保存至: \(outputPath.path)")
        return true
    } catch {
        print("保存报告失败: \(error.localizedDescription)")
        return false
    }
}

// MARK: - 主函数

func main() {
    print("开始生成API集成测试报告...")
    
    // 创建配置
    let config = IntegrationConfig.createDefault()
    
    // 生成报告
    let report = generateApiIntegrationReport(config: config)
    
    // 保存报告
    if saveReportToFile(report: report, outputPath: config.reportOutputPath) {
        print("API集成测试报告生成完成")
    } else {
        print("API集成测试报告生成失败")
    }
}

// 执行主函数
main() 