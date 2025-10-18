# LoneSword 快速参考卡

## 🎯 项目概览

| 项 | 值 |
|----|-----|
| **项目名** | LoneSword 响应式浏览器 App |
| **开发语言** | Swift 5.9+ |
| **最低 iOS 版本** | iOS 16.0 |
| **架构模式** | MVVM |
| **构建工具** | Xcode 15+ |
| **项目路径** | `/Users/liuhongfeng/Desktop/code/LoneSword/LoneSword` |

---

## 📁 核心文件速查

### 数据模型（Models）

| 文件 | 用途 | 行数 |
|------|------|------|
| `Models/BrowserHistory.swift` | 浏览历史记录 | 15 |
| `Models/AISettings.swift` | AI 功能开关 | 11 |
| `Item.swift` | 基础项目模型 | 18 |

### 视图模型（ViewModels）

| 文件 | 用途 | 行数 | 关键方法 |
|------|------|------|--------|
| `ViewModels/BrowserViewModel.swift` | 浏览器核心逻辑 | 130 | loadURL, goBack, goForward, stopLoading |

### 视图组件（Views）

| 文件 | 用途 | 行数 | 主要功能 |
|------|------|------|---------|
| `Views/ContentView.swift` | 主视图（响应式布局） | 63 | 横竖屏自动切换 |
| `Views/BrowserToolbarView.swift` | 浏览工具栏 | 90 | URL、导航、进度条 |
| `Views/WebViewContainer.swift` | WebView 适配器 | 26 | WKWebView 包装 |
| `Views/AIAssistantView.swift` | AI 助手面板 | 100 | 开关、显示、输入 |

### 应用配置

| 文件 | 修改 |
|------|------|
| `LoneSwordApp.swift` | 添加 BrowserHistory、AISettings 到 Schema |

---

## 🎨 设计常量

```swift
// 颜色定义
backgroundColor = Color(red: 0.98, green: 0.98, blue: 0.98)  // #F8F8F8
accentBlue = Color(red: 0, green: 0.478, blue: 1)           // #007AFF
orangeColor = Color(red: 1, green: 0.58, blue: 0)           // #FF9500
white = Color.white                                           // #FFFFFF

// 尺寸定义
toolbarHeight = 56                                             // 点
progressBarHeight = 2                                          // 点
minimumTouchSize = 44                                          // 点
```

---

## 🔄 数据流向

### 网页加载流程
```
用户输入 URL 
  ↓
TextField 更新 urlInput
  ↓
点击 Slash 或回车
  ↓
BrowserViewModel.loadURL() 调用 processURL()
  ↓
URL 智能处理 → URLRequest
  ↓
WebView.load(request)
  ↓
监听 estimatedProgress → 更新进度条
  ↓
加载完成 → didFinish 更新状态
```

### AI 数据流程（第二阶段）
```
网页加载完成
  ↓
提取网页内容 (JavaScript)
  ↓
检查 AISettings 功能开关
  ↓
调用 AIAssistantViewModel.queryAI()
  ↓
Qwen API 请求
  ↓
显示 AI 响应
```

---

## 🚀 快速命令

### 打开项目
```bash
cd /Users/liuhongfeng/Desktop/code/LoneSword/LoneSword
open LoneSword.xcodeproj
```

### 构建项目
```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  build -scheme LoneSword -destination 'generic/platform=iOS Simulator'
```

### 清理项目
```bash
xcodebuild clean -scheme LoneSword
```

---

## 📱 布局断点

| 设备 | 横屏大小 | 竖屏大小 | SizeClass |
|------|--------|--------|----------|
| iPhone SE | 667×375 | 667×667 | compact |
| iPhone 15 | 812×375 | 812×667 | regular |
| iPhone 15 Pro | 932×430 | 932×778 | regular |
| iPad | 1194×834 | 834×1194 | regular |

### 响应式判断
```swift
@Environment(\.verticalSizeClass) var verticalSizeClass
@Environment(\.horizontalSizeClass) var horizontalSizeClass

var isLandscape: Bool {
    horizontalSizeClass == .regular && verticalSizeClass == .compact
}
```

