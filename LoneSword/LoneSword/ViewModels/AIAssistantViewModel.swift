import Foundation
import Combine
import SwiftData

@MainActor
final class AIAssistantViewModel: ObservableObject {
    @Published var detectAIGenerated: Bool = true
    @Published var autoTranslateChinese: Bool = true
    @Published var autoSummarize: Bool = true
    @Published var isLoading: Bool = false
    @Published var aiSummaryText: String = "AI识别中…"
    @Published var conversationText: String = ""
    
    var displayText: String {
        var result = aiSummaryText
        if !conversationText.isEmpty {
            result += "\n\n——对话记录——\n\n" + conversationText
        }
        return result
    }
    
    var webContentProvider: (() async -> String)?
    private var qwenService: QwenService?
    private var modelContext: ModelContext?
    
    // API Key management
    private let keychainKey = "com.lonesword.qwen.apikey"
    @Published var hasValidPrivateKey: Bool = false
    @Published var privateKeyStatus: String = "未配置私人API Key"
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadAPIKeyFromKeychain() {
        if let apiKey = KeychainService.load(key: keychainKey), !apiKey.isEmpty {
            configureQwen(apiKey: apiKey)
            // 异步验证API Key有效性
            Task {
                await validatePrivateKey(apiKey)
            }
        } else {
            hasValidPrivateKey = false
            privateKeyStatus = "未配置私人API Key"
        }
    }
    
    func saveAPIKeyToKeychain(_ key: String) -> Bool {
        let success = KeychainService.save(key: keychainKey, data: key)
        if success {
            configureQwen(apiKey: key)
            // 异步验证API Key有效性
            Task {
                await validatePrivateKey(key)
            }
        }
        return success
    }
    
    func testAPIKey(_ key: String) async -> Bool {
        let tempService = QwenService(config: .init(apiKey: key))
        do {
            return try await tempService.testKey()
        } catch {
            return false
        }
    }
    
    private func validatePrivateKey(_ key: String) async {
        let isValid = await testAPIKey(key)
        hasValidPrivateKey = isValid
        if isValid {
            privateKeyStatus = "私人API Key有效，无使用限制"
        } else {
            privateKeyStatus = "私人API Key无效，请检查Key是否正确或是否还有用量"
        }
    }
    
    func configureQwen(apiKey: String, endpoint: String = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation") {
        qwenService = QwenService(config: .init(apiKey: apiKey, endpoint: endpoint))
    }
    
