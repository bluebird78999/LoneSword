# 访问级别错误修复

## 问题描述
编译错误：`'earlyExtractionWorkItem' is inaccessible due to 'private' protection level`

## 错误原因
`earlyExtractionWorkItem` 是 `Coordinator` 类的私有属性，但在 `WebView` 的 `updateUIView` 方法中试图直接访问它。

## 解决方案
通过添加公共方法来管理私有属性，保持良好的封装性：

### 1. 添加公共方法
```swift
// 取消早期提取任务
func cancelEarlyExtraction() {
    earlyExtractionWorkItem?.cancel()
    earlyExtractionWorkItem = nil
}

// 设置新的早期提取任务
func setEarlyExtractionWorkItem(_ workItem: DispatchWorkItem) {
    // 先取消任何现有的任务
    cancelEarlyExtraction()
    earlyExtractionWorkItem = workItem
}
```

### 2. 修改调用代码
```swift
// 之前（错误）
context.coordinator.earlyExtractionWorkItem?.cancel()
context.coordinator.earlyExtractionWorkItem = workItem

// 之后（正确）
context.coordinator.cancelEarlyExtraction()
context.coordinator.setEarlyExtractionWorkItem(workItem)
```

## 好处
1. **封装性**：私有属性保持私有，通过公共接口访问
2. **安全性**：在设置新任务前自动取消旧任务
3. **可维护性**：集中管理取消逻辑，便于未来修改 