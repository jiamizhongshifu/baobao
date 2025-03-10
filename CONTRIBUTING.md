# 贡献指南

感谢您考虑为宝宝故事项目做出贡献！这个文档将指导您如何参与项目开发。

## 开发流程

1. Fork 这个仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的改动 (`git commit -m 'feat: 添加某个特性'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## 提交规范

我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范，提交信息格式如下：

```
<type>: <description>

[optional body]

[optional footer]
```

类型（type）必须是以下之一：

- feat: 新特性
- fix: 修复bug
- docs: 文档更新
- style: 代码格式（不影响代码运行的变动）
- refactor: 重构（既不是新增功能，也不是修改bug的代码变动）
- perf: 性能优化
- test: 增加测试
- chore: 构建过程或辅助工具的变动

## 代码风格

- 遵循 Swift 官方风格指南
- 使用4个空格进行缩进
- 确保没有拼写错误
- 添加适当的注释
- 保持代码简洁明了

## 测试要求

- 所有新功能都必须包含测试
- 所有修复都必须包含测试
- 保持测试覆盖率不降低

## Pull Request 流程

1. 确保您的 PR 包含以下内容：
   - 清晰的标题和描述
   - 如果适用，包含截图或录屏
   - 更新相关文档
   
2. PR 会在以下情况下被审查：
   - 通过所有自动化测试
   - 代码风格符合要求
   - 至少有一个维护者审查通过

## 分支策略

- `main`: 主分支，保持稳定
- `develop`: 开发分支，用于集成功能
- `feature/*`: 特性分支，用于开发新功能
- `bugfix/*`: 修复分支，用于修复问题
- `release/*`: 发布分支，用于版本发布

## 版本发布

我们使用语义化版本号：

- 主版本号：不兼容的 API 修改
- 次版本号：向下兼容的功能性新增
- 修订号：向下兼容的问题修正

## 问题反馈

- 使用 GitHub Issues 进行问题反馈
- 清晰地描述问题
- 提供复现步骤
- 如果可能，提供错误日志

## 安全问题

如果您发现任何安全漏洞，请不要在 GitHub Issues 中公开，而是直接联系维护者。

## 许可证

通过提交 PR，您同意您的贡献将使用与项目相同的许可证。 