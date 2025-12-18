# 浏览历史持久化功能实现总结

## 功能概述

已成功实现浏览器历史记录的持久化存储和自定义导航功能，支持：
- ✅ 历史记录存储到本地 SwiftData 数据库
- ✅ App 重启后自动加载历史记录
- ✅ 自定义前进/后退导航基于持久化历史
- ✅ 最多保存100条历史记录，自动清理旧记录

---

## 实现细节

### 1. 数据模型 - `BrowserHistory.swift`

#### 修改内容
添加 `visitOrder` 字段用于排序和版本管理。

```swift
@Model
final class BrowserHistory {
    var url: String
    var title: String
    var timestamp: Date
    var visitOrder: Int // 用于排序，数字越大越新
    
    init(url: String, title: String = "", timestamp: Date = Date(), visitOrder: Int = 0) {
        self.url = url
        self.title = title
        self.timestamp = timestamp
        self.visitOrder = visitOrder
    }
}
```

**字段说明**：
- `url`: 页面URL
- `title`: 页面标题
- `timestamp`: 访问时间戳
- `visitOrder`: **新增**，全局递增序号，用于精确排序

---

### 2. 视图模型 - `BrowserViewModel.swift`

#### 新增状态变量

```swift
// 自定义导航历史栈（持久化）
@Published var navigationHistory: [BrowserHistory] = []
private var currentHistoryIndex: Int = -1
private var nextVisitOrder: Int = 0
private var isNavigatingInHistory: Bool = false // 标记是否正在历史导航中

// SwiftData ModelContext reference
private var modelContext: ModelContext?
```

**变量说明**：
- `navigationHistory`: 内存中的历史记录数组（按时间顺序，最旧在前，最新在后）
- `currentHistoryIndex`: 当前在历史栈中的位置索引
- `nextVisitOrder`: 下一个记录的 visitOrder 值
- `isNavigatingInHistory`: 防止前进/后退时重复创建历史记录
- `modelContext`: SwiftData 上下文引用，用于数据库操作

#### 核心方法实现

##### (1) 设置 ModelContext

```swift
func setModelContext(_ context: ModelContext) {
    self.modelContext = context
}
```

##### (2) 加载历史记录

```swift
func loadHistoryFromStorage() {
    guard let context = modelContext else {
        print("DEBUG: ModelContext not set, cannot load history")
        return
    }
    
    do {
        let descriptor = FetchDescriptor<BrowserHistory>(
            sortBy: [SortDescriptor(\.visitOrder, order: .reverse)]
        )
        let allHistory = try context.fetch(descriptor)
        
        // 只取最近100条
        let recentHistory = Array(allHistory.prefix(100))
        
        // 反转顺序，使最旧的在前，最新的在后
        navigationHistory = recentHistory.reversed()
        
        // 设置当前索引为最后一条（最新的）
        currentHistoryIndex = navigationHistory.isEmpty ? -1 : navigationHistory.count - 1
        
        // 设置下一个 visitOrder
        if let lastOrder = allHistory.first?.visitOrder {
            nextVisitOrder = lastOrder + 1
        } else {
            nextVisitOrder = 0
        }
        
        // 更新导航按钮状态
        updateNavigationButtonStates()
        
        print("DEBUG: Loaded \(navigationHistory.count) history records, currentIndex=\(currentHistoryIndex)")
    } catch {
        print("Error loading history: \(error)")
    }
}
```

**工作流程**：
1. 从 SwiftData 按 `visitOrder` 倒序获取所有历史记录
2. 只取最近100条
3. 反转顺序（数组中最旧在前，最新在后）
4. 设置当前索引为最后一条
5. 更新前进/后退按钮状态

##### (3) 添加新历史记录

```swift
private func addToHistory(url: String, title: String) {
    guard let context = modelContext else { return }
    
    // 如果当前不在最新位置，删除当前位置之后的所有记录
    if currentHistoryIndex < navigationHistory.count - 1 {
        let recordsToRemove = navigationHistory[(currentHistoryIndex + 1)...]
        for record in recordsToRemove {
            context.delete(record)
        }
        navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
    }
    
    // 创建新记录
    let newRecord = BrowserHistory(
        url: url,
        title: title,
        timestamp: Date(),
        visitOrder: nextVisitOrder
    )
    nextVisitOrder += 1
    
    // 添加到历史栈
    navigationHistory.append(newRecord)
    currentHistoryIndex = navigationHistory.count - 1
    
    // 保存到 SwiftData
    context.insert(newRecord)
    
    // 限制历史记录数量为100条
    trimHistoryIfNeeded()
    
    // 更新导航按钮状态
    updateNavigationButtonStates()
    
    print("DEBUG: Added history record: \(url), currentIndex=\(currentHistoryIndex)")
}
```

