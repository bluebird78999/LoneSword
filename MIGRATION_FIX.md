# SwiftData 数据迁移错误修复

## 问题描述

App 启动时出现以下错误：

```
CoreData: error: Cannot migrate store in-place: 
Validation error missing attribute values on mandatory destination attribute
entity=BrowserHistory, attribute=visitOrder
```

**原因**：
- 在 `BrowserHistory` 模型中新增了必填字段 `visitOrder`
- 旧数据库中已有的历史记录没有这个字段的值
- SwiftData 无法自动迁移，因为不知道如何为旧记录填充新字段

---

## 解决方案

采用**方案3**：自动删除旧数据库并重新创建

### 优点
- ✅ 最简单直接
- ✅ 自动处理，用户无感知
- ✅ 确保数据库结构一致
- ✅ 避免复杂的迁移逻辑

### 缺点
- ❌ 会丢失旧的浏览历史记录
- ❌ 会丢失旧的 AI 设置

**注意**：由于这是开发阶段的首次添加持久化历史功能，丢失旧数据的影响较小。

---

## 实现细节

### 修改的文件：`LoneSwordApp.swift`

#### 修改前
```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Item.self,
        BrowserHistory.self,
        AISettings.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
```

#### 修改后
```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Item.self,
        BrowserHistory.self,
        AISettings.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        // 如果迁移失败（例如添加了新的必填字段），删除旧数据库并重新创建
        print("⚠️ ModelContainer 创建失败，尝试删除旧数据库: \(error)")
        
        // 获取数据库文件路径
        let url = URL.applicationSupportDirectory.appending(path: "default.store")
        
        // 删除旧数据库文件
        if FileManager.default.fileExists(atPath: url.path()) {
            do {
                try FileManager.default.removeItem(at: url)
                print("✅ 已删除旧数据库文件")
                
                // 同时删除相关的辅助文件
                let shmURL = url.appendingPathExtension("shm")
                let walURL = url.appendingPathExtension("wal")
                try? FileManager.default.removeItem(at: shmURL)
                try? FileManager.default.removeItem(at: walURL)
            } catch {
                print("❌ 删除旧数据库失败: \(error)")
            }
        }
        
        // 重新创建 ModelContainer
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ 成功创建新的 ModelContainer")
            return container
        } catch {
            fatalError("无法创建 ModelContainer，即使在删除旧数据库后: \(error)")
        }
    }
}()
```

---

## 工作流程

### 正常启动（无迁移问题）
```
App 启动
↓
创建 ModelContainer
↓
成功 ✅
↓
加载数据
↓
正常运行
```

### 首次启动（有迁移问题）
```
App 启动
↓
尝试创建 ModelContainer
↓
捕获迁移错误 ⚠️
↓
打印错误日志
↓
检查旧数据库文件是否存在
↓
删除 default.store
↓
删除 default.store.shm
↓
删除 default.store.wal
↓
重新创建 ModelContainer
↓
成功 ✅
↓
使用新的空数据库
↓
正常运行
```

---

## 删除的文件

1. **default.store** - 主数据库文件
2. **default.store.shm** - 共享内存文件（SQLite WAL 模式）
3. **default.store.wal** - 预写日志文件（SQLite WAL 模式）

**位置**：
```
~/Library/Application Support/[Bundle ID]/default.store
```

在设备上：
```
/var/mobile/Containers/Data/Application/[UUID]/Library/Application Support/default.store
```

---

## 日志输出

### 成功删除并重建
```
⚠️ ModelContainer 创建失败，尝试删除旧数据库: SwiftDataError(...)
✅ 已删除旧数据库文件
✅ 成功创建新的 ModelContainer
```

### 如果旧数据库不存在（首次安装）
```
⚠️ ModelContainer 创建失败，尝试删除旧数据库: SwiftDataError(...)
✅ 成功创建新的 ModelContainer
```

### 如果删除失败
```
⚠️ ModelContainer 创建失败，尝试删除旧数据库: SwiftDataError(...)
❌ 删除旧数据库失败: Error(...)
Fatal error: 无法创建 ModelContainer，即使在删除旧数据库后
```

