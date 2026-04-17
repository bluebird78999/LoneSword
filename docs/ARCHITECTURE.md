# LoneSword 架构设计文档

> 生成日期: 2026-04-18
> 项目状态: 开发中 (v1.0.0+)
> 平台: iOS 15.0+ (iPhone/iPad)
> 架构模式: MVVM (Model-View-ViewModel)

---

## 1. 项目概述

LoneSword 是一个为 iPad 和 iPhone 设计的现代响应式网页浏览器应用，集成了 AI 助手功能。核心理念是"用AI对抗AI时代的熵增"——通过 AI 分析网页内容，提供 AI 生成检测、自动总结、智能翻译等能力。

### 1.1 核心功能矩阵

| 功能域 | 子功能 | 状态 |
|--------|--------|------|
| 网页浏览 | URL 导航、地址栏、加载进度条 | 已实现 |
| 历史导航 | 前进/后退、持久化历史栈(最多100条) | 已实现 |
| 响应式布局 | 横屏(2/3+1/3)、竖屏(2/3+1/3)、AI洞察收起模式 | 已实现 |
| AI 洞察 | AI 生成检测、内容自动总结 | 已实现 |
| AI 对话 | 文本问答、基于当前网页上下文 | 已实现 |
| 语音输入 | 中文语音识别、实时转文本 | 已实现 |
| 订阅系统 | StoreKit 2 内购、三级订阅、用量追踪 | 已实现 |
| API Key 管理 | Keychain 安全存储、有效性验证 | 已实现 |
| 下拉刷新 | WebView 下拉刷新 | 已实现 |
| Slash 按钮 | 单击加载地址栏、双击回到首页 | 已实现 |

---

## 2. 总体架构

### 2.1 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        Presentation Layer                     │
│  ┌─────────────────┐ ┌──────────────────┐ ┌───────────────┐ │
│  │  ContentView     │ │ BrowserToolbarView│ │  SettingsView  │ │
│  │  (响应式布局编排) │ │  (工具栏+地址栏)  │ │  (设置/订阅)   │ │
│  └───────┬─────────┘ └────────┬─────────┘ └───────┬───────┘ │
│          │                    │                    │          │
│  ┌───────┴─────────┐ ┌───────┴─────────┐ ┌───────┴───────┐ │
│  │ WebViewContainer │ │ AIAssistantView  │ │ (Sheet 弹出)  │ │
│  │ (WKWebView 封装)  │ │ (AI面板+输入框)   │ │               │ │
│  └───────┬─────────┘ └───────┬─────────┘ └───────────────┘ │
└──────────┼───────────────────┼──────────────────────────────┘
           │                   │
┌──────────┴───────────────────┴──────────────────────────────┐
│                        ViewModel Layer                        │
│  ┌──────────────────────────────┐ ┌──────────────────────┐  │
│  │  BrowserViewModel             │ │ AIAssistantViewModel  │  │
│  │  - 浏览器导航逻辑              │ │ - AI 调用生命周期      │  │
│  │  - 历史栈管理                  │ │ - 用量追踪与限制       │  │
│  │  - URL 处理与校验              │ │ - Keychain API管理    │  │
│  │  - WKNavigationDelegate       │ │ - 自动分析触发逻辑     │  │
│  └──────────────┬───────────────┘ └──────────┬───────────┘  │
└─────────────────┼────────────────────────────┼──────────────┘
                  │                            │
┌─────────────────┴────────────────────────────┴──────────────┐
│                         Service Layer                         │
│  ┌────────────┐ ┌────────────────┐ ┌─────────────┐ ┌──────┐ │
│  │ QwenService │ │ StoreKitManager│ │KeychainService│ │Speech│ │
│  │ (Qwen API) │ │ (StoreKit 2)   │ │ (SecItem)    │ │Recog.│ │
│  └────────────┘ └────────────────┘ └─────────────┘ └──────┘ │
└─────────────────────────────────────────────────────────────┘
                  │