---

## 🔧 关键属性

### BrowserViewModel
```swift
@Published var currentURL: String              // 当前 URL
@Published var loadingProgress: Double         // 0.0 ~ 1.0
@Published var isLoading: Bool                 // 加载中
@Published var canGoBack: Bool                 // 可后退
@Published var canGoForward: Bool              // 可前进
@Published var pageTitle: String               // 页面标题
```

### AIAssistantView
```swift
@State private var detectAIGenerated: Bool     // 识别 AI 生成
@State private var autoTranslateChinese: Bool  // 自动翻译
@State private var autoSummarize: Bool         // 自动总结
@State private var userInput: String           // 用户输入
@State private var aiResponse: String          // AI 响应
```

---

## 🔗 关键方法

### BrowserViewModel
```swift
loadURL(_ url: String)              // 加载 URL（智能处理）
goBack()                            // 后退
goForward()                         // 前进
stopLoading()                       // 停止加载
reload()                            // 刷新
processURL(_ urlString: String)     // URL 处理（返回完整 URL）
```

### BrowserToolbarView
```swift
Button(action: { viewModel.goBack() })      // 后退按钮
Button(action: { viewModel.goForward() })   // 前进按钮
TextField("...", text: $urlInput, onCommit: { 
    viewModel.loadURL(urlInput)             // 提交 URL
})
```

---

## 📋 第一阶段完成清单 ✅

- [x] 数据模型（BrowserHistory、AISettings）
- [x] BrowserViewModel（核心浏览逻辑）
- [x] WebViewContainer（WKWebView 适配）
- [x] BrowserToolbarView（工具栏）
- [x] AIAssistantView（AI 面板）
- [x] ContentView（响应式布局）
- [x] LoneSwordApp（应用配置）
- [x] 项目构建成功

---

## 🔨 第二阶段待实现

- [ ] WebView 内链拦截
- [ ] 下拉刷新
- [ ] 完整浏览历史
- [ ] Slash 按钮完整功能（双击、标签、动画）
- [ ] QwenService（API 集成）
- [ ] AIAssistantViewModel（AI 调用流程）
- [ ] SpeechRecognitionService（语音转文本）
- [ ] 完整测试

---

## 🐛 调试技巧

### 查看 WebView 加载进度
```swift
print("Progress: \(viewModel.loadingProgress)")
print("URL: \(viewModel.currentURL)")
print("Is Loading: \(viewModel.isLoading)")
```

### 模拟器快捷键
- `Cmd + ←` / `Cmd + →` : 横竖屏切换
- `Cmd + R` : 运行应用
- `Cmd + B` : 构建
- `Cmd + .` : 停止运行

### 清空模拟器数据
```bash
xcrun simctl erase all
```

---

## 📚 文档

| 文档 | 位置 | 用途 |
|------|------|------|
| README | `/LoneSword/README.md` | 项目概述 |
| 实现总结 | `/LoneSword/IMPLEMENTATION_SUMMARY.md` | 第一阶段完成情况 |
| 第二阶段计划 | `/PHASE2_PLAN.md` | 详细实现指南 |
| 快速参考 | 此文件 | 快速查找 |

---

## ✨ 设计亮点

1. **现代扁平风格** - 干净的白色/浅灰背景
2. **流畅响应式** - 自动适应横竖屏，无缝切换
3. **触屏友好** - 所有按钮最小 44×44pt
4. **蓝色强调** - 统一的蓝色主题色
5. **细致动画** - 加载进度条平滑过渡

---

## 📞 项目信息

- **开发者** 🧑‍💻：LiuHongfeng
- **创建日期** 📅：2025-10-18
- **状态** 🔄：Phase 1 Complete, Phase 2 Ready
- **代码行数** 📊：487 行（第一阶段）
- **构建状态** ✅：成功

---

**最后更新**: 2025-10-18
**版本**: 1.0 Phase 1
