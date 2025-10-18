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
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadAPIKeyFromKeychain() {
        if let apiKey = KeychainService.load(key: keychainKey), !apiKey.isEmpty {
            configureQwen(apiKey: apiKey)
        }
    }
    
    func saveAPIKeyToKeychain(_ key: String) -> Bool {
        let success = KeychainService.save(key: keychainKey, data: key)
        if success {
            configureQwen(apiKey: key)
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
    
    func configureQwen(apiKey: String, endpoint: String = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation") {
        qwenService = QwenService(config: .init(apiKey: apiKey, endpoint: endpoint))
    }
    
    func autoAnalyzeIfEnabled() async {
        guard detectAIGenerated || autoTranslateChinese || autoSummarize else { return }
        
        // Check usage limits
        guard await checkAndIncrementUsage() else {
            aiSummaryText = "已达到使用次数限制，请升级订阅套餐"
            return
        }
        
        let content = await webContentProvider?() ?? ""
        guard !content.isEmpty else {
            aiSummaryText = "网页内容为空"
            return
        }
        
        aiSummaryText = "AI识别中…"
        
        do {
            var processedContent = content
            
            // Step 1: Translation if enabled
            if autoTranslateChinese, let qwen = qwenService {
                let translationResult = try await qwen.detectAndTranslate(webContent: content)
                if translationResult.isTranslated {
                    processedContent = translationResult.translatedContent
                }
            }
            
            // Step 2: AI detection and summary
            if (detectAIGenerated || autoSummarize), let qwen = qwenService {
                let prompt = """
                请分析以下内容：
                1) 判断是否为AI生成的内容（回答"是"或"否"）
                2) 生成200字以内的结构化总结
                
                请按以下格式回复：
                AI生成判断：[是/否]
                内容总结：[总结内容]
                """
                
                let result = try await qwen.call(webContent: processedContent, userQuery: prompt)
                
                // Parse result
                var summaryText = ""
                if detectAIGenerated && result.contains("AI生成判断：是") {
                    summaryText = "**本文可能为AI创作**\n\n"
                }
                
                // Extract summary
                if let summaryRange = result.range(of: "内容总结：") {
                    let summary = String(result[summaryRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    summaryText += "内容总结：\(summary)"
                } else {
                    summaryText += result
                }
                
                aiSummaryText = summaryText
            } else {
                // No API configured
                aiSummaryText = "未配置API Key，请在设置中配置"
            }
            
        } catch {
            aiSummaryText = "[AI 错误] \(error.localizedDescription)"
        }
    }
    
    func queryFromUser(_ userQuery: String) async {
        // Check usage limits
        guard await checkAndIncrementUsage() else {
            conversationText += "\n\n已达到使用次数限制，请升级订阅套餐"
            return
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
            conversationText += "\n\n**AI:** [错误] \(error.localizedDescription)"
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
}