┌─────────────────┴────────────────────────────────────────────┐
│                          Model Layer                          │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────┐  │
│  │  BrowserHistory   │ │   AISettings     │ │    Item       │  │
│  │  (SwiftData)      │ │  (SwiftData)     │ │  (SwiftData)  │  │
│  └──────────────────┘ └──────────────────┘ └──────────────┘  │
│                        SwiftData / Keychain                    │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 分层职责

| 层次 | 职责 | 关键文件 |
|------|------|----------|
| **Model** | 数据模型定义，SwiftData 持久化实体 | BrowserHistory.swift, AISettings.swift, Item.swift |
| **ViewModel** | 业务逻辑、状态管理、Service 协调 | BrowserViewModel.swift, AIAssistantViewModel.swift |
| **View** | UI 渲染、用户交互、SwiftUI 声明式布局 | ContentView.swift, BrowserToolbarView.swift, WebViewContainer.swift, AIAssistantView.swift, SettingsView.swift |
| **Service** | 外部系统集成（API、StoreKit、Keychain、Speech） | QwenService.swift, StoreKitManager.swift, KeychainService.swift, SpeechRecognitionService.swift |

---

## 3. 详细组件设计

### 3.1 Model 层

#### 3.1.1 BrowserHistory

```swift
@Model final class BrowserHistory {
    var url: String
    var title: String
    var timestamp: Date
    var visitOrder: Int   // 用于排序，数字越大越新
}
```

- **用途**: 存储浏览历史条目，支持前进/后退导航
- **持久化**: SwiftData，最多保留 100 条
- **排序机制**: visitOrder 递增，避免时间戳精度问题

#### 3.1.2 AISettings

```swift
@Model final class AISettings {
    var detectAIGenerated: Bool    // 是否检测 AI 生成内容
    var autoTranslateChinese: Bool // 是否自动翻译（当前已禁用）
    var autoSummarize: Bool        // 是否自动总结
    var isAIEnabled: Bool          // AI 洞察总开关
    var subscriptionTier: String   // "free" / "basic" / "premium"
    var dailyUsageCount: Int       // 每日使用计数
    var lastResetDate: Date        // 上次重置日期
    var totalUsageCount: Int       // 累计使用计数
}
```

- **用途**: AI 功能配置 + 用量追踪 + 订阅状态
- **持久化**: SwiftData，单例模式（fetchOrCreateSettings）
- **用量限制**: free=10次/天, basic=10000次/月, premium=100000次/月

#### 3.1.3 Item (模板)

```swift
@Model final class Item {
    var timestamp: Date
}
```

- **用途**: Xcode 项目模板生成的默认模型，未实际使用，保留于 Schema

### 3.2 ViewModel 层

#### 3.2.1 BrowserViewModel

```
BrowserViewModel (ObservableObject)
├── 状态属性 (@Published)
│   ├── currentURL: String        // 当前地址
│   ├── loadingProgress: Double   // 加载进度 0~1
│   ├── isLoading: Bool           // 是否正在加载
│   ├── canGoBack: Bool           // 可否后退
│   ├── canGoForward: Bool        // 可否前进
│   ├── pageTitle: String         // 页面标题
│   └── navigationHistory: [BrowserHistory]  // 历史栈
├── 核心方法
│   ├── loadURL(_ url: String)    // 加载 URL（含协议补全）
│   ├── goBack() / goForward()    // 历史导航
│   ├── reload() / stopLoading()  // 刷新/停止
│   └── extractWebText()          // 提取页面文本
├── 历史记录管理
│   ├── setModelContext()         // 注入 SwiftData 上下文
│   ├── loadHistoryFromStorage()  // 从数据库加载
│   ├── addToHistory()            // 添加记录（含 trim 逻辑）
│   └── trimHistoryIfNeeded()     // 超过100条时裁剪
├── WKNavigationDelegate 实现
│   ├── didStartProvisionalNavigation
│   ├── didCommit                 // 更新 currentURL 并广播 URL 变化
│   ├── didFinish                 // 记录历史 + 回调通知
│   └── decidePolicyFor           // 允许所有导航，拦截更新地址栏
└── WKUIDelegate 实现
    └── createWebViewWith         // target=_blank 在当前 WebView 打开
```

