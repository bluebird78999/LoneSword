# 网页未渲染问题排查指南

## 问题描述

用户报告网页未渲染出来。

---

## 已添加的调试日志

为了帮助排查问题，我已经在关键位置添加了详细的调试日志：

### 1. BrowserViewModel 初始化
```swift
DEBUG: BrowserViewModel init() called
DEBUG: setupWebView() completed, webView=created
DEBUG: BrowserViewModel init() calling loadURL with: https://ai.quark.cn/
```

### 2. URL 加载
```swift
DEBUG: loadURL called with url=https://ai.quark.cn/, processedURL=https://ai.quark.cn/
DEBUG: loadURL calling webView.load() with URL: https://ai.quark.cn/
```

### 3. 导航委托方法
```swift
DEBUG: didStartProvisionalNavigation url=https://ai.quark.cn/
DEBUG: didCommit url=https://ai.quark.cn/
DEBUG: didFinish url=https://ai.quark.cn/, isNavigatingInHistory=false
```

### 4. 历史记录加载
```swift
DEBUG: Loaded 0 history records, currentIndex=-1
DEBUG: History is empty, ensuring initial URL is loaded: https://ai.quark.cn/
```

---

## 可能的原因和排查步骤

### 原因 1：数据库迁移失败导致 App 启动异常

**症状**：
- App 启动后黑屏或白屏
- 控制台显示 CoreData 迁移错误

**排查**：
查看控制台是否有以下日志：
```
⚠️ ModelContainer 创建失败，尝试删除旧数据库
✅ 已删除旧数据库文件
✅ 成功创建新的 ModelContainer
```

**解决**：
- 已在 `LoneSwordApp.swift` 中添加自动删除旧数据库的逻辑
- 首次启动会自动清理并重建数据库

---

### 原因 2：WebView 初始化问题

**症状**：
- 看到 `ERROR: loadURL called but webView is nil!`

**排查**：
1. 检查日志中是否有：
   ```
   DEBUG: setupWebView() completed, webView=created
   ```

2. 如果 webView 为 nil，说明初始化失败

**解决**：
- 确保 `BrowserViewModel` 的 `init()` 正确调用了 `setupWebView()`
- 确保 WKWebView 的初始化没有抛出异常

---

### 原因 3：URL 处理问题

**症状**：
- 看到 `ERROR: Failed to create URL object from: ...`

**排查**：
检查 `processURL()` 方法的输出，确保 URL 格式正确

**解决**：
- 确保 URL 以 `http://` 或 `https://` 开头
- 当前的 `processURL()` 会自动添加 `https://` 前缀

---

### 原因 4：WebView 布局问题

**症状**：
- WebView 创建了但是看不到内容
- 可能是尺寸为 0 或被其他视图遮挡

**排查**：
1. 在 Xcode 中使用 View Hierarchy Debugger
2. 检查 WebView 的 frame 是否正确
3. 检查 WebView 是否在视图层级中

**解决**：
- 确保 `WebViewContainer` 的 frame 正确
- 确保 `.ignoresSafeArea()` 和 `.frame()` 修饰符正确

---

### 原因 5：网络权限问题

**症状**：
- WebView 创建了，URL 也加载了，但是没有内容
- 可能是网络请求被阻止

**排查**：
检查 `Info.plist` 中是否配置了网络权限：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**解决**：
- 添加网络权限配置到 `Info.plist`

---

### 原因 6：历史记录加载干扰

**症状**：
- 首次启动时看到初始 URL 开始加载，但是被中断

**排查**：
检查日志顺序：
```
DEBUG: BrowserViewModel init() calling loadURL with: https://ai.quark.cn/
DEBUG: loadURL called with url=https://ai.quark.cn/
DEBUG: Loaded 0 history records, currentIndex=-1
DEBUG: History is empty, ensuring initial URL is loaded
```

**解决**：
- 已确保 `loadHistoryFromStorage()` 不会重复加载初始 URL
- 历史为空时不会干扰初始加载

---

## 调试步骤

### 1. 查看完整日志

在 Xcode 控制台查看完整的启动日志，按顺序检查：

```
1. DEBUG: BrowserViewModel init() called
2. DEBUG: setupWebView() completed, webView=created
3. DEBUG: BrowserViewModel init() calling loadURL with: ...
4. DEBUG: loadURL called with url=..., processedURL=...
5. DEBUG: loadURL calling webView.load() with URL: ...
6. DEBUG: didStartProvisionalNavigation url=...
7. DEBUG: Loaded X history records, currentIndex=Y
8. DEBUG: didCommit url=...
9. DEBUG: didFinish url=..., isNavigatingInHistory=false
```

