# 更新日志

## 版本 1.1.1 - 主演员隔离编译错误修复

### 修复问题

#### 🔧 主演员隔离(MainActor)编译错误
- **问题**: 在非主演员上下文中调用主演员隔离的方法导致编译错误
- **修复方案**: 
  - 将所有对`LLMService`方法的调用包装在`Task { @MainActor in }`中
  - 修复的调用包括：
    - `cancelCurrentTask()` 在 `deinit` 和 `resetExtractionState` 中
    - `determineProcessingStrategy()` 在 `processExtractedText` 中
    - `getAPIKeyStatus()` 和 `isAPIKeyAvailable()` 在 `checkAPIKeyAndSetInitialMessage` 中

#### 📝 技术细节
```swift
// 修复前 (导致编译错误)
parent.llmService.cancelCurrentTask()

// 修复后 (正确的异步调用)
Task { @MainActor in
    parent.llmService.cancelCurrentTask()
}
```

### 影响的文件
- `ContentView.swift`: 修复了所有对LLMService的同步调用
- 确保了Swift 6并发模型的兼容性

---

## 版本 1.1.0 - URL加载优化与进度条功能

### 新增功能

#### 🔄 URL加载优化
- **修复了URL加载问题**: 确保在点击Slash按钮加载新URL时，正确停止上一次的加载
- **改进的加载流程**: 
  - 在`updateUIView`中添加了`webView.stopLoading()`调用
  - 在`loadURL`函数中立即发送取消通知
  - 重置所有相关状态，确保干净的新加载

#### 📊 加载进度条
- **4像素蓝色进度条**: 在页面顶部添加了视觉加载指示器
- **实时进度更新**: 使用WKWebView的`estimatedProgress`属性实时更新进度
- **流畅动画**: 进度条具有平滑的动画效果
- **智能显示逻辑**: 
  - 开始加载时显示进度条
  - 加载完成后延迟0.5秒隐藏
  - 加载失败或取消时立即隐藏

### 技术实现

#### KVO观察者模式
```swift
// 添加进度监听
webView.addObserver(context.coordinator, 
                   forKeyPath: #keyPath(WKWebView.estimatedProgress), 
                   options: .new, 
                   context: nil)

// 处理进度更新
override func observeValue(forKeyPath keyPath: String?, ...) {
    if keyPath == #keyPath(WKWebView.estimatedProgress) {
        DispatchQueue.main.async {
            self.parent.onProgressChanged(webView.estimatedProgress)
        }
    }
}
```

#### 进度条UI实现
```swift
// 响应式进度条
GeometryReader { geometry in
    HStack(spacing: 0) {
        Rectangle()
            .fill(Color.blue)
            .frame(width: geometry.size.width * loadingProgress, height: 4)
            .animation(.easeInOut(duration: 0.3), value: loadingProgress)
        Spacer(minLength: 0)
    }
}
.frame(height: 4)
.opacity(isLoading ? 1.0 : 0.0)
.animation(.easeInOut(duration: 0.2), value: isLoading)
```

#### 状态管理
- `loadingProgress: Double`: 当前加载进度 (0.0 - 1.0)
- `isLoading: Bool`: 是否正在加载状态
- 自动状态更新和重置机制

### WKNavigationDelegate增强

#### 新增委托方法
- `didStartProvisionalNavigation`: 开始加载时重置进度
- `didCommit`: 确认导航提交
- `didFinish`: 确保进度达到100%
- `didFail`: 加载失败时重置进度
- `didFailProvisionalNavigation`: 预加载失败处理

#### 改进的错误处理
- 区分不同类型的加载错误
- 正确处理取消操作
- 避免在已取消的操作上显示错误消息

### 用户体验改进

1. **视觉反馈**: 用户可以清楚看到页面加载进度
2. **响应性**: 点击Slash按钮立即停止当前加载并开始新的加载
3. **状态一致性**: 所有加载状态(WebView、LLM任务、UI)保持同步
4. **平滑动画**: 进度条和状态变化具有流畅的动画效果

### 兼容性

- iOS 15.0+
- 保持与现有LLMService的完全兼容
- 不影响现有的文本提取和摘要功能

### 测试建议

1. **URL切换测试**: 
   - 在一个页面加载过程中输入新URL并点击Slash
   - 验证旧加载被正确取消，新加载顺利开始

2. **进度条测试**:
   - 观察进度条是否从0%平滑增长到100%
   - 验证加载完成后进度条正确隐藏

3. **错误处理测试**:
   - 测试无效URL的处理
   - 测试网络错误情况下的进度条行为

4. **性能测试**:
   - 快速连续点击Slash按钮
   - 验证没有内存泄漏或observer未移除的问题 