**关键设计决策**:
1. 自定义历史栈：不依赖 WKWebView 的 backForwardList，而是用 SwiftData 持久化的独立历史栈，实现跨 session 的前进/后退
2. URL 变化通知：通过 NotificationCenter 广播 `WebViewURLDidChange`，解耦 ViewModel 与 AI 面板
3. 协议自动补全：`processURL()` 处理无前缀、仅域名、搜索词等场景

#### 3.2.2 AIAssistantViewModel

```
AIAssistantViewModel (ObservableObject)
├── 状态属性 (@Published)
│   ├── detectAIGenerated: Bool     // AI 生成检测开关
│   ├── autoTranslateChinese: Bool  // 翻译开关（已禁用）
│   ├── autoSummarize: Bool         // 自动总结开关
│   ├── aiInsightEnabled: Bool      // AI 洞察总开关
│   ├── isLoading: Bool             // AI 请求中
│   ├── aiSummaryText: String       // AI 总结结果
│   ├── conversationText: String    // 对话历史
│   ├── hasValidPrivateKey: Bool    // API Key 是否有效
│   └── privateKeyStatus: String    // API Key 状态描述
├── 核心方法
│   ├── autoAnalyzeIfEnabled()      // 页面加载后自动分析
│   ├── queryFromUser(_ query)      // 用户手动查询
│   ├── resetForNewPage()           // 翻页时重置
│   └── loadSettings()              // 从 SwiftData 加载配置
├── API Key 管理
│   ├── loadAPIKeyFromKeychain()    // 启动时加载
│   ├── saveAPIKeyToKeychain()      // 保存并验证
│   ├── testAPIKey()               // 异步验证 Key
│   └── configureQwen()            // 初始化 QwenService
├── 用量控制
│   ├── checkAndIncrementUsage()    // 检查并递增（含每日重置）
│   └── getUsageLimitForTier()      // 按订阅等级返回限额
└── 回调注入
    └── webContentProvider: () async -> String  // 从 ContentView 注入
```

**关键设计决策**:
1. 内容提供者注入模式：`webContentProvider` 是一个 async 闭包，由 ContentView 注入，实现 ViewModel 与 WebView 的解耦
2. 双层使用限制：配置了私人有效 API Key 则跳过用量检查，否则按订阅等级限额
3. 自动分析触发链：`loadingProgress >= 1.0` → `autoAnalyzeIfEnabled()` → 提取内容 → 调用 Qwen → 解析响应

### 3.3 View 层

#### 3.3.1 ContentView（布局编排器）

- **职责**: 响应式布局的顶层协调器
- **横竖屏判断**: 通过 `verticalSizeClass == .compact` 判定横屏
- **布局策略**:
  - 横屏: HStack (WebView 2/3 | AI 1/3)
  - 竖屏: VStack (WebView 2/3, AI 1/3)
  - AI 洞察关闭: 全屏 WebView
- **初始化流程**:
  1. 注入 ModelContext 到两个 ViewModel
  2. 加载浏览历史
  3. 加载 AI 设置和 API Key
  4. 注入 webContentProvider 闭包

#### 3.3.2 BrowserToolbarView（工具栏）

- **组成**: 2px 进度条 + 后退/前进按钮 + URL 地址栏 + Slash 按钮 + 设置按钮
- **Slash 按钮逻辑**:
  - 单击: 加载地址栏当前输入
  - 双击 (< 0.3s): 加载首页 https://www.google.com/ncr
- **URL 地址栏**:
  - 编辑时显示完整 URL
  - 非编辑时同步 currentURL
  - 回车键提交
- **设置按钮**: 仅当 AI 洞察关闭时显示（AI 开启时设置入口在 AI 面板标题栏）

#### 3.3.3 WebViewContainer（WKWebView 桥接）