---

## 同时修改：BrowserHistory 模型

为了支持未来的迁移，给 `visitOrder` 字段添加了默认值：

```swift
@Model
final class BrowserHistory {
    var url: String
    var title: String
    var timestamp: Date
    var visitOrder: Int = 0 // 用于排序，数字越大越新（默认值0以支持数据迁移）
    
    init(url: String, title: String = "", timestamp: Date = Date(), visitOrder: Int = 0) {
        self.url = url
        self.title = title
        self.timestamp = timestamp
        self.visitOrder = visitOrder
    }
}
```

**好处**：
- ✅ 如果将来再次出现迁移问题，默认值可以帮助自动迁移
- ✅ 新记录会自动使用默认值 0
- ✅ 代码更健壮

---

## 影响评估

### 用户影响
- ❌ 首次更新后会丢失旧的浏览历史
- ❌ 首次更新后会丢失 AI 设置（API Key 除外，存在 Keychain）
- ✅ 之后的使用不受影响
- ✅ 历史记录会重新积累
- ✅ AI 设置可以重新配置

### 开发影响
- ✅ 解决了启动崩溃问题
- ✅ 未来添加新字段时有参考方案
- ✅ 有了自动恢复机制
- ✅ 不需要手动卸载重装 App

---

## 未来改进建议

### 更优雅的迁移方案

如果将来需要保留旧数据，可以考虑：

#### 1. 自定义迁移逻辑
```swift
// 手动迁移旧数据
let oldRecords = try context.fetch(oldDescriptor)
for oldRecord in oldRecords {
    let newRecord = BrowserHistory(
        url: oldRecord.url,
        title: oldRecord.title,
        timestamp: oldRecord.timestamp,
        visitOrder: 0 // 给旧记录分配默认值
    )
    context.insert(newRecord)
}
```

#### 2. 版本化 Schema
```swift
// 使用 SwiftData 的 Schema 版本管理
let schema = Schema(
    versionedSchema: VersionedSchema(
        version: 2,
        previousSchemas: [VersionedSchema(version: 1)]
    )
)
```

#### 3. 迁移策略
```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .none,
    migrationPlan: CustomMigrationPlan.self
)
```

---

## 测试验证

### 测试场景

#### 1. 干净安装（首次安装）
- [ ] 安装 App
- [ ] 验证正常启动
- [ ] 验证可以保存浏览历史
- [ ] 验证可以保存 AI 设置

#### 2. 从旧版本更新（有迁移问题）
- [ ] 安装旧版本（没有 visitOrder 字段）
- [ ] 创建一些浏览历史
- [ ] 配置 AI 设置
- [ ] 更新到新版本
- [ ] 验证 App 正常启动（旧数据库被删除）
- [ ] 验证浏览历史为空
- [ ] 验证可以创建新的浏览历史

#### 3. 正常运行（无迁移问题）
- [ ] 使用新版本正常浏览
- [ ] 创建浏览历史
- [ ] 关闭 App
- [ ] 重新启动 App
- [ ] 验证浏览历史保留
- [ ] 验证前进/后退功能正常

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

1. **`LoneSwordApp.swift`**
   - 添加迁移失败处理逻辑
   - 自动删除旧数据库
   - 重新创建 ModelContainer

2. **`Models/BrowserHistory.swift`**
   - 给 `visitOrder` 字段添加默认值 `= 0`

---

**修复完成时间**：2025-10-23  
**修复状态**：✅ 完成并编译通过  
**测试状态**：待用户验证

---

## 总结

通过在 `LoneSwordApp.swift` 中添加错误处理逻辑，App 现在可以：

1. ✅ 检测到 SwiftData 迁移失败
2. ✅ 自动删除旧数据库文件
3. ✅ 重新创建新数据库
4. ✅ 正常启动运行

用户首次更新会丢失旧数据，但之后的使用完全正常，历史记录持久化功能正常工作。
