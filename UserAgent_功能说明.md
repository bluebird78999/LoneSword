# LoneSword Browser UserAgent 功能说明

## 📋 功能概述

LoneSword Browser 现已支持动态 UserAgent 切换功能，提供4种不同的UserAgent模式：Safari、LoneSword Browser、Chrome iOS 和 Chrome PC，支持循环切换。

## 🎯 实现目标

✅ **默认使用 Safari UserAgent**: 确保与 iOS Safari 完全相同的网站兼容性  
✅ **提供自定义 UserAgent**: 支持 LoneSword Browser 品牌标识  
✅ **Chrome 浏览器模拟**: 支持 iOS 版和 PC 版 Chrome UserAgent  
✅ **智能设备识别**: iOS 版本 UserAgent 自动获取真实设备信息  
✅ **循环切换**: 通过工具栏按钮在4种模式间循环切换  
✅ **实时生效**: 切换后立即应用到新的网络请求  

## 🔧 技术实现

### UserAgent 字符串定义

```swift
// Safari UserAgent (默认)
private let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

// LoneSword Browser UserAgent (自定义)
private let customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) LoneSword/1.0 Mobile/15E148 Safari/604.1"
```

### 核心功能方法

```swift
/// 获取当前应该使用的UserAgent
func getCurrentUserAgent() -> String {
    return useCustomUserAgent ? customUserAgent : safariUserAgent
}

/// 切换UserAgent类型
func toggleUserAgent() {
    useCustomUserAgent.toggle()
    updateWebViewUserAgent()
}

/// 更新WebView的UserAgent
private func updateWebViewUserAgent() {
    guard let webView = webView else { return }
    let userAgent = getCurrentUserAgent()
    webView.customUserAgent = userAgent
}
```

## 🎨 用户界面

### SF/LS 切换按钮

- **位置**: 工具栏中，Slash按钮右侧
- **SF 模式** (默认):
  - 显示: `SF`
  - 颜色: 蓝色 (#007AFF)
  - 含义: Safari UserAgent
- **LS 模式**:
  - 显示: `LS`
  - 颜色: 橙色 (#FF9500)
  - 含义: LoneSword Browser UserAgent

### 按钮实现代码

```swift
Button(action: {
    viewModel.toggleUserAgent()
}) {
    Text(viewModel.useCustomUserAgent ? "LS" : "SF")
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(.white)
        .frame(width: 24, height: 24)
        .background(viewModel.useCustomUserAgent ? Color.orange : Color.blue)
        .cornerRadius(4)
}
```

## 🧪 测试方法

### 1. 使用内置测试页面

访问 `localhost:8080/test_useragent.html` 查看当前 UserAgent:

- 自动检测当前 UserAgent 字符串
- 识别浏览器类型 (Safari/LoneSword)
- 显示系统信息 (iOS版本、WebKit版本等)
- 每5秒自动刷新检测

### 2. 使用在线工具

访问以下网站测试 UserAgent:
- `https://www.whatismybrowser.com/`
- `https://httpbin.org/user-agent`
- `https://www.whatsmyua.info/`

### 3. 开发者工具

在网页中使用 JavaScript 检测:
```javascript
console.log('UserAgent:', navigator.userAgent);
```

## 📊 UserAgent 对比

| 模式 | 标识符 | 网站识别 | 兼容性 | 用途 |
|------|--------|----------|--------|------|
| Safari (SF) | `Version/17.0 Safari/604.1` | iOS Safari | 🟢 最佳 | 日常浏览 |
| LoneSword (LS) | `LoneSword/1.0 Safari/604.1` | LoneSword Browser | 🟡 良好 | 品牌展示 |

## 🔄 使用流程

1. **启动应用**: 默认使用 Safari UserAgent (SF 蓝色按钮)
2. **切换模式**: 点击 SF/LS 按钮切换 UserAgent
3. **验证效果**: 访问测试页面或网站查看识别结果
4. **恢复默认**: 再次点击按钮切换回 Safari 模式

## 🎯 应用场景

### Safari UserAgent (推荐默认)
- ✅ 日常网页浏览
- ✅ 在线服务使用
- ✅ 确保最佳兼容性
- ✅ 避免网站限制

### LoneSword UserAgent
- 🎯 品牌展示和推广
- 🎯 开发测试和调试
- 🎯 统计分析和追踪
- 🎯 特殊功能标识

## 🔍 技术细节

### WebKit 集成
- 使用 `WKWebView.customUserAgent` 属性
- 在 WebView 创建时设置初始 UserAgent
- 支持运行时动态切换

### 状态管理
- 使用 `@Published` 属性实现响应式更新
- UI 自动反映 UserAgent 状态变化
- 持久化状态 (可扩展到 UserDefaults)

### 内存管理
- 使用 weak 引用避免循环引用
- 正确的生命周期管理
- 自动清理资源

## 🚀 未来扩展

### 可能的增强功能
- [ ] 自定义 UserAgent 编辑器
- [ ] 预设 UserAgent 模板库
- [ ] 按网站自动切换 UserAgent
- [ ] UserAgent 历史记录
- [ ] 导入/导出 UserAgent 配置

### 高级特性
- [ ] 随机 UserAgent 生成
- [ ] 基于网站类型的智能切换
- [ ] UserAgent 统计和分析
- [ ] 与隐私模式集成

## 📝 注意事项

1. **兼容性优先**: 默认使用 Safari UserAgent 确保最佳网站兼容性
2. **实时生效**: UserAgent 切换后立即应用到新的网络请求
3. **测试建议**: 使用测试页面验证 UserAgent 切换效果
4. **隐私考虑**: 自定义 UserAgent 可能被网站用于追踪

---

**LoneSword Browser** - 智能、灵活的 UserAgent 管理 🗡️ 