**工作流程**：
1. 如果用户在历史中间位置加载新URL，删除当前位置之后的所有"前进"记录
2. 创建新的 `BrowserHistory` 记录，分配新的 `visitOrder`
3. 添加到内存历史栈
4. 保存到 SwiftData 数据库
5. 检查并限制总数为100条
6. 更新前进/后退按钮状态

##### (4) 限制历史记录数量

```swift
private func trimHistoryIfNeeded() {
    guard let context = modelContext else { return }
    
    if navigationHistory.count > 100 {
        let removeCount = navigationHistory.count - 100
        let recordsToRemove = navigationHistory.prefix(removeCount)
        
        for record in recordsToRemove {
            context.delete(record)
        }
        
        navigationHistory.removeFirst(removeCount)
        currentHistoryIndex -= removeCount
        
        print("DEBUG: Trimmed history to 100 records")
    }
}
```

**工作流程**：
1. 检查历史记录是否超过100条
2. 删除最旧的记录（从数组开头删除）
3. 同时从 SwiftData 数据库中删除
4. 调整当前索引位置

##### (5) 更新导航按钮状态

```swift
private func updateNavigationButtonStates() {
    canGoBack = currentHistoryIndex > 0
    canGoForward = currentHistoryIndex < navigationHistory.count - 1
    print("DEBUG: Navigation state - canGoBack=\(canGoBack), canGoForward=\(canGoForward), index=\(currentHistoryIndex)")
}
```

##### (6) 修改后的 goBack() 方法

```swift
func goBack() {
    guard canGoBack, currentHistoryIndex > 0 else { return }
    
    isNavigatingInHistory = true
    currentHistoryIndex -= 1
    
    let record = navigationHistory[currentHistoryIndex]
    currentURL = record.url
    pageTitle = record.title
    
    // 加载历史URL
    if let url = URL(string: record.url) {
        webView?.load(URLRequest(url: url))
    }
    
    updateNavigationButtonStates()
    
    print("DEBUG: goBack to index=\(currentHistoryIndex), url=\(record.url)")
}
```

**关键改动**：
- ❌ 不再使用 `webView?.goBack()`（WKWebView 内置历史）
- ✅ 使用自定义历史栈 `navigationHistory[currentHistoryIndex - 1]`
- ✅ 设置 `isNavigatingInHistory = true` 防止重复记录
- ✅ 直接加载历史记录中的 URL

##### (7) 修改后的 goForward() 方法

```swift
func goForward() {
    guard canGoForward, currentHistoryIndex < navigationHistory.count - 1 else { return }
    
    isNavigatingInHistory = true
    currentHistoryIndex += 1
    
    let record = navigationHistory[currentHistoryIndex]
    currentURL = record.url
    pageTitle = record.title
    
    // 加载历史URL
    if let url = URL(string: record.url) {
        webView?.load(URLRequest(url: url))
    }
    
    updateNavigationButtonStates()
    
    print("DEBUG: goForward to index=\(currentHistoryIndex), url=\(record.url)")
}
```

**关键改动**：
- ❌ 不再使用 `webView?.goForward()`
- ✅ 使用自定义历史栈 `navigationHistory[currentHistoryIndex + 1]`
- ✅ 设置 `isNavigatingInHistory = true`

##### (8) 修改后的 didFinish 方法

```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    print("DEBUG: didFinish url=\(webView.url?.absoluteString ?? "nil"), isNavigatingInHistory=\(isNavigatingInHistory)")
    DispatchQueue.main.async {
        self.isLoading = false
        self.loadingProgress = 1.0
        self.pageTitle = webView.title ?? ""
        self.currentURL = webView.url?.absoluteString ?? self.currentURL
        
        if !self.currentURL.isEmpty {
            // 只有在非历史导航时才添加到历史记录
            if !self.isNavigatingInHistory {
                self.addToHistory(url: self.currentURL, title: self.pageTitle)
            } else {
                // 重置历史导航标志
                self.isNavigatingInHistory = false
            }
            
            // 触发回调（用于其他功能，如AI分析）
            self.onPageFinished?(self.currentURL, self.pageTitle)
            for handler in self.pageFinishedHandlers { handler(self.currentURL, self.pageTitle) }
        }
    }
}
```

