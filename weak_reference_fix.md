# Weak引用错误修复

## 问题描述
编译错误：`'weak' may only be applied to class and class-bound protocol types, not 'ContentView'`

## 错误原因
在`loadURL`函数中的闭包使用了`[weak self]`，但`ContentView`是一个结构体（struct），而不是类（class）。

## Swift中的值类型和引用类型

### 值类型（Value Types）
- **结构体（struct）**：如`ContentView`
- **枚举（enum）**
- 特点：
  - 按值传递（复制）
  - 不存在循环引用问题
  - 不能使用`weak`或`unowned`

### 引用类型（Reference Types）
- **类（class）**：如`Coordinator`
- 特点：
  - 按引用传递
  - 可能存在循环引用
  - 可以使用`weak`或`unowned`

## 解决方案

### 对于结构体中的闭包
```swift
// 错误：结构体不能使用weak
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
    guard let self = self else { return }
    self.currentURL = urlToLoad
}

// 正确：直接使用self
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    self.currentURL = urlToLoad
}
```

### 对于类中的闭包（如Coordinator）
```swift
// 正确：类可以使用weak避免循环引用
self.currentSummarizationTask = Task { [weak self] in
    guard let self = self else { return }
    // 使用self...
}
```

## 何时使用weak

1. **必须使用weak的情况**：
   - 在类的闭包中捕获self，且闭包会被self强引用
   - 避免循环引用导致内存泄漏

2. **不需要weak的情况**：
   - 结构体中的任何闭包
   - 短生命周期的闭包（如动画闭包）
   - 不会被self强引用的闭包

## 最佳实践

1. **结构体**：永远不要使用`weak`或`unowned`
2. **类**：当闭包可能导致循环引用时使用`weak`
3. **不确定时**：查看类型定义（struct vs class） 