- **类型**: `UIViewRepresentable` — SwiftUI 与 UIKit 桥接
- **关键实现**:
  - `makeUIView`: 获取 BrowserViewModel 的 WKWebView，附加 UIRefreshControl
  - `updateUIView`: 仅在未加载任何页面时纠偏加载，不覆盖正在进行的导航
  - `Coordinator`: 处理下拉刷新回调
- **设计注意**: 不在 `updateUIView` 中主动触发加载，避免打断 ViewModel 的导航流程

#### 3.3.4 AIAssistantView（AI 面板）

- **组成**: 标题栏 + 功能开关 Chip + API Key 状态 + 内容展示区 + 输入区
- **内容展示**: 分 AI 总结区和对话记录区，支持简易 Markdown 粗体解析
- **自动触发**:
  - `onReceive(browser.$loadingProgress)`: 加载完成时自动分析
  - `onReceive(WebViewURLDidChange)`: URL 变化时重置
- **输入方式**: 文本输入框 + 发送按钮 + 语音麦克风按钮
- **语音集成**: 内嵌 `SpeechRecognitionService`，识别结果自动填充输入框

#### 3.3.5 SettingsView（设置页）

- **展示方式**: Sheet 模态弹出
- **模块**:
  - AI 洞察总开关
  - API Key 配置（输入、测试、保存到 Keychain）
  - 订阅等级卡片（Free / Basic ¥19.9/月 / Premium ¥39.9/月）
  - 恢复购买
  - 使用说明

### 3.4 Service 层

#### 3.4.1 QwenService

- **用途**: 阿里云通义千问 API 封装
- **模型**: qwen-plus
- **端点**: https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation
- **方法**:
  - `call(webContent, userQuery)`: 核心 AI 调用，截取前 6000 字符
  - `detectAndTranslate(webContent)`: 语言检测 + 翻译（当前已禁用）
  - `testKey()`: API Key 有效性验证

#### 3.4.2 KeychainService

- **用途**: iOS Keychain 安全存储封装
- **API**:
  - `save(key, data)`: 先删除后插入（幂等写入）
  - `load(key)`: 读取字符串
  - `delete(key)`: 删除条目
- **安全级别**: `kSecAttrAccessibleWhenUnlocked`（设备解锁时可访问）

#### 3.4.3 StoreKitManager

- **用途**: App Store 订阅管理（StoreKit 2）
- **产品 ID**:
  - `com.lonesword.subscription.basic` (¥19.9/月)
  - `com.lonesword.subscription.premium` (¥39.9/月)
- **功能**:
  - 产品列表加载
  - 购买流程 + 交易验证
  - 交易更新监听（后台监听 Task）
  - 恢复购买
  - 订阅等级识别

#### 3.4.4 SpeechRecognitionService

- **用途**: iOS 语音识别（中文）
- **框架**: Speech + AVFoundation
- **Locale**: zh-CN
- **功能**:
  - 权限请求
  - 实时语音识别（partial results）
  - 音频引擎管理

---

## 4. 数据流与通信

### 4.1 页面加载完整流程

```
用户输入 URL → BrowserToolbarView.loadURL()
    ↓
BrowserViewModel.loadURL()
    ├── processURL() (协议补全)
    ├── 广播 WebViewURLDidChange 通知
    └── webView.load(request)
    ↓
WKNavigationDelegate 回调链
    ├── didStartProvisionalNavigation → isLoading=true, progress=0
    ├── didCommit → 更新 currentURL, 广播 URL 变化
    └── didFinish → isLoading=false, addToHistory()
    ↓
AIAssistantView 响应
    ├── 收到 loadingProgress=1.0 → autoAnalyzeIfEnabled()
    ├── 收到 URL 变化通知 → resetForNewPage()
    └── 通过 webContentProvider 提取页面文本 → QwenService.call()
    ↓
结果渲染到 AIAssistantView 显示区
```

### 4.2 用户提问流程

```
用户在 AIAssistantView 输入问题 → submitQuery()
    ↓
AIAssistantViewModel.queryFromUser(query)
    ├── 检查用量限制 (checkAndIncrementUsage)
    ├── 提取当前页面内容 (webContentProvider)
    └── QwenService.call(webContent, query)
    ↓
结果追加到 conversationText → UI 自动滚动到底部
```

