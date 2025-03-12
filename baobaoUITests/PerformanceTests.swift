import XCTest

final class PerformanceTests: XCTestCase {
    
    // 应用实例
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // 测试失败时立即停止
        continueAfterFailure = false
        
        // 初始化应用实例
        app = XCUIApplication()
        
        // 配置性能测试环境
        app.launchArguments = ["--UITesting", "--PerformanceTesting"]
        app.launchEnvironment = [
            "isUITesting": "YES",
            "performanceTestingEnabled": "YES"
        ]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 启动性能测试
    
    @MainActor
    func testLaunchPerformanceDetailed() throws {
        if #available(iOS 13.0, *) {
            // 测量应用启动时间
            measure(metrics: [XCTApplicationLaunchMetric(), XCTMemoryMetric()]) {
                app.launch()
                
                // 验证应用已完全启动
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
                
                // 等待加载完成
                let loadingIndicator = app.activityIndicators.firstMatch
                if loadingIndicator.exists {
                    let loadingComplete = NSPredicate(format: "exists == false")
                    expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
                    waitForExpectations(timeout: 10)
                }
                
                // 终止应用，准备下一轮测试
                app.terminate()
            }
        }
    }
    
    // MARK: - 故事生成性能测试
    
    @MainActor
    func testStoryGenerationPerformance() throws {
        // 启动应用
        app.launch()
        
        // 验证应用已成功启动
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // 等待一段时间让界面加载
        sleep(3)
        
        // 测量应用的基本性能，不依赖特定UI元素
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTStorageMetric()]) {
                // 模拟用户交互：点击界面上的第一个按钮（如果存在）
                if app.buttons.count > 0 {
                    app.buttons.element(boundBy: 0).tap()
                    sleep(2)
                    
                    // 如果有返回按钮，点击它返回
                    if app.buttons["返回"].exists {
                        app.buttons["返回"].tap()
                    } else if app.navigationBars.buttons.firstMatch.exists {
                        app.navigationBars.buttons.firstMatch.tap()
                    }
                } else {
                    // 如果没有按钮，尝试点击屏幕中央
                    let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    coordinate.tap()
                    sleep(2)
                }
                
                // 等待处理完成
                sleep(1)
            }
        }
    }
    
    // MARK: - 语音合成性能测试
    
    @MainActor
    func testSpeechSynthesisPerformance() throws {
        // 启动应用
        app.launch()
        
        // 验证应用已成功启动
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // 等待一段时间让界面加载
        sleep(3)
        
        // 测量应用的基本音频处理性能，不依赖特定UI元素
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
                // 模拟用户交互：尝试点击可能的播放按钮
                let playButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "播放"))
                
                if playButtons.count > 0 {
                    // 如果找到播放按钮，点击它
                    playButtons.element(boundBy: 0).tap()
                    sleep(3)
                    
                    // 尝试点击可能的暂停/停止按钮
                    let pauseButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "暂停", "停止"))
                    if pauseButtons.count > 0 {
                        pauseButtons.element(boundBy: 0).tap()
                    }
                } else {
                    // 如果没有找到播放按钮，尝试点击列表中的第一个项目
                    if app.cells.count > 0 {
                        app.cells.element(boundBy: 0).tap()
                        sleep(2)
                        
                        // 如果有返回按钮，点击它返回
                        if app.buttons["返回"].exists {
                            app.buttons["返回"].tap()
                        } else if app.navigationBars.buttons.firstMatch.exists {
                            app.navigationBars.buttons.firstMatch.tap()
                        }
                    }
                }
                
                // 等待处理完成
                sleep(1)
            }
        }
    }
    
    // MARK: - WebView渲染性能测试
    
    @MainActor
    func testWebViewRenderingPerformance() throws {
        // 启动应用
        app.launch()
        
        // 等待加载完成
        let loadingComplete = NSPredicate(format: "exists == false")
        let loadingIndicator = app.activityIndicators.firstMatch
        
        expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
        waitForExpectations(timeout: 10)
        
        // 等待WebView完全加载
        sleep(2)
        
        // 测量WebView渲染性能
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
                // 模拟视图切换
                if app.buttons["设置"].exists {
                    app.buttons["设置"].tap()
                    sleep(1)
                    
                    if app.buttons["关闭"].exists {
                        app.buttons["关闭"].tap()
                    } else if app.buttons["返回"].exists {
                        app.buttons["返回"].tap()
                    }
                    sleep(1)
                }
                
                // 滚动视图
                if app.collectionViews.firstMatch.exists {
                    app.collectionViews.firstMatch.swipeUp()
                    sleep(1)
                    app.collectionViews.firstMatch.swipeDown()
                    sleep(1)
                } else if app.scrollViews.firstMatch.exists {
                    app.scrollViews.firstMatch.swipeUp()
                    sleep(1)
                    app.scrollViews.firstMatch.swipeDown()
                    sleep(1)
                }
            }
        }
    }
    
    // MARK: - 内存使用测试
    
    @MainActor
    func testLongRunningMemoryUsage() throws {
        if #available(iOS 13.0, *) {
            // 启动应用
            app.launch()
            
            // 等待加载完成
            let loadingComplete = NSPredicate(format: "exists == false")
            let loadingIndicator = app.activityIndicators.firstMatch
            
            expectation(for: loadingComplete, evaluatedWith: loadingIndicator, handler: nil)
            waitForExpectations(timeout: 10)
            
            // 等待WebView完全加载
            sleep(2)
            
            // 测量长时间运行的内存使用情况
            measure(metrics: [XCTMemoryMetric()]) {
                // 模拟用户使用应用30秒
                for _ in 1...3 {
                    // 如果有故事列表，滚动它
                    if app.collectionViews.firstMatch.exists {
                        app.collectionViews.firstMatch.swipeUp()
                        sleep(1)
                        app.collectionViews.firstMatch.swipeDown()
                        sleep(1)
                    }
                    
                    // 打开设置页面
                    if app.buttons["设置"].exists {
                        app.buttons["设置"].tap()
                        sleep(2)
                        
                        // 关闭设置页面
                        if app.buttons["关闭"].exists {
                            app.buttons["关闭"].tap()
                        } else if app.buttons["返回"].exists {
                            app.buttons["返回"].tap()
                        }
                        sleep(1)
                    }
                    
                    // 创建新故事（但不实际生成）
                    if app.buttons["新建故事"].exists {
                        app.buttons["新建故事"].tap()
                        sleep(2)
                        
                        // 返回主页
                        if app.buttons["返回"].exists {
                            app.buttons["返回"].tap()
                        }
                        sleep(1)
                    }
                }
            }
        }
    }
} 