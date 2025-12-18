//
//  LoneSwordApp.swift
//  LoneSword
//
//  Created by LiuHongfeng on 2025/10/18.
//

import SwiftUI
import SwiftData

@main
struct LoneSwordApp: App {
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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
