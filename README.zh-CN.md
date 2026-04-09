# GestureFire

用于键盘快捷键触发的自定义 macOS 触控板手势工具。

[English](README.md) | [日本語](README.ja.md)

GestureFire 是一个 macOS 菜单栏应用，用来把自定义触控板手势映射为键盘快捷键。当前支持 TipTap、角落点击、多指点击、多指滑动，并且已经具备基于 replay 的回归测试能力与后续调参基础。

## 这个项目解决什么问题

macOS 自带的触控板手势是固定的。GestureFire 面向那些想要更多自定义能力的人：

- 用自定义手势触发应用快捷键
- 使用角落点击、多指点击、多指滑动等额外手势
- 针对自己的手势习惯调节灵敏度
- 用可回放、可测试的方式迭代识别逻辑

目前这个项目已经达到 MVP 阶段。

## 当前已经具备的能力

- 支持 **19 种手势**
- 支持 **4 类 recognizer**：`TipTap`、`CornerTap`、`MultiFingerTap`、`MultiFingerSwipe`
- 菜单栏应用 + 设置界面
- 首次启动向导与练习流程
- 诊断、日志、声音反馈、状态面板、开机启动
- **215 个测试 / 44 个测试套件**
- **19 个 replay fixture** 用于回归保护

## 手势家族

- **TipTap**：4 个方向
- **Corner Tap**：4 个角落
- **Multi-Finger Tap**：3 指 / 4 指 / 5 指点击
- **Multi-Finger Swipe**：3 指 / 4 指的 4 个方向滑动

## 当前 MVP 状态

GestureFire 已经是一个合格的 MVP：

- 核心识别链路已经成立
- 已完成真实设备验收
- 已有高级灵敏度参数
- 已有 accessibility 基线
- 已建立 replay 驱动的回归保护

当前已知限制：

- 多指滑动对手指排布仍然稍微敏感
- macOS 系统手势可能会与 3 指 / 4 指滑动冲突
- onboarding 的 practice 目前主要覆盖 TipTap

这些都已经进入后续阶段规划，不阻塞 MVP 定义。

## 快速开始

### 要求

- macOS 14+
- Xcode 安装在 `/Applications/Xcode.app`

### 构建

```bash
swift build
./scripts/build-app.sh debug
open dist/GestureFire.app
```

Release 构建：

```bash
./scripts/build-app.sh release
```

### 测试

Swift Testing 依赖 Xcode 自带工具链：

```bash
./scripts/test.sh
```

等价命令：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## 文档

- [ROADMAP](ROADMAP.md)
- [REVIEW](REVIEW.md)
- [Architecture Overview](docs/architecture/overview.md)
- [Phase 3 Spec](docs/phases/PHASE-3.md)
- [Phase 3 Acceptance](docs/PHASE-3-ACCEPTANCE.md)

## 路线图概览

- Phase 1: Core Loop — 已完成
- Phase 1H: Hardening — 已完成
- Phase 1.5: Onboarding + Verification + Sample Capture — 已完成
- Phase 2: Experience Polish — 已完成
- Phase 2.5: UI Structure Polish — 已完成
- Phase 2.6: Visual Polish — 已完成
- Phase 3: More Gestures — 已完成
- Phase 4: Smart Tuning — 下一阶段
- Phase 5: Personalization — 规划中

## 技术说明

GestureFire 使用 OpenMultitouchSupport 获取原始触控板输入。识别层通过 `TouchFrame` 抽象与 OMS 解耦，这也是后续 replay、校准与调参能够成立的基础。
