# LoneSword Phase 2 - 完整功能实现计划

## 📋 概述

第一阶段已完成 UI 框架和基本浏览功能。第二阶段将重点实现高级浏览功能、Slash 按钮完整逻辑、AI 集成和语音输入。

---

## 🔧 任务 1：WebView 高级功能

### 1.1 内链点击拦截

**文件**: `BrowserViewModel.swift` + `WebViewContainer.swift`

**实现内容**:
- 实现 `WKNavigationDelegate.webView(_:decidePolicyFor:decisionHandler:)`
- 拦截所有链接点击事件
- 更新 `currentURL` 地址栏
- 保存到浏览历史
- 触发 Slash 按钮加载逻辑

**关键代码框架**:
```swift
func webView(_ webView: WKWebView, 
             decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url?.absoluteString {
        currentURL = url
        // 保存到历史
        // 触发 Slash 加载
    }
    decisionHandler(.allow)
}
```

### 1.2 下拉刷新手势

**文件**: `WebViewContainer.swift`

**实现内容**:
- 在 UIViewRepresentable 中添加 `UIRefreshControl`
- 绑定到 WebView 的 `scrollView`
- 触发 `webView.reload()` 在 BrowserViewModel
- 刷新完成后更新 UI

**关键实现**:
```swift
let refreshControl = UIRefreshControl()
refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
webView.scrollView.addSubview(refreshControl)
```

### 1.3 浏览历史管理

**文件**: `BrowserViewModel.swift`（需扩展）

**实现内容**:
- 创建 `@Published var history: [BrowserHistory] = []`
- 页面加载完成后调用 `saveHistory(url:title:)`
- 实现 `getHistory()` 从 SwiftData 读取历史
- 显示历史列表（可选 UI 组件或下拉菜单）

**关键方法**:
```swift
func saveHistory(url: String, title: String) {
    let record = BrowserHistory(url: url, title: title)
    // 存储到 SwiftData
}

func clearHistory() {
    // 清空历史记录
}
```

---

## 🔘 任务 2：Slash 按钮完整功能

### 2.1 双击事件监听

**文件**: `BrowserToolbarView.swift`

**实现内容**:
- 添加 `@GestureState` 跟踪点击次数
- 实现双击手势（`TapGesture` + timer）
- 单击：停止加载 + 加载当前 URL
- 双击：加载首页 "https://ai.quark.cn/"

**关键实现**:
```swift
@State private var tapCount = 0
@State private var lastTapTime = Date()

// 处理单/双击逻辑
if Date().timeIntervalSince(lastTapTime) < 0.3 {
    // 双击
    viewModel.loadURL("https://ai.quark.cn/")
} else {
    // 单击
    tapCount = 1
}
lastTapTime = Date()
```

### 2.2 橙色进度标签

**文件**: `BrowserToolbarView.swift`

**实现内容**:
- 单击 Slash 后在按钮右上角显示橙色小圆点
- 标签样式：宽高 16pt，背景色 #FF9500
- 显示数字或文本（可选）
- 加载完成时消失

**UI 框架**:
```swift
ZStack(alignment: .topTrailing) {
    // Slash 按钮内容
    
    if isLoading {
        Circle()
            .fill(Color(red: 1, green: 0.58, blue: 0))
            .frame(width: 16, height: 16)
            .offset(x: 4, y: -4)
    }
}
```

### 2.3 进度条动画（右上角起始）

**文件**: `BrowserToolbarView.swift`

**实现内容**:
- 加载时显示 2px 进度条，从右上角起始
- 动画方向：右上角 → 顺时针旋转 → 左上角 → 左下角 → 右下角 → 右上角（合拢）
- 加载完成（100%）时转满一圈后消失
- 使用 CABasicAnimation 或 SwiftUI animation

**实现思路**:
```swift
// 使用 BorderStrokeAnimation 或自定义 Canvas
if isLoading {
    Canvas { context in
        // 绘制旋转的进度条
        let path = Path(roundedRect: bounds, cornerRadius: 8)
        // 计算旋转角度：360 * loadingProgress
    }
}
```

---

## 🤖 任务 3：AI 功能集成

### 3.1 QwenService 实现

**新文件**: `Services/QwenService.swift`

**实现内容**:
- 创建 `class QwenService: ObservableObject`
- 配置 API 端点和密钥（环境变量或配置文件）
- 实现 `callQwen(content: String, query: String) async throws -> String`
- 支持 HTTP 请求（URLSession）
- 错误处理和重试逻辑

**关键方法**:
```swift
class QwenService {
    let apiKey: String = "your-api-key"
    let apiEndpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
    
    func callQwen(webContent: String, userQuery: String) async throws -> String {
        // 构建请求
        // 发送 POST 请求
        // 解析响应
        // 返回 AI 回答
    }
}
```

**API 请求示例**:
```json
{
    "model": "qwen-plus",
    "input": {
        "messages": [
            {
                "role": "user",
                "content": "分析网页内容：{webContent}。用户问题：{userQuery}"
            }
        ]
    }
}
```

### 3.2 AIAssistantViewModel 实现

**新文件**: `ViewModels/AIAssistantViewModel.swift`

**实现内容**:
- 创建 `class AIAssistantViewModel: ObservableObject`
- 管理 AI 调用生命周期
- 发布属性：isLoading、aiResponse、error
- 实现 `queryAI(webContent:userQuery:)` 方法
- 根据功能开关决定是否调用

