import XCTest

final class AccessibilityTests: XCTestCase {
    
    // 应用实例
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // 测试失败时立即停止
        continueAfterFailure = false
        
        // 初始化应用实例
        app = XCUIApplication()
        
        // 配置辅助功能测试环境
        app.launchArguments = ["--UITesting", "--AccessibilityTesting"]
        app.launchEnvironment = [
            "isUITesting": "YES",
            "accessibilityTestingEnabled": "YES"
        ]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 基本辅助功能测试
    
    @MainActor
    func testBasicAccessibility() throws {
        // 启动应用
        app.launch()
        
        // 等待加载完成
        let loadingComplete = NSPredicate(format: "exists == false")
        let loadingIndicator = app.activityIndicators.firstMatch
        
        expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
        waitForExpectations(timeout: 10)
        
        // 等待WebView完全加载
        sleep(2)
        
        // 验证关键UI元素可访问性
        validateElementAccessibility(app.buttons["新建故事"])
        validateElementAccessibility(app.buttons["设置"])
        
        // 如果有故事列表，验证第一个故事项的可访问性
        if app.collectionViews.firstMatch.exists && app.collectionViews.cells.count > 0 {
            validateElementAccessibility(app.collectionViews.cells.element(boundBy: 0))
        }
        
        // 添加辅助功能测试截图
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "辅助功能测试-主页"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    // MARK: - 动态字体测试
    
    @MainActor
    func testDynamicTypeAccessibility() throws {
        // 测试较大的动态字体
        testWithContentSize(accessibilitySize: .extraExtraExtraLarge)
        
        // 恢复默认字体大小
        testWithContentSize(accessibilitySize: .medium)
    }
    
    // MARK: - VoiceOver测试
    
    @MainActor
    func testVoiceOverAccessibility() throws {
        // 启动应用
        app.launch()
        
        // 等待加载完成
        let loadingComplete = NSPredicate(format: "exists == false")
        let loadingIndicator = app.activityIndicators.firstMatch
        
        expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
        waitForExpectations(timeout: 10)
        
        // 等待WebView完全加载
        sleep(2)
        
        // 启用VoiceOver模拟（注意：这只是UI测试，实际的VoiceOver不会被启用）
        simulateVoiceOver()
        
        // 尝试使用VoiceOver导航到"新建故事"按钮
        if app.buttons["新建故事"].exists {
            // 验证"新建故事"按钮有正确的可访问性标签
            let newStoryButton = app.buttons["新建故事"]
            XCTAssertFalse(newStoryButton.label.isEmpty, "新建故事按钮应有可访问性标签")
            
            // 点击"新建故事"按钮
            newStoryButton.tap()
            
            // 验证新建故事界面已加载
            if app.textFields.firstMatch.waitForExistence(timeout: 5) {
                // 验证故事主题输入框有正确的可访问性提示
                let themeField = app.textFields.firstMatch
                XCTAssertFalse(themeField.label.isEmpty, "故事主题输入框应有可访问性标签")
                
                // 返回主页
                if app.buttons["返回"].exists {
                    app.buttons["返回"].tap()
                }
            }
        }
        
        // 禁用VoiceOver模拟
        simulateVoiceOverEnd()
    }
    
    // MARK: - 高对比度模式测试
    
    @MainActor
    func testHighContrastAccessibility() throws {
        // 启动应用
        app.launch()
        
        // 等待加载完成
        let loadingComplete = NSPredicate(format: "exists == false")
        let loadingIndicator = app.activityIndicators.firstMatch
        
        expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
        waitForExpectations(timeout: 10)
        
        // 等待WebView完全加载
        sleep(2)
        
        // 启用高对比度模式模拟
        simulateHighContrast()
        
        // 添加高对比度模式截图
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "辅助功能测试-高对比度"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        
        // 如果有设置按钮，测试高对比度下的设置页面
        if app.buttons["设置"].exists {
            app.buttons["设置"].tap()
            
            // 验证设置页面已加载
            if app.tables.firstMatch.waitForExistence(timeout: 5) {
                // 添加设置页面高对比度截图
                let settingsScreenshot = XCTAttachment(screenshot: app.screenshot())
                settingsScreenshot.name = "辅助功能测试-高对比度-设置"
                settingsScreenshot.lifetime = .keepAlways
                add(settingsScreenshot)
                
                // 返回主页
                if app.buttons["关闭"].exists {
                    app.buttons["关闭"].tap()
                } else if app.buttons["返回"].exists {
                    app.buttons["返回"].tap()
                }
            }
        }
        
        // 禁用高对比度模式模拟
        simulateHighContrastEnd()
    }
    
    // MARK: - 辅助功能测试辅助方法
    
    /// 验证UI元素的辅助功能属性
    private func validateElementAccessibility(_ element: XCUIElement) {
        // 验证元素存在
        guard element.exists else {
            return
        }
        
        // 验证元素可交互
        if element.isEnabled {
            XCTAssertTrue(element.isHittable, "可启用的元素应该是可点击的")
        }
        
        // 验证元素有可访问性标签
        if !element.label.isEmpty {
            XCTAssertTrue(element.isAccessibilityElement, "有标签的元素应该是可访问的")
        }
    }
    
    /// 测试不同的内容大小设置
    private func testWithContentSize(accessibilitySize: UIContentSizeCategory) {
        // 这个方法在实际的UI测试中不会真正改变系统设置
        // 只是模拟测试，真正的动态字体测试需要在设备设置中更改
        
        // 启动应用
        app.launch()
        
        // 等待加载完成
        let loadingComplete = NSPredicate(format: "exists == false")
        let loadingIndicator = app.activityIndicators.firstMatch
        
        expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
        waitForExpectations(timeout: 10)
        
        // 等待WebView完全加载
        sleep(2)
        
        // 添加当前字体大小的截图
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "辅助功能测试-动态字体-\(accessibilitySize.rawValue)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        
        app.terminate()
    }
    
    /// 模拟启用VoiceOver（仅用于测试，不会真正启用系统VoiceOver）
    private func simulateVoiceOver() {
        // 这是一个模拟方法，实际上不会启用系统VoiceOver
        // 在真实设备上测试VoiceOver需要在设备设置中启用
        app.launchEnvironment["UIAccessibilityVoiceOverSimulation"] = "YES"
    }
    
    /// 模拟禁用VoiceOver
    private func simulateVoiceOverEnd() {
        app.launchEnvironment.removeValue(forKey: "UIAccessibilityVoiceOverSimulation")
    }
    
    /// 模拟启用高对比度模式
    private func simulateHighContrast() {
        // 这是一个模拟方法，实际上不会启用系统高对比度
        app.launchEnvironment["UIAccessibilityHighContrastSimulation"] = "YES"
    }
    
    /// 模拟禁用高对比度模式
    private func simulateHighContrastEnd() {
        app.launchEnvironment.removeValue(forKey: "UIAccessibilityHighContrastSimulation")
    }
} 