    func autoAnalyzeIfEnabled() async {
        // 注意：翻译功能已禁用，不再作为触发条件
        guard detectAIGenerated || autoSummarize else { return }
        
        // Check usage limits (skip if using valid private key)
        if !hasValidPrivateKey {
            guard await checkAndIncrementUsage() else {
                aiSummaryText = "已达到使用次数限制，请升级订阅套餐或配置私人API Key"
                return
            }
        }
        
        let content = await webContentProvider?() ?? ""
        guard !content.isEmpty else {
            aiSummaryText = "网页内容为空"
            return
        }
        
        aiSummaryText = "AI识别中…"
        
        do {
            var processedContent = content
            
            // Step 1: Translation if enabled (已禁用翻译功能，不再调用大模型)
            // if autoTranslateChinese, let qwen = qwenService {
            //     let translationResult = try await qwen.detectAndTranslate(webContent: content)
            //     if translationResult.isTranslated {
            //         processedContent = translationResult.translatedContent
            //     }
            // }
            
            // Step 2: AI detection and summary, Reasioning and Acting.
            if (detectAIGenerated || autoSummarize), let qwen = qwenService {
                // 根据开关状态构建不同的 prompt
                var prompt = "请分析以下内容：\n"
                var needsAIDetection = false
                var needsSummary = false
                
                if detectAIGenerated {
                    prompt += "1) 判断是否为AI生成的内容（回答\"是\"或\"否\"）\n"
                    needsAIDetection = true
                }
                
                if autoSummarize {
                    prompt += "\(needsAIDetection ? "2" : "1")) 生成200字以内的结构化总结\n"
                    needsSummary = true
                }
                
                prompt += "\n请按以下格式回复：\n"
                if needsAIDetection {
                    prompt += "AI生成判断：[是/否]\n"
                }
                if needsSummary {
                    prompt += "内容总结：[总结内容]\n"
                }
                
                let result = try await qwen.call(webContent: processedContent, userQuery: prompt)
                
                // Parse result
                var summaryText = ""
                
                // 只有开启了"识别AI生成"功能时才显示识别结果
                if detectAIGenerated {
                    if result.contains("AI生成判断：是") {
                        summaryText = "**本文可能为AI创作**\n\n"
                    } else {
                        summaryText = "**本文未识别到AI创作**\n\n"
                    }
                }
                
                // 只有开启了"自动总结"功能时才显示总结
                if autoSummarize {
                    if let summaryRange = result.range(of: "内容总结：") {
                        let summary = String(result[summaryRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        summaryText += "内容总结：\(summary)"
                    } else if !detectAIGenerated {
                        // 如果只开启了总结功能且没有找到"内容总结："标记，显示全部结果
                        summaryText = result
                    }
                }
                
                aiSummaryText = summaryText.isEmpty ? "分析完成" : summaryText
            } else {
                // No API configured
                aiSummaryText = "未配置API Key，请在设置中配置"
            }
            
        } catch {
            // 检查是否是API Key相关错误
            if hasValidPrivateKey {
                aiSummaryText = "[API 错误] 私人API Key可能已失效或用量不足，请检查Key状态"
            } else {
                aiSummaryText = "[AI 错误] \(error.localizedDescription)"
            }
        }
    }
    
    func queryFromUser(_ userQuery: String) async {
        // Check usage limits (skip if using valid private key)
        if !hasValidPrivateKey {
            guard await checkAndIncrementUsage() else {
                conversationText += "\n\n已达到使用次数限制，请升级订阅套餐或配置私人API Key"
                return
            }
        }
        
        let content = await webContentProvider?() ?? ""
        
        // Add user query to conversation
        conversationText += "\n\n**用户:** \(userQuery)"
        isLoading = true
        
        do {
            if let qwen = qwenService {
                let result = try await qwen.call(webContent: content, userQuery: userQuery)
                conversationText += "\n\n**AI:** \(result)"
            } else {
                conversationText += "\n\n**AI:** 未配置API Key，请在设置中配置"
            }
        } catch {
            // 检查是否是API Key相关错误
            if hasValidPrivateKey {
                conversationText += "\n\n**AI:** [API 错误] 私人API Key可能已失效或用量不足，请检查Key状态"
            } else {
                conversationText += "\n\n**AI:** [错误] \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Usage Tracking
    
    private func checkAndIncrementUsage() async -> Bool {
        guard let context = modelContext else { return true }
        
        // Fetch or create AISettings
        let descriptor = FetchDescriptor<AISettings>()
        let settings: AISettings
        
        do {
            let allSettings = try context.fetch(descriptor)
            if let existing = allSettings.first {
                settings = existing
            } else {
                settings = AISettings()
                context.insert(settings)
            }
        } catch {
            print("Failed to fetch AISettings: \(error)")
            return true // Allow usage if can't check
        }
        
        // Reset daily counter if needed
        let calendar = Calendar.current
        if !calendar.isDateInToday(settings.lastResetDate) {
            settings.dailyUsageCount = 0
            settings.lastResetDate = Date()
        }
        
        // Get usage limit based on tier
        let limit = getUsageLimitForTier(settings.subscriptionTier)
        
        // Check if within limit
        if settings.dailyUsageCount >= limit {
            return false
        }
        
        // Increment usage
        settings.dailyUsageCount += 1
        settings.totalUsageCount += 1
        
        do {
            try context.save()
        } catch {
            print("Failed to save usage: \(error)")
        }
        
        return true
    }
    
    private func getUsageLimitForTier(_ tier: String) -> Int {
        switch tier {
        case "premium":
            return 100000
        case "basic":
            return 10000
        case "free":
            return 10
        default:
            return 10
        }
    }
    
    func updateSubscriptionTier(_ tier: String) async {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<AISettings>()
        do {
            let allSettings = try context.fetch(descriptor)
            if let settings = allSettings.first {
                settings.subscriptionTier = tier
                try context.save()
            }
        } catch {
            print("Failed to update subscription tier: \(error)")
        }
    }
    
    func resetForNewPage() {
        print("DEBUG: AIAssistantViewModel resetForNewPage called")
        aiSummaryText = "AI识别中…"
        // 可选：清空对话记录
        // conversationText = ""
    }
}