**关键方法**:
```swift
class AIAssistantViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var aiResponse: String = ""
    @Published var error: String?
    
    let qwenService = QwenService()
    
    func queryAI(webContent: String, userQuery: String, settings: AISettings) async {
        guard settings.detectAIGenerated || settings.autoTranslateChinese || settings.autoSummarize else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await qwenService.callQwen(content: webContent, query: userQuery)
            aiResponse = response
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### 3.3 网页加载完成触发 AI

**文件**: `BrowserViewModel.swift` + `AIAssistantView.swift`

**实现内容**:
- 页面加载完成（`webView(_:didFinish:)`）时获取网页内容
- 调用 JavaScript 提取页面文本
- 根据功能开关自动触发 AI 分析
- 更新 AI 面板显示

**关键实现**:
```swift
func extractWebContent() async -> String {
    let javascript = "document.documentElement.innerText"
    guard let result = try? await webView?.evaluateJavaScript(javascript) as? String else {
        return ""
    }
    return result
}

// 在 didFinish 中调用
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task {
        let content = await extractWebContent()
        // 触发 AIAssistantViewModel.queryAI()
    }
}
```

---

## 🎤 任务 4：语音输入实现

### 4.1 SpeechRecognitionService 创建

**新文件**: `Services/SpeechRecognitionService.swift`

**实现内容**:
- 导入 `Speech` 框架
- 实现 `class SpeechRecognitionService: NSObject, ObservableObject`
- 处理麦克风权限请求
- 实现语音识别主逻辑

**关键代码**:
```swift
import Speech

class SpeechRecognitionService: NSObject, ObservableObject {
    @Published var recognizedText: String = ""
    @Published var isListening: Bool = false
    @Published var error: String?
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func requestMicrophoneAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func startListening() {
        // 配置音频引擎
        // 开始语音识别
        isListening = true
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }
}
```

### 4.2 麦克风权限处理

**文件**: `Info.plist` + `SpeechRecognitionService.swift`

**实现内容**:
- 在 Info.plist 中添加权限说明：
  - `NSSpeechRecognitionUsageDescription`
  - `NSMicrophoneUsageDescription`
- 应用启动时请求权限
- 权限拒绝时显示提示

**Info.plist 配置**:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>应用需要访问语音识别功能来转录您的语音输入</string>
<key>NSMicrophoneUsageDescription</key>
<string>应用需要访问麦克风来识别您的语音</string>
```

### 4.3 AIAssistantView 集成语音

**文件**: `AIAssistantView.swift`（修改）

**实现内容**:
- 添加 `@StateObject var speechService = SpeechRecognitionService()`
- 麦克风按钮点击：启动/停止语音识别
- 识别完成时自动填充输入框
- 按钮状态变化（监听、完成、错误）

**关键修改**:
```swift
Button(action: {
    if speechService.isListening {
        speechService.stopListening()
    } else {
        Task {
            let authorized = await speechService.requestMicrophoneAccess()
            if authorized {
                speechService.startListening()
            }
        }
    }
}) {
    Image(systemName: speechService.isListening ? "mic.fill" : "mic")
        .font(.system(size: 16))
        .foregroundColor(speechService.isListening ? .red : accentBlue)
}

.onChange(of: speechService.recognizedText) { oldValue, newValue in
    if !newValue.isEmpty {
        userInput = newValue
    }
}
```

---

## 📱 任务 5：综合测试

### 5.1 功能测试清单

- [ ] WebView 加载和导航
- [ ] 前进/后退历史
- [ ] 浏览历史持久化
- [ ] 内链点击拦截
- [ ] 下拉刷新功能
- [ ] Slash 按钮单击/双击
- [ ] 橙色标签显示
- [ ] 进度条动画
- [ ] AI 查询调用
- [ ] 语音输入转文本
- [ ] 横竖屏切换
- [ ] 功能开关控制

### 5.2 性能测试

- [ ] 加载大型网页
- [ ] 快速导航不卡顿
- [ ] 内存占用合理
- [ ] 屏幕旋转平滑

### 5.3 UI/UX 测试

- [ ] 所有文本清晰可读
- [ ] 颜色对比度符合 WCAG
- [ ] 所有按钮易于点击
- [ ] 过渡动画流畅

---

## 📊 预期工作量

| 任务 | 难度 | 预计时间 |
|------|------|--------|
| WebView 高级功能 | 中 | 2-3 小时 |
| Slash 按钮完整逻辑 | 中 | 1-2 小时 |
| AI 集成 | 中 | 2-3 小时 |
| 语音输入 | 中 | 2-3 小时 |
| 综合测试 | 中 | 2-3 小时 |
| **总计** | - | **9-14 小时** |

---

## 🔐 安全建议

1. **API 密钥管理**：
   - 不要将 API Key 硬编码
   - 使用环境变量或配置文件
   - 考虑后端代理以隐藏密钥

2. **语音数据**：
   - 仅在本地处理，不上传原始音频
   - 及时清理临时文件

3. **网页内容**：
   - 验证提取的网页内容
   - 限制发送给 AI 的内容大小

---

## 📚 参考资源

- [Speech Framework 文档](https://developer.apple.com/documentation/speech)
- [WKWebView 最佳实践](https://developer.apple.com/documentation/webkit/wkwebview)
- [Qwen API 文档](https://dashscope.aliyuncs.com/docs)
- [SwiftUI 手势识别](https://developer.apple.com/documentation/swiftui/gestures)

---

**计划更新**: 2025-10-18
**状态**: 📋 Ready for Phase 2
