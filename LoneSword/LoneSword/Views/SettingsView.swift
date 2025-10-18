import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject var vm: AIAssistantViewModel
    @StateObject private var storeManager = StoreKitManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKeyInput: String = ""
    @State private var isTestingKey: Bool = false
    @State private var testResult: String?
    
    let backgroundColor = Color.white
    let textColor = Color.black
    let accentBlue = Color(red: 0, green: 0.478, blue: 1)
    let lightGray = Color(red: 0.96, green: 0.96, blue: 0.96)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // API Key Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API 配置")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("私人Qwen API Key，检测Key有效则默认使用，不配置则不使用")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(textColor)
                            
                            VStack(spacing: 12) {
                                // API Key 输入框
                                SecureField("请输入API Key", text: $apiKeyInput)
                                    .font(.system(size: 16))
                                    .foregroundColor(textColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(lightGray)
                                    .cornerRadius(8)
                                
                                // 按钮行
                                HStack(spacing: 12) {
                                    Button(action: { testAPIKey() }) {
                                        HStack {
                                            if isTestingKey {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .scaleEffect(0.8)
                                            } else {
                                                Text("测试")
                                                    .font(.system(size: 16, weight: .medium))
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .background(accentBlue)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isTestingKey || apiKeyInput.isEmpty)
                                    
                                    Button(action: { saveAPIKey() }) {
                                        Text("保存")
                                            .font(.system(size: 16, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 12)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                    .disabled(apiKeyInput.isEmpty)
                                }
                            }
                            
                            if let result = testResult {
                                Text(result)
                                    .font(.system(size: 14))
                                    .foregroundColor(result.contains("成功") ? .green : .red)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Subscription Tiers Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("订阅版本")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textColor)
                        
                        // Free Tier
                        SubscriptionTierCard(
                            title: "免费版",
                            price: "免费",
                            features: ["每天10次AI分析", "基础功能"],
                            isCurrentTier: storeManager.getCurrentTier() == "free",
                            isPurchased: true,
                            accentBlue: accentBlue,
                            onPurchase: nil
                        )
                        
                        // Basic Tier
                        if let basicProduct = storeManager.products.first(where: { $0.id == "com.lonesword.subscription.basic" }) {
                            SubscriptionTierCard(
                                title: "基础版",
                                price: "¥19.9/月",
                                features: ["10,000次AI分析/月", "优先处理", "邮件支持"],
                                isCurrentTier: storeManager.getCurrentTier() == "basic",
                                isPurchased: storeManager.purchasedProductIDs.contains(basicProduct.id),
                                accentBlue: accentBlue,
                                onPurchase: { Task { await purchaseProduct(basicProduct) } }
                            )
                        } else {
                            SubscriptionTierCard(
                                title: "基础版",
                                price: "¥19.9/月",
                                features: ["10,000次AI分析/月", "优先处理", "邮件支持"],
                                isCurrentTier: false,
                                isPurchased: false,
                                accentBlue: accentBlue,
                                onPurchase: nil
                            )
                        }
                        
                        // Premium Tier
                        if let premiumProduct = storeManager.products.first(where: { $0.id == "com.lonesword.subscription.premium" }) {
                            SubscriptionTierCard(
                                title: "高级版",
                                price: "¥39.9/月",
                                features: ["100,000次AI分析/月", "最高优先级", "专属客服", "高级功能"],
                                isCurrentTier: storeManager.getCurrentTier() == "premium",
                                isPurchased: storeManager.purchasedProductIDs.contains(premiumProduct.id),
                                accentBlue: accentBlue,
                                onPurchase: { Task { await purchaseProduct(premiumProduct) } }
                            )
                        } else {
                            SubscriptionTierCard(
                                title: "高级版",
                                price: "¥39.9/月",
                                features: ["100,000次AI分析/月", "最高优先级", "专属客服", "高级功能"],
                                isCurrentTier: false,
                                isPurchased: false,
                                accentBlue: accentBlue,
                                onPurchase: nil
                            )
                        }
                        
                        // Restore Purchases Button
                        Button(action: { Task { await restorePurchases() } }) {
                            Text("恢复购买")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(accentBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(lightGray)
                                .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Usage Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用说明")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 配置API Key后即可使用AI分析功能")
                            Text("• 免费版每天限制10次AI分析")
                            Text("• 订阅版本可享受更多使用次数")
                            Text("• 支持网页内容翻译和AI生成检测")
                            Text("• 所有数据安全存储在本地")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    if let error = storeManager.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(16)
            }
            .background(lightGray)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(accentBlue)
                }
            }
        }
        .onAppear {
            // Load saved API key
            if let savedKey = KeychainService.load(key: "com.lonesword.qwen.apikey") {
                apiKeyInput = savedKey
            }
        }
    }
    
    private func testAPIKey() {
        isTestingKey = true
        testResult = nil
        
        Task {
            let isValid = await vm.testAPIKey(apiKeyInput)
            isTestingKey = false
            testResult = isValid ? "✓ API Key有效" : "✗ API Key无效"
        }
    }
    
    private func saveAPIKey() {
        let success = vm.saveAPIKeyToKeychain(apiKeyInput)
        testResult = success ? "✓ 已保存" : "✗ 保存失败"
    }
    
    private func purchaseProduct(_ product: Product) async {
        do {
            if let transaction = try await storeManager.purchase(product) {
                // Update subscription tier in ViewModel
                let tier = product.id.contains("premium") ? "premium" : "basic"
                await vm.updateSubscriptionTier(tier)
                testResult = "✓ 购买成功"
            }
        } catch {
            testResult = "✗ 购买失败: \(error.localizedDescription)"
        }
    }
    
    private func restorePurchases() async {
        do {
            try await storeManager.restore()
            testResult = "✓ 恢复成功"
        } catch {
            testResult = "✗ 恢复失败: \(error.localizedDescription)"
        }
    }
}

// Subscription Tier Card Component
private struct SubscriptionTierCard: View {
    let title: String
    let price: String
    let features: [String]
    let isCurrentTier: Bool
    let isPurchased: Bool
    let accentBlue: Color
    let onPurchase: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(price)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentBlue)
                }
                
                Spacer()
                
                if isCurrentTier {
                    Text("当前套餐")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentBlue)
                        .cornerRadius(16)
                } else if isPurchased {
                    Text("已购买")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                } else if let action = onPurchase {
                    Button(action: action) {
                        Text("购买")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(accentBlue)
                            .cornerRadius(16)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accentBlue)
                        
                        Text(feature)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentTier ? accentBlue : Color.gray.opacity(0.2), lineWidth: isCurrentTier ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    SettingsView(vm: AIAssistantViewModel())
}
