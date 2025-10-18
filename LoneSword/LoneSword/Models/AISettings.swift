import Foundation
import SwiftData

@Model
final class AISettings {
    var detectAIGenerated: Bool = true
    var autoTranslateChinese: Bool = true
    var autoSummarize: Bool = true
    
    // Subscription tracking
    var subscriptionTier: String = "free" // "free", "basic", "premium"
    var dailyUsageCount: Int = 0
    var lastResetDate: Date = Date()
    var totalUsageCount: Int = 0
    
    init() {}
}
