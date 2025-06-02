# LoneSword 
![icon-1024](https://github.com/user-attachments/assets/ce694f23-46db-46a4-9c7e-a0ae6a1cfbe4)


LoneSword: An Efficient Information Browsing Tool for Discerning Truth in the AI Era.

用AI对抗AI时代的网络熵增,一个基于SwiftUI和WebKit的现代iOS浏览器应用，当前只完成浏览器基本功能，AI功能开发中。

## 功能特性

### 🌐 浏览器界面
- **智能地址栏**: 自动格式化域名，根据需要添加 `http://`、`https://`、`www.`
- **导航按钮**: 前进/后退按钮，有历史记录时显示蓝色可点击，无历史时显示灰色不可点击
- **Slash按钮**: 蓝色按钮，点击时停止当前加载并开始加载地址栏中的URL
- **UserAgent切换**: 多模式循环切换按钮，支持4种不同的UserAgent
  - **SF** (蓝色): Safari UserAgent，与iOS Safari完全相同
  - **LS** (橙色): LoneSword Browser UserAgent，自定义品牌标识
  - **CI** (绿色): Chrome iOS UserAgent，模拟iOS版Chrome浏览器
  - **CP** (红色): Chrome PC UserAgent，模拟Windows版Chrome浏览器
- **多选项功能**: 三个可选功能（翻译、AI总结、AI判别），默认未选中，选中时显示蓝色勾选状态
- **进度条**: 顶部2像素的网页加载进度条，从屏幕最左侧到最右侧，根据加载百分比动态调整

### 📱 WebView集成
- 地址栏下方整个屏幕区域为WebView
- 正确的URL加载和停止功能
- URL加载进度关联顶部进度条长度
- 支持手势导航（左右滑动前进后退）
- 支持内联媒体播放

### 📚 URL历史记录管理
- 完整的浏览历史记录，支持前进/后退导航
- 自动URL处理（根据需要添加协议和www前缀）
- 导航时地址栏自动更新
- 智能搜索：输入非URL格式内容时自动使用Google搜索

## 技术实现

### 架构
- **SwiftUI**: 现代声明式UI框架
- **WebKit**: 原生Web浏览引擎
- **MVVM模式**: 清晰的数据绑定和状态管理
- **Combine**: 响应式编程处理状态更新

### 核心组件
1. **ContentView**: 主视图容器
2. **BrowserToolbar**: 工具栏组件（地址栏、导航按钮、选项）
3. **WebViewContainer**: WebKit集成组件
4. **ProgressBar**: 加载进度指示器
5. **BrowserViewModel**: 业务逻辑和状态管理

### 智能URL处理
```swift
// 自动添加协议
if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
    urlString = "https://" + urlString
}

// 智能添加www前缀
if host.components(separatedBy: ".").count == 2 && !host.hasPrefix("www.") {
    urlString = urlString.replacingOccurrences(of: "://\(host)", with: "://www.\(host)")
}

// 搜索查询检测
if !urlString.contains(".") || urlString.contains(" ") {
    return "https://www.google.com/search?q=" + encodedQuery
}
```

### UserAgent 管理
```swift
// UserAgent类型枚举
enum UserAgentType: Int, CaseIterable {
    case safari = 0      // Safari UserAgent
    case loneSword = 1   // LoneSword Browser UserAgent  
    case chromeIOS = 2   // Chrome iOS UserAgent
    case chromePC = 3    // Chrome PC UserAgent
}

// 动态设备信息获取
class DeviceInfo {
    var iosVersion: String { UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_") }
    var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var safariUserAgent: String {
        if isIPad {
            return "Mozilla/5.0 (iPad; CPU OS \(iosVersion) like Mac OS X) AppleWebKit/605.1.15..."
        } else {
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosVersion) like Mac OS X) AppleWebKit/605.1.15..."
        }
    }
}

// 循环切换 UserAgent
func toggleUserAgent() {
    let allCases = UserAgentType.allCases
    let currentIndex = allCases.firstIndex(of: currentUserAgentType) ?? 0
    let nextIndex = (currentIndex + 1) % allCases.count
    currentUserAgentType = allCases[nextIndex]
}
```

## 安装和运行

### 系统要求
- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

### 构建步骤
1. 克隆或下载项目
2. 在Xcode中打开 `LoneSword.xcodeproj`
3. 选择目标设备或模拟器
4. 点击运行按钮或按 `Cmd+R`

### 配置说明
项目已配置了必要的网络安全传输设置（`Info.plist`）：
- `NSAllowsArbitraryLoads`: 允许加载任意网站
- `NSAllowsArbitraryLoadsInWebContent`: 允许WebView加载任意内容

## 使用方法

### 基本浏览
1. 在地址栏输入网址或搜索关键词
2. 按回车键或点击"Slash"按钮开始加载
3. 使用前进/后退按钮导航历史记录
4. 观察顶部进度条了解加载状态

### UserAgent 管理
1. 点击工具栏中的 UserAgent 按钮循环切换不同模式
2. **SF** (蓝色): Safari UserAgent，网站识别为iOS Safari浏览器
3. **LS** (橙色): LoneSword Browser UserAgent，网站识别为LoneSword浏览器
4. **CI** (绿色): Chrome iOS UserAgent，网站识别为iOS版Chrome浏览器
5. **CP** (红色): Chrome PC UserAgent，网站识别为Windows版Chrome浏览器
6. iOS版本的UserAgent会自动获取当前设备的真实信息（设备型号、iOS版本等）
7. 可以访问 `localhost:8080/test_useragent.html` 测试UserAgent效果

### 智能输入示例
- `google.com` → `https://www.google.com`
- `github.com` → `https://www.github.com`
- `hello world` → Google搜索"hello world"
- `https://example.com` → 直接加载

### 功能选项（还未实现功能）
- **翻译**: 启用网页翻译功能
- **AI总结**: 启用AI内容总结
- **AI判别**: 启用AI内容判别

## 项目结构

```
LoneSword/
├── LoneSword/
│   ├── LoneSwordApp.swift      # 应用入口点
│   ├── ContentView.swift       # 主视图和所有组件
│   ├── Info.plist             # 应用配置
│   └── Assets.xcassets/       # 应用资源
├── LoneSwordTests/            # 单元测试
├── LoneSwordUITests/          # UI测试
└── LoneSword.xcodeproj/       # Xcode项目文件
```

## 特色功能

### 🎯 智能进度条
- 仅在加载时显示（0% < 进度 < 100%）
- 平滑动画效果
- 加载完成后自动隐藏

### 🔧 UserAgent 管理
- **四模式循环切换**: Safari → LoneSword → Chrome iOS → Chrome PC
- **智能设备识别**: iOS版本UserAgent自动获取真实设备信息
- **实时生效**: 切换后立即应用到所有新请求
- **视觉指示**: SF(蓝色) / LS(橙色) / CI(绿色) / CP(红色) 按钮状态清晰
- **兼容性优先**: 默认使用Safari UserAgent确保最佳兼容性

### 🔄 内存管理
- 使用weak引用避免循环引用
- 正确的KVO观察者管理
- 自动清理资源

### 🎨 用户体验
- 响应式设计适配不同屏幕尺寸
- 直观的视觉反馈
- 流畅的动画过渡
- 键盘友好的输入体验

### 自定义选项
三个多选项功能可以根据需要实现具体逻辑：
```swift
// 在BrowserViewModel中添加功能逻辑
@Published var option1: Bool = false // 翻译
@Published var option2: Bool = false // AI总结  
@Published var option3: Bool = false // AI判别
```

## 许可证
MIT协议！

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。

---