**关键改动**：
- ✅ 检查 `isNavigatingInHistory` 标志
- ✅ 只有在加载新URL时才调用 `addToHistory()`
- ✅ 前进/后退导航不会创建新历史记录

---

### 3. 主视图 - `ContentView.swift`

#### 修改内容

```swift
.onAppear {
    // 设置 ModelContext 并加载历史记录
    browserViewModel.setModelContext(modelContext)
    browserViewModel.loadHistoryFromStorage()
}
```

**工作流程**：
1. App 启动时，将 SwiftData 的 `ModelContext` 传递给 `BrowserViewModel`
2. 调用 `loadHistoryFromStorage()` 从数据库加载最近100条历史
3. 恢复浏览状态

---

## 核心逻辑图

### 历史栈结构示例

```
navigationHistory = [
  BrowserHistory(url: "url1", visitOrder: 1),  // index 0
  BrowserHistory(url: "url2", visitOrder: 2),  // index 1 <- currentHistoryIndex
  BrowserHistory(url: "url3", visitOrder: 3),  // index 2 (可前进)
]

canGoBack = true (currentHistoryIndex > 0)
canGoForward = true (currentHistoryIndex < 2)
```

### 操作流程

#### 1. 加载新URL

```
用户输入新URL或点击链接
↓
didFinish 触发
↓
检查 isNavigatingInHistory = false
↓
调用 addToHistory()
↓
删除 currentHistoryIndex 之后的记录（如果有）
↓
创建新记录，visitOrder++
↓
添加到 navigationHistory 末尾
↓
保存到 SwiftData
↓
currentHistoryIndex = navigationHistory.count - 1
↓
trimHistoryIfNeeded() (限制100条)
↓
updateNavigationButtonStates()
```

#### 2. 点击后退按钮

```
用户点击后退
↓
检查 canGoBack = true
↓
设置 isNavigatingInHistory = true
↓
currentHistoryIndex--
↓
获取 navigationHistory[currentHistoryIndex]
↓
加载该记录的 URL
↓
updateNavigationButtonStates()
↓
didFinish 触发
↓
检查 isNavigatingInHistory = true
↓
跳过 addToHistory()
↓
重置 isNavigatingInHistory = false
```

#### 3. 点击前进按钮

```
用户点击前进
↓
检查 canGoForward = true
↓
设置 isNavigatingInHistory = true
↓
currentHistoryIndex++
↓
获取 navigationHistory[currentHistoryIndex]
↓
加载该记录的 URL
↓
updateNavigationButtonStates()
↓
didFinish 触发
↓
检查 isNavigatingInHistory = true
↓
跳过 addToHistory()
↓
重置 isNavigatingInHistory = false
```

#### 4. App 重启后恢复

```
App 启动
↓
ContentView.onAppear 触发
↓
setModelContext(modelContext)
↓
loadHistoryFromStorage()
↓
从 SwiftData 按 visitOrder 倒序查询
↓
取最近100条
↓
反转顺序存入 navigationHistory
↓
currentHistoryIndex = navigationHistory.count - 1
↓
updateNavigationButtonStates()
↓
前进/后退按钮状态恢复
```

---

## 功能特性

### ✅ 持久化存储
- 使用 SwiftData 存储浏览历史
- App 关闭后数据不丢失
- 重启后自动恢复

### ✅ 智能导航
- 自定义前进/后退基于历史栈
- 不依赖 WKWebView 的内置历史
- 重启后仍可前进/后退

### ✅ 历史管理
- 加载新URL时，清除当前位置之后的"前进"历史
- 自动限制最多100条记录
- 自动清理最旧的记录

### ✅ 避免重复记录
- 使用 `isNavigatingInHistory` 标志
- 前进/后退不创建新历史
- 只有真正加载新URL时才记录

### ✅ 全局排序
- 使用 `visitOrder` 全局递增序号
- 精确排序，避免时间戳冲突
- 支持跨会话排序

---

## 调试日志

### 启动加载历史

```
DEBUG: Loaded 42 history records, currentIndex=41
DEBUG: Navigation state - canGoBack=true, canGoForward=false, index=41
```

### 加载新URL

```
DEBUG: didFinish url=https://example.com, isNavigatingInHistory=false
DEBUG: Added history record: https://example.com, currentIndex=42
DEBUG: Navigation state - canGoBack=true, canGoForward=false, index=42
```

### 点击后退

