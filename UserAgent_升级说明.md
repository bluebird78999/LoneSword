# LoneSword Browser UserAgent 功能升级说明

## 🚀 升级概述

LoneSword Browser 的 UserAgent 功能已从双模式切换升级为四模式循环切换，新增了 Chrome iOS 和 Chrome PC 模拟功能，并实现了智能设备信息获取。

## 🆕 新增功能

### 1. Chrome 浏览器模拟
- **Chrome iOS**: 模拟 iOS 版 Chrome 浏览器 (CriOS)
- **Chrome PC**: 模拟 Windows 版 Chrome 浏览器

### 2. 智能设备信息获取
- 自动检测当前设备型号 (iPhone/iPad)
- 动态获取真实 iOS 版本
- 根据设备类型生成对应的 UserAgent

### 3. 循环切换机制
- 点击按钮在 4 种模式间循环切换
- 每种模式都有独特的颜色标识
- 实时显示当前模式状态

## 🎯 四种 UserAgent 模式

### 1. 🔵 Safari (SF) - 默认模式
```
Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1
```
- **用途**: 日常浏览，最佳兼容性
- **识别**: iOS Safari 浏览器
- **特点**: 使用真实设备信息

### 2. 🟠 LoneSword (LS) - 品牌模式
```
Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) LoneSword/0.1 Mobile/15E148 Safari/604.1
```
- **用途**: 品牌展示，统计追踪
- **识别**: LoneSword Browser
- **特点**: 自定义品牌标识

### 3. 🟢 Chrome iOS (CI) - iOS Chrome 模拟
```
Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/120.0.6099.119 Mobile/15E148 Safari/604.1
```
- **用途**: 模拟 iOS Chrome，测试兼容性
- **识别**: iOS 版 Chrome 浏览器
- **特点**: 使用真实设备信息 + Chrome 标识

### 4. 🔴 Chrome PC (CP) - PC Chrome 模拟
```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
```
- **用途**: 访问桌面版网站，绕过移动端限制
- **识别**: Windows 版 Chrome 浏览器
- **特点**: 完整的桌面浏览器标识

## 🔧 技术实现细节

### 设备信息获取
```swift
class DeviceInfo {
    // 获取设备型号
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        // 解析机器标识符...
    }
    
    // 获取iOS版本
    var iosVersion: String {
        UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
    }
    
    // 判断设备类型
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
```

### 循环切换逻辑
```swift
enum UserAgentType: Int, CaseIterable {
    case safari = 0, loneSword = 1, chromeIOS = 2, chromePC = 3
}

func toggleUserAgent() {
    let allCases = UserAgentType.allCases
    let currentIndex = allCases.firstIndex(of: currentUserAgentType) ?? 0
    let nextIndex = (currentIndex + 1) % allCases.count
    currentUserAgentType = allCases[nextIndex]
}
```

## 🎨 用户界面更新

### 按钮设计
- **尺寸**: 28x24 像素 (增加宽度以容纳两字符)
- **字体**: 10pt 粗体 (适应更小空间)
- **颜色**: 4种不同颜色区分模式

### 状态指示
| 模式 | 显示 | 颜色 | 含义 |
|------|------|------|------|
| Safari | SF | 🔵 蓝色 | 标准Safari |
| LoneSword | LS | 🟠 橙色 | 自定义浏览器 |
| Chrome iOS | CI | 🟢 绿色 | iOS版Chrome |
| Chrome PC | CP | 🔴 红色 | PC版Chrome |

## 🧪 测试功能增强

### 测试页面更新
- 支持检测所有 4 种 UserAgent 类型
- 自动识别 Chrome iOS (CriOS) 和 Chrome PC
- 显示详细的设备和系统信息
- 实时刷新检测 UserAgent 变化

### 检测逻辑
```javascript
if (ua.includes('LoneSword')) {
    info.push('🗡️ LoneSword Browser 自定义 UserAgent');
} else if (ua.includes('CriOS')) {
    info.push('🟢 Chrome iOS UserAgent');
} else if (ua.includes('Chrome') && ua.includes('Windows')) {
    info.push('🔴 Chrome PC UserAgent (Windows)');
} else if (ua.includes('Safari') && ua.includes('Version')) {
    info.push('🔵 Safari UserAgent (默认)');
}
```

## 🎯 应用场景扩展

### Chrome iOS 模式
- ✅ 测试网站对 Chrome iOS 的兼容性
- ✅ 访问 Chrome 专属功能
- ✅ 绕过 Safari 特定限制
- ✅ 开发调试和测试

### Chrome PC 模式
- 🖥️ 访问桌面版网站
- 🖥️ 绕过移动端功能限制
- 🖥️ 获取完整网页体验
- 🖥️ 测试响应式设计

## 📊 兼容性对比

| 模式 | 移动端兼容性 | 桌面端兼容性 | 特殊功能 | 推荐用途 |
|------|-------------|-------------|----------|----------|
| Safari | 🟢 最佳 | 🟡 良好 | iOS特性 | 日常浏览 |
| LoneSword | 🟢 最佳 | 🟡 良好 | 品牌标识 | 统计分析 |
| Chrome iOS | 🟢 优秀 | 🟡 良好 | Chrome特性 | 兼容性测试 |
| Chrome PC | 🔴 受限 | 🟢 最佳 | 桌面功能 | 桌面体验 |

## 🔄 使用流程

1. **启动应用**: 默认 Safari 模式 (SF 蓝色)
2. **第一次点击**: 切换到 LoneSword 模式 (LS 橙色)
3. **第二次点击**: 切换到 Chrome iOS 模式 (CI 绿色)
4. **第三次点击**: 切换到 Chrome PC 模式 (CP 红色)
5. **第四次点击**: 循环回到 Safari 模式 (SF 蓝色)

## 🚀 未来扩展计划

### 短期计划
- [ ] 添加更多浏览器模拟 (Firefox, Edge)
- [ ] 支持自定义 UserAgent 编辑
- [ ] 按网站自动切换 UserAgent

### 长期计划
- [ ] UserAgent 历史记录
- [ ] 智能推荐最佳 UserAgent
- [ ] 与网站兼容性数据库集成

## 📝 注意事项

1. **设备信息准确性**: iOS 版本的 UserAgent 使用真实设备信息
2. **兼容性考虑**: Chrome PC 模式可能导致某些移动端功能不可用
3. **测试建议**: 使用测试页面验证 UserAgent 切换效果
4. **性能影响**: UserAgent 切换对性能影响微乎其微

---

**LoneSword Browser** - 更强大、更灵活的 UserAgent 管理系统 🗡️ 