### 2. 检查关键错误

搜索日志中的 `ERROR:` 关键字：
- `ERROR: loadURL called but webView is nil!`
- `ERROR: Failed to create URL object from: ...`
- `ERROR: Failed to load history: ...`

### 3. 验证 WebView 可见性

在 Xcode 中：
1. 运行 App
2. 点击 Debug View Hierarchy（调试视图层级）
3. 找到 WKWebView
4. 检查其 frame 和位置

### 4. 测试简单 URL

如果默认 URL 无法加载，尝试修改为简单的 URL：
```swift
@Published var currentURL: String = "https://www.apple.com"
```

### 5. 检查网络连接

确保模拟器或设备有网络连接：
- Safari 能正常打开网页
- 模拟器设置中网络是打开的

---

## 已知问题和修复

### 问题 1：数据库迁移失败（已修复）

**问题**：
添加 `visitOrder` 字段后，旧数据库无法迁移

**修复**：
在 `LoneSwordApp.swift` 中添加自动删除旧数据库的逻辑

### 问题 2：首次启动历史为空（正常）

**问题**：
首次启动或数据库被清空后，`navigationHistory` 为空

**修复**：
这是正常行为，不影响初始 URL 加载

---

## 快速测试方案

### 测试 1：最小化测试

创建一个简单的测试视图：

```swift
struct SimpleWebViewTest: View {
    var body: some View {
        WebView(url: URL(string: "https://www.apple.com")!)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
```

如果这个简单版本可以工作，说明问题在于复杂的状态管理。

### 测试 2：禁用历史记录

临时注释掉历史记录相关代码：

```swift
.onAppear {
    // browserViewModel.setModelContext(modelContext)
    // browserViewModel.loadHistoryFromStorage()
}
```

看是否能正常渲染。

### 测试 3：延迟加载历史

```swift
.onAppear {
    browserViewModel.setModelContext(modelContext)
    // 延迟加载历史，避免干扰初始URL
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        browserViewModel.loadHistoryFromStorage()
    }
}
```

---

## 预期的正常日志

```
DEBUG: BrowserViewModel init() called
DEBUG: setupWebView() completed, webView=created
DEBUG: BrowserViewModel init() calling loadURL with: https://ai.quark.cn/
DEBUG: loadURL called with url=https://ai.quark.cn/, processedURL=https://ai.quark.cn/
DEBUG: loadURL sending URL change notification
DEBUG: loadURL calling webView.load() with URL: https://ai.quark.cn/
DEBUG: AIAssistantView received URL change notification
DEBUG: New URL: https://ai.quark.cn/
DEBUG: AIAssistantViewModel resetForNewPage called
DEBUG: didStartProvisionalNavigation url=https://ai.quark.cn/
DEBUG: ModelContext not set, cannot load history
[或]
DEBUG: Loaded 0 history records, currentIndex=-1
DEBUG: Navigation state - canGoBack=false, canGoForward=false, index=-1
DEBUG: History is empty, ensuring initial URL is loaded: https://ai.quark.cn/
DEBUG: didCommit url=https://ai.quark.cn/
DEBUG: didFinish url=https://ai.quark.cn/, isNavigatingInHistory=false
DEBUG: Added history record: https://ai.quark.cn/, currentIndex=0
DEBUG: Navigation state - canGoBack=false, canGoForward=false, index=0
```

---

## 下一步

请在 Xcode 控制台中查看启动日志，然后告诉我：

1. **是否看到 `ERROR:` 开头的日志？** 如果有，完整的错误信息是什么？

2. **是否看到 `DEBUG: BrowserViewModel init() called`？** 如果没有，说明 ViewModel 未初始化

3. **是否看到 `DEBUG: didFinish url=...`？** 如果看到了，说明页面加载完成了

4. **WebView 区域是什么颜色？**
   - 白色：WebView 创建了但没有内容
   - 黑色：可能是布局问题
   - 完全看不到：可能被其他视图覆盖

5. **能否使用 View Hierarchy Debugger 看到 WKWebView？** 如果看不到，说明 WebView 未添加到视图层级

根据这些信息，我可以提供更具体的解决方案。

---

**修改完成时间**：2025-10-23  
**修改状态**：✅ 已添加详细调试日志  
**编译状态**：✅ 编译成功  
**测试状态**：待用户提供调试日志
