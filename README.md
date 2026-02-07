# LoneSword 响应式网页浏览器 App
用AI对抗AI时代的熵增！
一个为 iPad 和 iPhone 设计的现代响应式网页浏览器应用，集成了 AI 助手功能。支持横竖屏自适应布局，采用现代扁平设计风格。

## 🎯 项目特点

### 核心功能
- 🌐 **网页浏览**：基于 WKWebView 的完整浏览功能
- 📱 **响应式设计**：自动适应横竖屏布局
- 🤖 **AI 助手**：集成阿里云通义千问 API，支持识别与总结
- 🎤 **语音输入**：支持中文语音转文本
- 📊 **浏览历史**：持久化存储浏览记录
- ⚙️ **AI洞察开关**：可一键关闭 AI 面板并收缩布局

### 设计理念
- ✨ 现代扁平风格，浅色主题
- 🎨 蓝色强调色，专业简约
- 👆 触屏优化，所有按钮 ≥44×44pt
- ⚡ 流畅过渡，无缝屏幕旋转

## 📐 布局设计

### 横屏模式（Landscape）
```
┌──────────────────────────────────┐
│ 工具栏（后退/前进/URL/Slash）      │
├──────────────────────┬────────────┤
│                      │            │
│                      │   AI助手   │
│   WebView (2/3)      │   (1/3)    │
│                      │            │
└──────────────────────┴────────────┘
```

### 竖屏模式（Portrait）
```
┌──────────────────────────────────┐
│ 工具栏（后退/前进/URL/Slash）     │
├──────────────────────────────────┤
│                                  │
│        WebView (2/3)             │
│                                  │
├──────────────────────────────────┤
│         AI助手 (1/3)             │
└──────────────────────────────────┘
```

## 📁 项目结构

```
LoneSword/
├── Models/                          # 数据模型
│   ├── BrowserHistory.swift        # 浏览历史
│   ├── AISettings.swift            # AI 功能设置
│   └── Item.swift                  # 基础项目模型
├── ViewModels/                      # 视图模型
│   ├── BrowserViewModel.swift      # 浏览器逻辑
│   └── AIAssistantViewModel.swift  # AI 逻辑
├── Views/                           # UI 组件
│   ├── ContentView.swift           # 主视图（响应式布局）
│   ├── BrowserToolbarView.swift    # 浏览器工具栏
│   ├── WebViewContainer.swift      # WebView 容器
│   └── AIAssistantView.swift       # AI 助手面板
├── Services/                        # 业务服务
│   ├── QwenService.swift           # Qwen API
│   ├── SpeechRecognitionService.swift # 语音识别
│   ├── StoreKitManager.swift       # 订阅与内购
│   └── KeychainService.swift       # API Key 安全存储
├── LoneSwordApp.swift              # 应用入口
├── Assets.xcassets/                # 图片资源
└── README.md                       # 此文件
```

## 🚀 快速开始

### 前置需求
- iOS 16.0 或更高版本
- Xcode 15.0 或更高版本
- Swift 5.9 或更高版本

### 安装和运行

1. **打开项目**
   ```bash
   cd /Users/liuhongfeng/Desktop/code/LoneSword/LoneSword
   open LoneSword.xcodeproj
   ```

2. **选择目标设备**
   - 在 Xcode 中选择 iPhone 或 iPad 模拟器

3. **运行应用**
   - 按 `Cmd + R` 或点击 Run 按钮

4. **测试响应式布局**
   - 在模拟器中旋转设备（`Cmd + ←/→`）观察布局自动切换

## 📋 实现状态

### ✅ 已完成

#### 网页视图
- ✅ WebView 初始加载与渲染
- ✅ URL 智能处理（自动补全协议）
- ✅ 加载进度条实时显示
- ✅ 前进/后退导航（基于持久化历史）
- ✅ 地址栏编辑与 Slash 加载

#### 响应式布局
- ✅ 横屏：2/3 网页 + 1/3 AI
- ✅ 竖屏：2/3 网页 + 1/3 AI
- ✅ AI洞察关闭时自动收缩为全屏 WebView
- ✅ 全屏显示与自动旋转

#### AI 助手面板
- ✅ 标题"AI洞察"与设置入口
- ✅ 功能开关（识别AI生成 / 自动总结）
- ✅ 富文本显示区与对话记录
- ✅ 文本输入与语音输入
- ✅ AI洞察总开关与设置中控制

### ✅ 已集成

#### WebView 高级功能
- ✅ 内链点击更新地址栏并触发 AI 重置
- ✅ 下拉刷新
- ✅ 完整历史管理（最多 100 条）

#### Slash 按钮功能
- ✅ 双击加载首页
- ✅ 单击加载地址栏

#### AI 集成
- ✅ Qwen API 集成与私钥校验
- ✅ 网页内容分析与总结
- ✅ AI 响应渲染

#### 语音输入
- ✅ 中文语音识别
- ✅ 麦克风权限处理
- ✅ 结果自动填充

## 🎨 设计规范

| 元素 | 规范 |
|------|------|
| 主背景色 | #F8F8F8（浅灰） |
| 卡片背景 | #FFFFFF（白色） |
| 强调色 | #007AFF（蓝色） |
| 进度条颜色 | #007AFF（蓝色） |
| 橙色标签 | #FF9500（橙色，第二阶段使用） |
| 禁用文本 | #A0A0A0（浅灰） |
| 工具栏高度 | 56pt |
| 进度条高度 | 2px |
| 最小触点 | 44×44pt |

## 🔧 技术栈

- **UI 框架**：SwiftUI
- **网页视图**：WebKit (WKWebView)
- **数据持久化**：SwiftData
- **API 集成**：Qwen
- **语音识别**：Speech Framework
- **开发语言**：Swift 5.9+

## 📝 代码风格

- 使用 MVVM 架构模式
- View 层：SwiftUI 组件
- ViewModel 层：@ObservableObject 管理状态
- Model 层：SwiftData @Model 属性
- 命名规范：驼峰式（camelCase）
- 注释：中英文混合，代码前注释说明逻辑

## 🐛 已知问题

目前无已知问题（如发现请反馈）。

## 📞 联系信息

- 开发者：LiuHongfeng
- 项目开始日期：2025-10-18
- 状态：🔄 开发中

## 📄 许可证

此项目为私人项目，未公开发布。

---

**最后更新**: 2026-02-07 | **状态**: Active Development
