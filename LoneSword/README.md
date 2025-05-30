# LoneSword - 网页内容AI总结应用

## 项目概述

LoneSword是一个iOS应用，可以加载网页内容并使用AI大模型进行智能总结。

## 最新更新 - LLMService抽象重构

### 重构内容

1. **创建了独立的LLMService类** (`LLMService.swift`)
   - 将所有大模型API请求和响应处理逻辑从ContentView.swift中抽象出来
   - 提供了清晰的公共接口用于文本摘要处理
   - 支持流式响应和实时进度更新

2. **移除了ContentView.swift中的冗余代码**
   - 删除了APIError枚举
   - 删除了QwenRequest、QwenResponse、QwenStreamChunk结构体
   - 删除了QwenAPIManager类
   - 简化了ContentView的职责，专注于UI逻辑

### LLMService类特性

#### 核心功能
- **API密钥管理**: 自动检测和验证DASHSCOPE_API_KEY环境变量
- **异步文本摘要**: 支持大文本的智能摘要处理
- **流式响应**: 实时显示AI生成的内容
- **任务管理**: 支持取消正在进行的摘要任务
- **错误处理**: 完善的错误类型和本地化错误信息

#### 智能处理策略
- **早期文本处理**: 当文本长度超过2000字符时启动早期摘要
- **最终文本优化**: 根据文本长度变化决定是否重新摘要
- **策略决策**: 自动判断最佳的处理时机和方式

#### 公共接口

```swift
// 检查API密钥状态
func isAPIKeyAvailable() -> Bool
func getAPIKeyStatus() -> String

// 文本摘要处理
func summarizeText(_ text: String, onProgress: @escaping (String) -> Void) async throws -> String

// 任务管理
func cancelCurrentTask()

// 处理策略决定
func determineProcessingStrategy(currentText: String, previousText: String?, isEarlyAttempt: Bool) -> TextProcessingStrategy
```

### 使用方式

在ContentView中，现在只需要：

```swift
// 创建LLMService实例
@StateObject private var llmService = LLMService()

// 在WebView中传递服务实例
WebView(
    urlString: $currentURL,
    onTextExtracted: { text in
        self.displayText = text
    },
    llmService: llmService
)

// 使用服务进行摘要
let summary = try await llmService.summarizeText(text) { progressText in
    // 实时更新UI
    DispatchQueue.main.async {
        self.onTextExtracted(progressText)
    }
}
```

### 优势

1. **代码分离**: UI逻辑和API逻辑完全分离
2. **可重用性**: LLMService可以在其他地方复用
3. **可测试性**: 独立的服务类更容易进行单元测试
4. **可维护性**: 代码结构更清晰，职责分明
5. **扩展性**: 可以轻松添加新的AI服务或功能

### 环境要求

- iOS 15.0+
- Xcode 14.0+
- 需要设置DASHSCOPE_API_KEY环境变量

### API配置

应用使用阿里云通义千问(Qwen)模型，需要在环境变量中设置：

```bash
export DASHSCOPE_API_KEY="your_api_key_here"
```

### 项目结构

```
LoneSword/
├── LoneSword/
│   ├── ContentView.swift      # 主UI界面
│   ├── LLMService.swift       # AI服务抽象类
│   ├── LoneSwordApp.swift     # 应用入口
│   └── ...
└── README.md
``` 