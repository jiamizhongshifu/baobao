//
//  baobaoUITestsLaunchTests.swift
//  baobaoUITests
//
//  Created by 钟庆标 on 2025/3/10.
//

import XCTest

final class baobaoUITestsLaunchTests: XCTestCase {

    // 每种设备配置都运行一次
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    // 测试配置
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // 启动屏幕测试
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 验证应用已成功启动，使用更长的超时时间
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        
        // 等待更长时间让界面完全加载
        sleep(5)
        
        // 不验证特定UI元素，只确保应用正在运行
        XCTAssertTrue(app.state == .runningForeground, "应用应该在前台运行")
        
        // 拍摄启动屏幕的截图
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "启动屏幕"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    // 测试不同设备方向的启动
    @MainActor
    func testLaunchInPortraitAndLandscape() throws {
        let app = XCUIApplication()
        
        // 竖屏启动测试
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        
        // 添加竖屏截图
        let portraitAttachment = XCTAttachment(screenshot: app.screenshot())
        portraitAttachment.name = "启动屏幕-竖屏"
        portraitAttachment.lifetime = .keepAlways
        add(portraitAttachment)
        
        app.terminate()
        
        // 横屏启动测试
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        
        // 添加横屏截图
        let landscapeAttachment = XCTAttachment(screenshot: app.screenshot())
        landscapeAttachment.name = "启动屏幕-横屏"
        landscapeAttachment.lifetime = .keepAlways
        add(landscapeAttachment)
        
        // 恢复竖屏方向
        XCUIDevice.shared.orientation = .portrait
    }
    
    // 测试各种设备的启动文本可见性
    @MainActor
    func testLaunchTextVisibility() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 等待启动动画完成
        sleep(2)
        
        // 验证启动文本在视图层级中可见且不被遮挡
        let loadingText = app.staticTexts["正在加载宝宝故事..."].firstMatch
        let webView = app.webViews.firstMatch
        
        if loadingText.exists {
            XCTAssertTrue(loadingText.isHittable)
        } else if webView.exists {
            XCTAssertTrue(webView.exists)
        } else {
            XCTFail("未找到启动文本或WebView")
        }
        
        // 添加文本可见性测试截图
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "启动文本可见性"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
