# 完整的URL加载和AI分析流程分析

## 当前流程分析

### 1. 用户输入新URL并点击Slash按钮时的流程

1. **loadURL()函数被调用**
   - 验证URL格式
   - 发送取消通知（`cancelWebViewAndSummary`）
   - 更新`currentURL`状态变量

2. **取消通知处理**
   - `handleCancelNotification`被调用
   - 停止WebView加载（`webView.stopLoading()`）
   - 重置提取状态（`resetExtractionState()`）
   - 取消当前的AI总结任务

3. **WebView更新**
   - `updateUIView`被调用（因为`currentURL`改变）
   - 检查是否需要加载新URL
   - 停止当前加载并加载新URL
   - 3秒后尝试早期文本提取

4. **文本提取和AI分析**
   - 早期提取（3秒后）
   - 最终提取（页面加载完成后）
   - 根据文本长度决定是否进行AI总结

## 存在的问题

### 1. 取消机制不够彻底
- 虽然发送了取消通知，但WebView可能已经在执行JavaScript
- AI任务的取消检查点不够多
- 早期提取的延迟任务没有取消机制

### 2. 状态管理混乱
- `didSummarizeEarly`等状态在新URL加载时可能没有正确重置
- WebView和Coordinator的生命周期管理不够清晰

### 3. URL比较逻辑的问题
- 在`didFinish`中使用`contains`比较URL可能导致误判
- 重定向处理不够完善

### 4. 错误处理不一致
- 某些错误情况下没有重置状态
- 错误信息可能被后续操作覆盖

## 改进方案

### 1. 增强的取消机制
```swift
// 添加一个取消标识符来追踪当前的加载会话
private var currentLoadingSession: UUID?

// 在加载新URL时生成新的会话ID
func loadURL() {
    let newSession = UUID()
    currentLoadingSession = newSession
    // ... 其他逻辑
}

// 在所有异步操作中检查会话是否仍然有效
guard currentLoadingSession == sessionId else {
    logger.info("Session cancelled, skipping operation")
    return
}
```

### 2. 改进的早期提取机制
```swift
// 存储早期提取的任务，以便能够取消
private var earlyExtractionWorkItem: DispatchWorkItem?

// 在updateUIView中
earlyExtractionWorkItem?.cancel()
let workItem = DispatchWorkItem { [weak self] in
    // 早期提取逻辑
}
earlyExtractionWorkItem = workItem
DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
```

### 3. 更严格的URL匹配
```swift
// 使用更精确的URL比较
func isURLMatch(_ url1: String, _ url2: String) -> Bool {
    let normalized1 = normalizeURL(url1)
    let normalized2 = normalizeURL(url2)
    return normalized1 == normalized2
}
```

### 4. 统一的状态重置
```swift
func resetAllStates() {
    // WebView状态
    webViewInstance?.stopLoading()
    
    // 提取状态
    earlyExtractedText = nil
    earlyExtractedLength = 0
    didSummarizeEarly = false
    
    // 任务状态
    currentSummarizationTask?.cancel()
    earlyExtractionWorkItem?.cancel()
    
    // 会话状态
    currentLoadingSession = nil
}
```

## 完整的改进流程

### 1. 用户点击Slash按钮
1. 生成新的加载会话ID
2. 取消所有正在进行的操作
3. 重置所有状态
4. 更新UI显示"正在加载..."

### 2. WebView加载
1. 验证会话ID是否匹配
2. 停止之前的加载
3. 开始新的加载
4. 设置早期提取定时器（可取消）

### 3. 文本提取
1. 检查会话ID
2. 提取文本
3. 决定是否进行AI总结
4. 更新UI

### 4. AI总结
1. 检查会话ID
2. 取消之前的总结任务
3. 开始新的总结
4. 在总结过程中多次检查取消状态
5. 更新UI

## 关键代码修改建议

### 1. Coordinator类增强
```swift
class Coordinator: NSObject, WKNavigationDelegate {
    // ... 现有属性 ...
    private var currentLoadingSession: UUID?
    private var earlyExtractionWorkItem: DispatchWorkItem?
    
    func startNewLoadingSession() -> UUID {
        let newSession = UUID()
        currentLoadingSession = newSession
        return newSession
    }
    
    func isSessionValid(_ session: UUID) -> Bool {
        return currentLoadingSession == session
    }
    
    func cancelAllOperations() {
        webViewInstance?.stopLoading()
        currentSummarizationTask?.cancel()
        earlyExtractionWorkItem?.cancel()
        resetExtractionState()
        currentLoadingSession = nil
    }
}
```

### 2. loadURL函数改进
```swift
private func loadURL() {
    logger.info("=== Starting new URL load ===")
    
    // 1. 验证URL
    var urlToLoad = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !urlToLoad.isEmpty else {
        logger.info("Search text is empty.")
        return
    }
    
    // 2. 标准化URL
    if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
        urlToLoad = "https://" + urlToLoad
    }
    
    // 3. 发送取消通知（会触发所有正在进行的操作取消）
    NotificationCenter.default.post(name: .cancelWebViewAndSummary, object: nil)
    
    // 4. 立即更新UI状态
    displayText = "正在加载: \(urlToLoad)"
    
    // 5. 更新URL（触发WebView更新）
    if URL(string: urlToLoad) != nil {
        currentURL = urlToLoad
        logger.info("URL updated, WebView will reload: \(currentURL)")
    } else {
        displayText = "无效的URL: \(searchText)"
    }
}
```

### 3. 改进的文本提取检查
```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // 使用更严格的URL匹配
    guard let webViewURL = webView.url,
          isURLMatch(webViewURL.absoluteString, parent.urlString) else {
        logger.warning("URL mismatch, skipping extraction")
        return
    }
    
    // 检查是否有有效的会话
    guard let session = currentLoadingSession else {
        logger.info("No active session, skipping extraction")
        return
    }
    
    // 执行文本提取...
}
```

## 测试场景

1. **快速切换URL**
   - 在页面加载过程中输入新URL
   - 验证旧的加载和AI分析被正确取消

2. **重复点击Slash**
   - 对同一URL多次点击Slash
   - 验证不会有多个AI分析同时进行

3. **网络延迟情况**
   - 在慢速网络下测试
   - 验证取消机制仍然有效

4. **错误处理**
   - 输入无效URL
   - 验证错误状态被正确显示和清理 