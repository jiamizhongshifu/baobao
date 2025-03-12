# 宝宝故事App测试

本目录包含宝宝故事应用的所有测试用例。

## 测试结构

```
Tests/
  ├── BaoBaoTests/               # 主要单元测试目录
  │    ├── APITests.swift        # API接口测试
  │    ├── CacheManagerTests.swift  # 缓存管理器测试
  │    ├── ConfigurationServiceTests.swift  # 配置服务测试
  │    ├── NetworkManagerTests.swift  # 网络管理器测试
  │    ├── OfflineManagerTests.swift  # 离线管理器测试
  │    ├── SpeechServiceTests.swift   # 语音服务测试
  │    ├── StoryServiceTests.swift    # 故事服务测试
  │    └── Resources/            # 测试资源文件
  │
  ├── CloudKitSyncTests.swift    # CloudKit同步功能测试
  ├── CloudKitStressTest.swift   # CloudKit压力测试
  └── TestConfig.xcconfig        # 测试配置文件
```

## 运行测试

在Xcode中，可以使用Command+U快捷键运行所有测试，或者在测试导航器中选择特定的测试运行。

标准测试目录 `baobaoTests` 中包含一个 `AllTests.swift` 文件，该文件集成了我们自定义 `Tests` 目录中的测试。

## 添加新测试

1. 在适当的目录下创建新的测试文件
2. 在新文件中导入XCTest和应用模块
3. 创建继承自XCTestCase的测试类
4. 实现setUp和tearDown方法（如需要）
5. 添加以"test"开头的测试方法

示例:

```swift
import XCTest
@testable import BaoBao

final class NewFeatureTests: XCTestCase {
    
    override func setUpWithError() throws {
        // 测试准备
    }
    
    override func tearDownWithError() throws {
        // 测试清理
    }
    
    func testNewFeature() throws {
        // 测试代码
        XCTAssertTrue(true)
    }
} 