```
DEBUG: goBack to index=41, url=https://previous.com
DEBUG: didFinish url=https://previous.com, isNavigatingInHistory=true
DEBUG: Navigation state - canGoBack=true, canGoForward=true, index=41
```

### 点击前进

```
DEBUG: goForward to index=42, url=https://example.com
DEBUG: didFinish url=https://example.com, isNavigatingInHistory=true
DEBUG: Navigation state - canGoBack=true, canGoForward=false, index=42
```

### 历史数量达到100条

```
DEBUG: Added history record: https://new.com, currentIndex=100
DEBUG: Trimmed history to 100 records
DEBUG: Navigation state - canGoBack=true, canGoForward=false, index=99
```

---

## 编译状态

```
✅ BUILD SUCCEEDED
✅ 0 Errors
✅ 0 Warnings
```

---

## 文件修改清单

### 修改的文件

1. **`Models/BrowserHistory.swift`**
   - 添加 `visitOrder: Int` 字段

2. **`ViewModels/BrowserViewModel.swift`**
   - 添加 `navigationHistory`、`currentHistoryIndex`、`nextVisitOrder`、`isNavigatingInHistory` 状态变量
   - 添加 `modelContext` 引用
   - 实现 `setModelContext()` 方法
   - 实现 `loadHistoryFromStorage()` 方法
   - 实现 `addToHistory()` 方法
   - 实现 `trimHistoryIfNeeded()` 方法
   - 实现 `updateNavigationButtonStates()` 方法
   - 修改 `goBack()` 方法使用自定义历史栈
   - 修改 `goForward()` 方法使用自定义历史栈
   - 修改 `didFinish` 方法添加历史记录判断

3. **`Views/ContentView.swift`**
   - 修改 `onAppear` 逻辑
   - 设置 ModelContext 并加载历史

---

## 测试建议

### 测试场景

#### 1. 基本导航
- [ ] 访问多个页面（例如：A → B → C）
- [ ] 点击后退按钮：C → B → A
- [ ] 点击前进按钮：A → B → C
- [ ] 验证地址栏和页面内容正确

#### 2. 历史分支
- [ ] 访问：A → B → C
- [ ] 后退到 B
- [ ] 访问新页面 D
- [ ] 验证无法前进到 C（已被删除）
- [ ] 验证历史栈：A → B → D

#### 3. 持久化
- [ ] 访问多个页面
- [ ] 完全关闭 App（终止进程）
- [ ] 重新启动 App
- [ ] 验证可以后退到之前访问的页面
- [ ] 验证前进按钮状态正确

#### 4. 100条限制
- [ ] 访问超过100个不同页面
- [ ] 验证历史记录总数不超过100条
- [ ] 验证最旧的记录被自动删除
- [ ] 重启 App 后验证仍是100条

#### 5. 按钮状态
- [ ] 首次启动：后退禁用，前进禁用
- [ ] 访问一个页面：后退启用，前进禁用
- [ ] 后退一次：后退可能禁用，前进启用
- [ ] 前进到最新：后退启用，前进禁用

#### 6. AI功能兼容
- [ ] 验证加载新页面时 AI 分析正常触发
- [ ] 验证前进/后退时 AI 分析正常触发
- [ ] 验证历史记录保存不影响 AI 功能

---

## 技术优势

### 相比 WKWebView 内置历史的优势

| 特性 | WKWebView 内置历史 | 自定义历史栈 |
|------|-------------------|-------------|
| 持久化 | ❌ 重启后丢失 | ✅ 永久保存 |
| 数量限制 | ❌ 无限制 | ✅ 最多100条 |
| 跨会话导航 | ❌ 不支持 | ✅ 支持 |
| 精确控制 | ❌ 黑盒 | ✅ 完全可控 |
| 数据查询 | ❌ 不支持 | ✅ 随时查询 |
| 清理管理 | ❌ 困难 | ✅ 简单 |

---

## 未来扩展

### 可能的功能增强

1. **历史记录UI**
   - 添加历史记录列表视图
   - 支持搜索历史记录
   - 支持删除单条历史

2. **智能管理**
   - 根据访问频率调整保留策略
   - 自动合并重复访问的URL
   - 智能分组（按日期、按域名）

3. **云同步**
   - 使用 iCloud 同步历史记录
   - 跨设备浏览历史共享

4. **隐私模式**
   - 添加无痕浏览模式
   - 不记录历史

---

**实现完成时间**：2025-10-23  
**实现状态**：✅ 完成并编译通过  
**功能状态**：所有核心功能已实现  
**测试状态**：待用户验证
