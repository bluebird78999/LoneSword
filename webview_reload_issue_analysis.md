# WebView重新加载问题分析

## 问题描述
用户报告重新加载URL时WebView没有刷新。

## 问题原因

### 1. 初始状态不一致
```swift
@State private var searchText: String = "https://www.163.com/news/article/K0RCE23F000189FH.html"
@State private var currentURL: String = "" // 空字符串
```
- `searchText`有初始值，但`currentURL`是空字符串
- 这导致应用启动时WebView处于未加载状态，但输入框显示了URL

### 2. URL比较逻辑问题
原始的URL比较逻辑过于简单：
```swift
let shouldLoad = webView.url == nil || webView.url?.absoluteString != urlString
```
这个逻辑没有考虑：
- URL重定向（如从http到https）
- URL末尾的斜杠差异
- www前缀的差异
- Fragment标识符（#后面的部分）

### 3. WebView状态管理
当`currentURL`为空时，第一次调用`updateUIView`可能会进入错误的分支，导致后续加载失败。

## 解决方案

### 1. 自动加载初始URL
```swift
private func checkAPIKeyAndSetInitialMessage() {
    // ... API Key检查 ...
    if URL(string: currentURL) != nil {
        displayText = "Initial page loaded. Enter a new URL or tap Slash to reload and summarize."
    } else {
        displayText = "Enter a valid URL and tap Slash."
        // 如果searchText有初始值但currentURL为空，自动加载
        if !searchText.isEmpty && currentURL.isEmpty {
            logger.info("Initial searchText found, auto-loading: \(searchText)")
            loadURL()
        }
    }
}
```

### 2. 改进的URL比较逻辑
```swift
// 添加URL标准化函数
private func normalizeURL(_ urlString: String) -> String {
    var normalized = urlString.lowercased()
    // 移除末尾斜杠
    if normalized.hasSuffix("/") {
        normalized = String(normalized.dropLast())
    }
    // 移除www前缀
    normalized = normalized.replacingOccurrences(of: "://www.", with: "://")
    // 移除fragment标识符
    if let fragmentRange = normalized.range(of: "#") {
        normalized = String(normalized[..<fragmentRange.lowerBound])
    }
    return normalized
}

// 改进的shouldLoad判断
let shouldLoad: Bool
if let currentURL = webView.url {
    let normalizedCurrent = normalizeURL(currentURL.absoluteString)
    let normalizedNew = normalizeURL(urlString)
    shouldLoad = normalizedCurrent != normalizedNew
} else {
    shouldLoad = true
}
```

### 3. 增强的调试日志
```swift
logger.info("UpdateUIView called with urlString: \(urlString)")
logger.info("Current webView.url: \(webView.url?.absoluteString ?? "nil")")
logger.info("Normalized current: \(normalizedCurrent), Normalized new: \(normalizedNew), shouldLoad: \(shouldLoad)")
```

## 关键改进

1. **初始状态一致性**：确保应用启动时自动加载searchText中的URL
2. **智能URL比较**：处理各种URL变体情况
3. **更好的状态管理**：确保WebView状态与UI状态同步
4. **详细日志**：帮助追踪加载流程

## 测试场景

1. **应用启动测试**
   - 启动应用，验证初始URL是否自动加载
   - 检查WebView是否显示正确的页面

2. **URL重新加载测试**
   - 点击Slash按钮重新加载相同的URL
   - 验证WebView是否刷新

3. **URL切换测试**
   - 输入新URL并点击Slash
   - 验证是否正确加载新页面

4. **重定向测试**
   - 加载一个会重定向的URL
   - 再次点击Slash，验证是否正确处理 