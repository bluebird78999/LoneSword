import SwiftUI

struct BrowserToolbarView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @ObservedObject var aiViewModel: AIAssistantViewModel
    @State private var urlInput: String = ""
    @State private var isEditing: Bool = false
    @State private var lastTapTime: Date = .distantPast
    @FocusState private var isUrlFieldFocused: Bool
    @State private var showSettingsSheet: Bool = false
    
    let backgroundColor = Color(red: 0.98, green: 0.98, blue: 0.98)
    let accentBlue = Color(red: 0, green: 0.478, blue: 1)
    let orange = Color(red: 1.0, green: 0.58, blue: 0)
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部 2px 加载进度条（始终占位，避免布局抖动）
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(height: 2)
                
                accentBlue
                    .frame(width: max(0, UIScreen.main.bounds.width * viewModel.loadingProgress), height: 2)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.loadingProgress)
            }
            
            HStack(spacing: 12) {
                // 后退/前进按钮
                HStack(spacing: 12) {
                    Button(action: { viewModel.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(viewModel.canGoBack ? accentBlue : .gray)
                    }
                    .disabled(!viewModel.canGoBack)
                    .frame(width: 44, height: 44)
                    
                    Button(action: { viewModel.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(viewModel.canGoForward ? accentBlue : .gray)
                    }
                    .disabled(!viewModel.canGoForward)
                    .frame(width: 44, height: 44)
                }
                
                // URL 地址栏
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    TextField("https://ai.quark.cn/", text: $urlInput)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .focused($isUrlFieldFocused)
                        .onSubmit {
                            // 回车键提交时使用当前输入值
                            let currentInput = urlInput
                            isUrlFieldFocused = false
                            loadURL(currentInput)
                        }
                        .onChange(of: isUrlFieldFocused) { _, isFocused in
                            isEditing = isFocused
                            if isFocused {
                                // 开始编辑时，显示当前 URL
                                urlInput = viewModel.currentURL
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                // Slash 按钮
                Button(action: {
                    // 保存当前输入值，避免焦点变化导致的问题
                    let currentInput = urlInput
                    isUrlFieldFocused = false
                    // 使用保存的输入值执行加载
                    handleSlashTap(withInput: currentInput)
                }) {
                    Text("Slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(accentBlue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if !aiViewModel.aiInsightEnabled {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(accentBlue)
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding(12)
            .background(backgroundColor)
            .onAppear {
                // 启动时将地址栏显示为当前 URL
                self.urlInput = viewModel.currentURL
            }
            .onChange(of: viewModel.currentURL) { oldValue, newValue in
                // 非编辑状态下同步地址栏文本
                if !isEditing {
                    self.urlInput = newValue
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(vm: aiViewModel)
            }
        }
    }
    
    private func handleSlashTap(withInput input: String) {
        print("DEBUG: handleSlashTap called, input=\(input)")
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.3 {
            // 双击：加载首页
            print("DEBUG: Double tap detected")
            let homeURL = "https://ai.quark.cn/"
            loadURL(homeURL)
        } else {
            // 单击
            print("DEBUG: Single tap detected")
            loadURL(input)
        }
        lastTapTime = now
    }
    
    private func loadURL(_ input: String) {
        let target = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalURL = target.isEmpty ? viewModel.currentURL : target
        print("DEBUG: Loading URL: \(finalURL)")
        
        // 只有在实际需要加载新 URL 时才停止当前加载
        if finalURL != viewModel.currentURL {
            viewModel.stopLoading()
        }
        
        viewModel.loadURL(finalURL)
    }
    
}

#Preview {
    BrowserToolbarView(viewModel: BrowserViewModel(), aiViewModel: AIAssistantViewModel())
}