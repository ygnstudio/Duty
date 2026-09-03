# 贡献指南

感谢你对 **Duty** 的兴趣！Duty 是一个 macOS 菜单栏 app，用于管理和恢复默认文件关联。这份指南告诉你如何参与贡献。

## 行为准则

参与本项目即表示你同意遵守 [Code of Conduct](./CODE_OF_CONDUCT.md)。请在所有交流中保持尊重。

## 我能贡献什么

- 报 Bug / 提功能建议 → 直接开 [Issue](../../issues)
- 修 Bug / 加功能 → 提 Pull Request
- 改文档 / 改示例 → 同样欢迎提 PR
- 帮忙回答其他用户的 Issue → 任何用户都能参与

## 提 Issue 前

1. 先在 [Issues](../../issues) 搜索关键词，避免重复。
2. 选对应的 Issue 模板（Bug 报告 / 功能建议 / 提问）。
3. Bug 报告请尽量给出复现步骤、macOS 版本、Duty 版本和截图/日志。
4. 涉及"默认应用关联"不生效的，请说明是按 **文件类型**（扩展名 / UTI）还是按 **单个文件** 锁定，两类问题机制不同。

## 本地开发

### 环境要求

- **macOS 13+**（部署目标）
- Xcode 15+ / Swift 5.9+（命令行工具：`xcode-select --install`）
- 运行时依赖：[`duti`](https://github.com/moretension/duti) 1.5.4（`brew install duti`）

### 克隆与构建

```bash
git clone https://github.com/ygnstudio/Duty.git
cd Duty
swift build -c release
```

构建 `.app` 包：

```bash
./build_app.sh
```

产物在 `build/Duty.app` 或 `./.build/release/Duty`。

### 测试

Duty 暂无自动化测试。改动请在菜单栏实际操作验证（设置默认应用、查询、恢复）。

> 注意：macOS 26 上 launchservicesd 缓存单文件 OpenWith 绑定，公开 API（`NSWorkspace.setDefaultApplication` / `LSSetDefaultRoleHandlerForContentType`）对单文件绑定可能无效，请勿把单文件场景当作"必须修复"的回归。

## 提 Pull Request

1. Fork 本仓库
2. 从 `main` 创建分支：`git checkout -b feat/my-feature`
3. 本地提交，commit message 遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)：
   - `feat: 新增 X` / `fix: 修复 Y` / `docs: 改文档` / `refactor: 重构`
4. 如果改了用户可见行为，更新 [`CHANGELOG.md`](./CHANGELOG.md) 的 `[Unreleased]` 部分
5. 推到自己的 fork：`git push origin feat/my-feature`
6. 在 GitHub 上发起 PR 到 `main`，按 PR 模板勾选自检清单

## 代码风格

- Swift 代码遵循 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- 没有 lint 配置时，新代码与周边风格保持一致
- macOS 14+ API **必须**用 `#available` 兜底（部署目标 13+）
- 优先使用 SwiftUI；不要裸用 macOS 14+ 才有的 API

## 版本与发布

- 版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)
- 变更记录见 [`CHANGELOG.md`](./CHANGELOG.md)
- 发布由维护者统一进行，贡献者只需保证 PR 干净、CHANGELOG 已更新

## 联系

- Issue 优先：[GitHub Issues](../../issues)
- 邮箱：[markwalsh6809@gmail.com](mailto:markwalsh6809@gmail.com)
- GitHub 主页：<https://github.com/ygnstudio>
