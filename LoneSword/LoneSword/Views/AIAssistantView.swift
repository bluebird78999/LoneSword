import SwiftUI
import WebKit
import SwiftData

struct AIAssistantView: View {
    @EnvironmentObject var browser: BrowserViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var vm: AIAssistantViewModel
    @StateObject private var speech = SpeechRecognitionService()
    @State private var userInput: String = ""
    @State private var showSettingsSheet: Bool = false
    
    let backgroundColor = Color.white
    let textColor = Color.black
    let secondaryColor = Color(red: 0.5, green: 0.5, blue: 0.5)
    let accentBlue = Color(red: 0, green: 0.478, blue: 1)
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏（浅灰背景，文本居中，右侧齿轮按钮）
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.96)
                HStack {
                    Spacer()
                    Text("AI洞察")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textColor)
                    Spacer()
                }
                HStack {
                    Spacer()
                    if vm.isLoading {
                        ProgressView().progressViewStyle(.circular)
                            .padding(.trailing, 8)
                    }
                    Button(action: { 
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(accentBlue)
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .frame(height: 44)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.2)), alignment: .bottom)
            
            
            // 三个横向并排的"复选柜"样式
            HStack(spacing: 8) {
                OptionChip(title: "识别AI生成", isOn: $vm.detectAIGenerated, accentBlue: accentBlue, textColor: textColor)
                // OptionChip(title: "自动翻译", isOn: $vm.autoTranslateChinese, accentBlue: accentBlue, textColor: textColor)
                OptionChip(title: "自动总结", isOn: $vm.autoSummarize, accentBlue: accentBlue, textColor: textColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            // 私人API Key状态显示
            if !vm.privateKeyStatus.isEmpty {
                HStack {
                    Image(systemName: vm.hasValidPrivateKey ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(vm.hasValidPrivateKey ? .green : .orange)
                    
                    Text(vm.privateKeyStatus)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            
            Divider()
                .padding(.horizontal, 0)
            
            // 显示区域（AI总结 + 对话记录）
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // AI Summary Section
                        if !vm.aiSummaryText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(parseMarkdown(vm.aiSummaryText))
                                    .font(.system(size: 14, weight: .regular))
                                    .lineSpacing(4)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Divider between summary and conversation
                        if !vm.aiSummaryText.isEmpty && !vm.conversationText.isEmpty {
                            Divider()
                        }
                        
                        // Conversation Section
                        if !vm.conversationText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(parseMarkdown(vm.conversationText))
                                    .font(.system(size: 14))
                                    .lineSpacing(4)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id("conversationBottom")
                        }
                    }
                    .padding(12)
                }
                .background(Color(red: 0.98, green: 0.98, blue: 0.98))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .onChange(of: vm.conversationText) { _, _ in
                    // Auto-scroll to bottom when conversation updates
                    withAnimation {
                        proxy.scrollTo("conversationBottom", anchor: .bottom)
                    }
                }
            }
            
            // 分隔线
            Divider()
                .padding(.horizontal, 0)
            
            // 输入框
            HStack(spacing: 8) {
                TextField("输入您的问题...", text: $userInput)
                    .font(.system(size: 14))
                    .foregroundColor(textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.98, green: 0.98, blue: 0.98))
                    .cornerRadius(6)
                    .onSubmit { submitQuery() }
                
                Button(action: { submitQuery() }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(accentBlue)
                }
                .frame(width: 44, height: 44)
                
                Button(action: { toggleSpeech() }) {
                    Image(systemName: speech.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 16))
                        .foregroundColor(speech.isListening ? .red : accentBlue)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(backgroundColor)
        .border(Color.gray.opacity(0.2), width: 1)
        .onChange(of: speech.recognizedText) { _, newVal in
            if !newVal.isEmpty { userInput = newVal }
        }
        .task {
            // 这些初始化现在在 ContentView 中完成，这里不需要重复设置
            // 但保留这个 task 块以防需要其他初始化逻辑
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WebViewURLDidChange"))) { notification in
            // URL变化时立即重置AI总结文本
            print("DEBUG: AIAssistantView received URL change notification")
            if let url = notification.userInfo?["url"] as? String {
                print("DEBUG: New URL: \(url)")
            }
            vm.resetForNewPage()
        }
        .onReceive(browser.$loadingProgress) { progress in
            if progress >= 1.0 {
                guard vm.aiInsightEnabled else { return }
                Task { await vm.autoAnalyzeIfEnabled() }
            }
        }
        .onChange(of: vm.aiInsightEnabled) { _, enabled in
            if !enabled, speech.isListening {
                speech.stop()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(vm: vm)
        }
    }
    
    private func submitQuery() {
        guard vm.aiInsightEnabled else { return }
        let query = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        Task { await vm.queryFromUser(query) }
        userInput = ""
    }
    
    private func toggleSpeech() {
        guard vm.aiInsightEnabled else { return }
        Task {
            if speech.isListening { speech.stop(); return }
            let ok = await speech.requestAuthorization()
            if ok { speech.start() }
        }
    }
    
    // Simple markdown parser for bold text
    private func parseMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Parse **bold** text
        let pattern = "\\*\\*(.+?)\\*\\*"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let boldText = String(text[range]).replacingOccurrences(of: "**", with: "")
                    if let attrRange = Range(match.range, in: attributedString) {
                        attributedString.replaceSubrange(attrRange, with: AttributedString(boldText))
                        if let boldRange = attributedString.range(of: boldText) {
                            attributedString[boldRange].font = .system(size: 14, weight: .bold)
                        }
                    }
                }
            }
        }
        
        return attributedString
    }
}

// 复选柜样式的 Chip 组件
private struct OptionChip: View {
    let title: String
    @Binding var isOn: Bool
    let accentBlue: Color
    let textColor: Color
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 6) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 14))
                    .lineLimit(1)
            }
            .foregroundColor(isOn ? accentBlue : textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn ? accentBlue.opacity(0.1) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? accentBlue : Color.gray.opacity(0.3), lineWidth: 1.5)
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .buttonStyle(.plain)
    }
}

#Preview {
    AIAssistantView(vm: AIAssistantViewModel())
}