### 4.3 通信机制汇总

| 机制 | 用途 | 发起方 | 接收方 |
|------|------|--------|--------|
| `@Published` + `@ObservedObject` | ViewModel → View 状态同步 | ViewModel | View |
| `@EnvironmentObject` | 跨层级共享 ViewModel | ContentView | AIAssistantView (获取 BrowserViewModel) |
| `NotificationCenter` | URL 变化广播 | BrowserViewModel | AIAssistantView |
| 闭包注入 (`webContentProvider`) | WebView 内容提取 | ContentView | AIAssistantViewModel |
| `@Binding` | 父子组件双向绑定 | Parent View | Child View |
| `.sheet` | 模态页面 | SettingsView | 主界面 |

---

## 5. 技术栈

| 类别 | 技术 | 版本要求 |
|------|------|----------|
| UI 框架 | SwiftUI | iOS 15.0+ |
| 网页视图 | WebKit (WKWebView) | - |
| 数据持久化 | SwiftData | iOS 17.0+ (代码兼容) |
| 网络请求 | URLSession (async/await) | - |
| AI API | 阿里云通义千问 (qwen-plus) | - |
| 语音识别 | Speech Framework | - |
| 应用内购买 | StoreKit 2 | iOS 15.0+ |
| 安全存储 | Security Framework (Keychain) | - |
| 响应式编程 | Combine | - |
| 开发语言 | Swift 5.9+ | - |

---

## 6. 扩展点分析（为后续开发预留）

### 6.1 已预留但未实现的功能

| 功能 | 位置 | 状态 |
|------|------|------|
| 自动翻译 | AIAssistantViewModel 中已注释 | 禁用 |
| 对话历史持久化 | conversationText 仅内存 | 未持久化 |
| 浏览历史列表 UI | BrowserHistory 模型存在 | 无 UI |
| 清除历史记录 | 模型支持 | 无入口 |
| 多语言翻译扩展 | Speech 仅 zh-CN | 可加其他 Locale |

### 6.2 架构扩展建议

#### 6.2.1 新增 AI 模型/Provider

当前 `QwenService` 是硬编码的单一 Provider。扩展方案：

```
protocol AIProvider {
    func call(webContent: String, userQuery: String) async throws -> String
}

class QwenService: AIProvider { ... }
class OpenAIService: AIProvider { ... }
```

在 AIAssistantViewModel 中注入 Provider 即可切换。

#### 6.2.2 新增浏览器功能

- **书签系统**: 新增 `Bookmark` SwiftData 模型 + BookmarkViewModel + 书签 UI
- **标签页管理**: 需要重构 BrowserViewModel 为多实例管理，引入 TabManager
- **下载管理**: 新增 DownloadService + WKDownloadDelegate 实现
- **广告拦截**: 在 WKWebViewConfiguration 中注入 Content Blocker Rules
- **无痕模式**: 使用非持久化的 WKWebsiteDataStore

#### 6.2.3 订阅系统扩展

- 当前 `StoreKitManager` 和 `AISettings.subscriptionTier` 之间存在状态同步断点：StoreKit 的 `purchasedProductIDs` 没有自动同步到 AISettings
- 建议在 StoreKitManager 购买成功后自动调用 `vm.updateSubscriptionTier()`
- 可引入 Server-side receipt validation 增强安全性

#### 6.2.4 性能优化

- 网页内容提取：当前使用 `document.documentElement.innerText` 截取 6000 字符，可能丢失重要内容。可改为基于 DOM 结构的智能提取（移除导航栏、广告等）
- 对话历史：当前为纯文本追加，长对话会导致 ScrollView 性能下降。可改为结构化消息列表 + LazyVStack
- AI 响应：当前为一次性返回，可改为 Stream 流式输出提升体验

---

## 7. 项目文件清单

```
LoneSword/
├── LoneSword/
│   ├── LoneSwordApp.swift                  # 应用入口，SwiftData Schema 配置
│   ├── ContentView.swift                   # 主视图，响应式布局编排
│   ├── Item.swift                          # 模板模型（未使用）
│   ├── Models/
│   │   ├── BrowserHistory.swift            # 浏览历史模型
│   │   └── AISettings.swift                # AI 设置与用量模型
│   ├── ViewModels/
│   │   ├── BrowserViewModel.swift          # 浏览器逻辑 + WKNavigationDelegate
│   │   └── AIAssistantViewModel.swift      # AI 分析 + 用量 + API Key 管理
│   ├── Views/
│   │   ├── BrowserToolbarView.swift        # 工具栏（地址栏 + 导航 + Slash）
│   │   ├── WebViewContainer.swift          # WKWebView UIViewRepresentable 桥接
│   │   ├── AIAssistantView.swift           # AI 面板（分析 + 对话 + 语音）
│   │   └── SettingsView.swift              # 设置页（API Key + 订阅）
│   ├── Services/
│   │   ├── QwenService.swift               # 通义千问 API 封装
│   │   ├── KeychainService.swift           # iOS Keychain 安全存储
│   │   ├── StoreKitManager.swift           # StoreKit 2 订阅管理
│   │   └── SpeechRecognitionService.swift  # iOS 语音识别服务
│   ├── Assets.xcassets/                    # 图片与颜色资源
│   ├── LoneSword.xcodeproj/                # Xcode 项目配置
│   ├── LoneSwordTests/                     # 单元测试（空）
│   └── LoneSwordUITests/                   # UI 测试（空）
├── docs/
│   └── ARCHITECTURE.md                     # 本文档
├── README.md                               # 项目说明
├── IMPLEMENTATION_SUMMARY.md               # 功能实现总结
├── PHASE2_PLAN.md                          # 第二阶段开发计划
├── TEST_CASES.md                           # 测试用例
└── (其他开发文档...)
```

---

## 8. 关键设计决策记录

| 决策 | 方案 | 原因 |
|------|------|------|
| 历史管理 | 自定义 SwiftData 历史栈，非 WKWebView.backForwardList | 支持跨 session 持久化，精确控制历史条目数 |
| URL 变化通知 | NotificationCenter 而非直接引用 | 解耦 BrowserViewModel 与 AIAssistantViewModel |
| WebView 桥接 | UIViewRepresentable 复用同一 WKWebView 实例 | 避免 SwiftUI 重建导致页面状态丢失 |
| API Key 存储 | iOS Keychain 而非 UserDefaults | 安全加密存储 |
| 内容提取 | evaluateJavaScript("document.documentElement.innerText") | 简单有效，截取前 6000 字符控制 token 用量 |
| 订阅层级 | free/basic/premium 三级 | 渐进式付费模型 |
| 语音识别 | 仅支持中文 (zh-CN) | 目标用户群体，降低复杂度 |
| 自动翻译 | 已禁用 | 减少 API 调用成本，聚焦核心功能 |

---

## 9. 已知技术债务

1. **Coordinator 每次创建新实例**: `WebViewContainer.contextCoordinator()` 每次都创建新的 Coordinator，应改为单例或在 `makeCoordinator()` 中复用
2. **Debug 日志泛滥**: 代码中有大量 `print("DEBUG: ...")` 语句，生产环境应移除或使用日志框架
3. **ContentView 布局代码冗长**: 横竖屏逻辑重复度高，可抽取为 LayoutModifier
4. **AISettings 与 StoreKitManager 状态未同步**: 购买成功后需手动调用 `updateSubscriptionTier`
5. **Simple Markdown 解析器**: 仅支持粗体，不支持列表、代码块、链接等，可引入 AttributedString.MarkdownParsing (iOS 15+)
6. **语音识别单次使用**: SpeechRecognitionService 在 AIAssistantView 中每次创建，未复用
7. **Item 模型残留**: 项目模板生成的 Item.swift 未被使用但仍在 Schema 中

---

*文档结束*
