//
//  ContentView.swift
//  LoneSword
//
//  Created by LiuHongfeng on 2025/6/1.
//

import SwiftUI
import WebKit
import UIKit
import Foundation

struct ContentView: View {
    @StateObject private var browserViewModel = BrowserViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部进度条
            ProgressBar(progress: browserViewModel.loadingProgress)
            
            // 地址栏和控制区域
            BrowserToolbar(viewModel: browserViewModel)
            
            // WebView
            WebViewContainer(viewModel: browserViewModel)
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            // 应用启动时加载默认页面
            browserViewModel.loadURL("https://www.google.com/")
        }
    }
}

// 进度条组件
struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 2)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progress, height: 2)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 2)
        .opacity(progress > 0 && progress < 1 ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: progress > 0 && progress < 1)
    }
}

// 浏览器工具栏
struct BrowserToolbar: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var urlText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // 双击检测相关状态
    @State private var lastTapTime: Date = Date()
    @State private var tapCount: Int = 0
    private let doubleTapTimeInterval: TimeInterval = 0.5 // 双击时间间隔
    
    var body: some View {
        HStack(spacing: 8) {
            // 后退按钮
            Button(action: {
                viewModel.goBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(viewModel.canGoBack ? .blue : .gray)
                    .frame(width: 36, height: 36)
            }
            .disabled(!viewModel.canGoBack)
            
            // 前进按钮
            Button(action: {
                viewModel.goForward()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(viewModel.canGoForward ? .blue : .gray)
                    .frame(width: 36, height: 36)
            }
            .disabled(!viewModel.canGoForward)
            
            // 地址栏
            TextField("输入网址或搜索", text: $urlText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isTextFieldFocused)
                .onSubmit {
                    handleSlashAction()
                }
                .onChange(of: viewModel.currentURL) { _, newURL in
                    // 只有在地址栏没有焦点时才更新文本，避免用户输入时被覆盖
                    if let newURL = newURL, !isTextFieldFocused {
                        let newURLString = newURL.absoluteString
                        if urlText != newURLString {
                            urlText = newURLString
                            print("🔄 地址栏已更新: \(newURLString)")
                        }
                    }
                }
                .onReceive(viewModel.$currentURL) { newURL in
                    // 使用onReceive作为备用更新机制
                    if let newURL = newURL, !isTextFieldFocused {
                        let newURLString = newURL.absoluteString
                        if urlText != newURLString {
                            urlText = newURLString
                        }
                    }
                }
            
            // Slash按钮 - 支持双击
            Button(action: {
                handleSlashButtonTap()
            }) {
                Text("Slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
            }
            
            // 增加额外间距
            Spacer()
                .frame(width: 8)
            
            // UserAgent切换按钮
            Button(action: {
                viewModel.toggleUserAgent()
            }) {
                Text(viewModel.currentUserAgentType.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 24)
                    .background(viewModel.currentUserAgentType.color)
                    .cornerRadius(4)
            }
            
            // 三个复选框
            CheckboxView(isChecked: $viewModel.option1, label: "翻译")
            CheckboxView(isChecked: $viewModel.option2, label: "AI总结")
            CheckboxView(isChecked: $viewModel.option3, label: "AI判别")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .onAppear {
            urlText = "https://www.google.com/"
            
            // 设置下拉刷新回调
            viewModel.onPullToRefresh = {
                handleSlashAction()
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 处理Slash按钮点击 - 支持单击和双击
    private func handleSlashButtonTap() {
        let currentTime = Date()
        let timeSinceLastTap = currentTime.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < doubleTapTimeInterval {
            // 双击检测
            tapCount += 1
            if tapCount >= 2 {
                handleDoubleClick()
                tapCount = 0
                return
            }
        } else {
            // 重置计数
            tapCount = 1
        }
        
        lastTapTime = currentTime
        
        // 延迟执行单击动作，给双击检测留时间
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapTimeInterval) {
            if self.tapCount == 1 {
                // 确认是单击
                self.handleSingleClick()
                self.tapCount = 0
            }
        }
    }
    
    /// 处理单击动作
    private func handleSingleClick() {
        print("👆 Slash按钮单击")
        handleSlashAction()
    }
    
    /// 处理双击动作 - 加载Google首页
    private func handleDoubleClick() {
        print("👆👆 Slash按钮双击 - 加载Google首页")
        
        // 取消地址栏焦点
        isTextFieldFocused = false
        
        // 更新地址栏文本为Google首页
        urlText = "https://google.com"
        
        // 加载Google首页
        viewModel.loadURL("https://google.com")
        
        // 执行额外动作
        handleAdditionalActions()
    }
    
    /// 处理Slash按钮动作 - 统一的URL加载逻辑
    private func handleSlashAction() {
        // 取消地址栏焦点
        isTextFieldFocused = false
        
        print("🚀 开始加载URL: \(urlText)")
        
        // 执行URL加载逻辑
        viewModel.loadURL(urlText)
        
        // 这里可以添加更多的处理逻辑，比如：
        // - 记录用户行为
        // - 处理特殊功能选项
        // - 执行其他扩展功能
        handleAdditionalActions()
    }
    
    /// 处理额外的动作逻辑
    private func handleAdditionalActions() {
        // 根据复选框状态执行相应的功能
        if viewModel.option1 {
            // 翻译功能逻辑
            print("🌐 翻译功能已启用")
        }
        
        if viewModel.option2 {
            // AI总结功能逻辑
            print("🤖 AI总结功能已启用")
        }
        
        if viewModel.option3 {
            // AI判别功能逻辑
            print("🔍 AI判别功能已启用")
        }
    }
}

// 复选框组件
struct CheckboxView: View {
    @Binding var isChecked: Bool
    let label: String
    
    var body: some View {
        Button(action: {
            isChecked.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .blue : .gray)
                    .font(.system(size: 14))
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// WebView容器
struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    func makeUIView(context: Context) -> UIView {
        // 创建容器视图
        let containerView = UIView()
        
        // 创建WebView配置
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 创建WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建下拉刷新控件
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(context.coordinator.handleRefresh(_:)), for: .valueChanged)
        
        // 获取WebView的ScrollView并添加刷新控件
        webView.scrollView.refreshControl = refreshControl
        webView.scrollView.bounces = true
        
        // 将WebView添加到容器中
        containerView.addSubview(webView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 设置webView引用并初始化UserAgent
        viewModel.setWebView(webView)
        
        // 保存refreshControl引用到coordinator
        context.coordinator.refreshControl = refreshControl
        
        // 然后立即设置观察者
        context.coordinator.setupObservers(for: webView)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新UI视图时的逻辑
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        var refreshControl: UIRefreshControl?
        private var progressObserver: NSKeyValueObservation?
        private var canGoBackObserver: NSKeyValueObservation?
        private var canGoForwardObserver: NSKeyValueObservation?
        private var urlObserver: NSKeyValueObservation?
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            removeObservers()
        }
        
        // 处理下拉刷新
        @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
            print("🔄 下拉刷新触发")
            
            // 调用ViewModel的刷新方法
            parent.viewModel.handlePullToRefresh()
            
            // 延迟结束刷新动画，给用户视觉反馈
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshControl.endRefreshing()
            }
        }
        
        func setupObservers(for webView: WKWebView) {
            // 先清除之前的观察者
            removeObservers()
            
            progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.viewModel.loadingProgress = webView.estimatedProgress
                }
            }
            
            canGoBackObserver = webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.viewModel.canGoBack = webView.canGoBack
                }
            }
            
            canGoForwardObserver = webView.observe(\.canGoForward, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.viewModel.canGoForward = webView.canGoForward
                }
            }
            
            urlObserver = webView.observe(\.url, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.viewModel.currentURL = webView.url
                }
            }
        }
        
        private func removeObservers() {
            progressObserver?.invalidate()
            canGoBackObserver?.invalidate()
            canGoForwardObserver?.invalidate()
            urlObserver?.invalidate()
            
            progressObserver = nil
            canGoBackObserver = nil
            canGoForwardObserver = nil
            urlObserver = nil
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = true
                self.parent.viewModel.loadingProgress = 0.1
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.loadingProgress = 1.0
                
                // 延迟隐藏进度条
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.parent.viewModel.loadingProgress = 0.0
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.loadingProgress = 0.0
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.loadingProgress = 0.0
            }
        }
        
        // 处理导航决策 - 链接点击事件
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 如果是用户点击链接触发的导航
            if navigationAction.navigationType == .linkActivated {
                // 获取点击的链接URL
                if let clickedURL = navigationAction.request.url {
                    // 取消当前导航，我们将使用loadURL方法重新加载
                    decisionHandler(.cancel)
                    
                    DispatchQueue.main.async {
                        // 直接调用loadURL方法（与Slash按钮相同的逻辑）
                        self.parent.viewModel.loadURL(clickedURL.absoluteString)
                    }
                    return
                }
            }
            
            // 允许其他类型的导航继续
            decisionHandler(.allow)
        }
    }
}

// UserAgent类型枚举
enum UserAgentType: Int, CaseIterable {
    case safari = 0
    case loneSword = 1
    case chromeIOS = 2
    case chromePC = 3
    
    var displayName: String {
        switch self {
        case .safari: return "SF"
        case .loneSword: return "LS"
        case .chromeIOS: return "CI"
        case .chromePC: return "CP"
        }
    }
    
    var fullName: String {
        switch self {
        case .safari: return "Safari"
        case .loneSword: return "LoneSword Browser"
        case .chromeIOS: return "Chrome iOS"
        case .chromePC: return "Chrome PC"
        }
    }
    
    var color: Color {
        switch self {
        case .safari: return .blue
        case .loneSword: return .orange
        case .chromeIOS: return .green
        case .chromePC: return .red
        }
    }
}

// 浏览器视图模型
class BrowserViewModel: ObservableObject {
    @Published var currentURL: URL?
    @Published var loadingProgress: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    
    // 多选项状态
    @Published var option1: Bool = false
    @Published var option2: Bool = false
    @Published var option3: Bool = false
    
    // UserAgent相关属性
    @Published var currentUserAgentType: UserAgentType = .safari
    
    weak var webView: WKWebView?
    
    // 下拉刷新回调
    var onPullToRefresh: (() -> Void)?
    
    // 设备信息
    private let deviceInfo = DeviceInfo()
    
    /// 获取当前应该使用的UserAgent
    func getCurrentUserAgent() -> String {
        switch currentUserAgentType {
        case .safari:
            return deviceInfo.safariUserAgent
        case .loneSword:
            return deviceInfo.loneSwordUserAgent
        case .chromeIOS:
            return deviceInfo.chromeIOSUserAgent
        case .chromePC:
            return deviceInfo.chromePCUserAgent
        }
    }
    
    /// 切换到下一个UserAgent类型
    func toggleUserAgent() {
        let allCases = UserAgentType.allCases
        let currentIndex = allCases.firstIndex(of: currentUserAgentType) ?? 0
        let nextIndex = (currentIndex + 1) % allCases.count
        currentUserAgentType = allCases[nextIndex]
        
        updateWebViewUserAgent()
        print("🔄 UserAgent已切换为: \(currentUserAgentType.fullName)")
    }
    
    /// 更新WebView的UserAgent
    private func updateWebViewUserAgent() {
        guard let webView = webView else { return }
        
        let userAgent = getCurrentUserAgent()
        webView.customUserAgent = userAgent
        print("📱 WebView UserAgent已更新: \(userAgent)")
    }
    
    /// 设置WebView引用并初始化UserAgent
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        updateWebViewUserAgent()
    }
    
    func loadURL(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        
        let processedURL = processURL(urlString)
        print("📝 处理后的URL: \(processedURL)")
        
        if let url = URL(string: processedURL) {
            webView?.stopLoading()
            let request = URLRequest(url: url)
            webView?.load(request)
            print("✅ URL加载请求已发送")
        } else {
            print("❌ URL格式无效: \(processedURL)")
        }
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    /// 处理下拉刷新 - 调用Slash按钮单击逻辑
    func handlePullToRefresh() {
        print("🔄 执行下拉刷新 - 调用Slash按钮单击逻辑")
        
        // 如果有当前URL，重新加载当前页面
        if let currentURL = currentURL {
            loadURL(currentURL.absoluteString)
        } else {
            // 如果没有当前URL，调用外部的刷新回调
            onPullToRefresh?()
        }
    }
    
    private func processURL(_ input: String) -> String {
        var urlString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果输入看起来像搜索查询而不是URL，使用搜索引擎
        if !urlString.contains(".") || urlString.contains(" ") {
            return "https://www.google.com/search?q=" + (urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        }
        
        // 如果没有协议，添加https://
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        // 智能添加www（仅对主域名）
        if let url = URL(string: urlString),
           let host = url.host,
           !host.hasPrefix("www.") && 
           host.components(separatedBy: ".").count == 2 &&
           !host.contains("localhost") &&
           !host.contains("127.0.0.1") {
            urlString = urlString.replacingOccurrences(of: "://\(host)", with: "://www.\(host)")
        }
        
        return urlString
    }
}

// 设备信息类
class DeviceInfo {
    // 获取设备型号
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 将机器标识符转换为友好的设备名称
        switch identifier {
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        case "iPad13,1", "iPad13,2": return "iPad Air (5th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro (11-inch) (5th generation)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro (12.9-inch) (5th generation)"
        default:
            // 如果是模拟器或未知设备，返回通用名称
            if identifier.contains("iPhone") {
                return "iPhone"
            } else if identifier.contains("iPad") {
                return "iPad"
            } else {
                return "iOS Device"
            }
        }
    }
    
    // 获取iOS版本
    var iosVersion: String {
        let version = UIDevice.current.systemVersion
        return version.replacingOccurrences(of: ".", with: "_")
    }
    
    // 获取iOS版本（点分格式）
    var iosVersionDot: String {
        return UIDevice.current.systemVersion
    }
    
    // 判断是否为iPad
    var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // 获取WebKit版本（固定值，因为无法动态获取）
    var webKitVersion: String {
        return "605.1.15"
    }
    
    // Safari UserAgent
    var safariUserAgent: String {
        if isIPad {
            return "Mozilla/5.0 (iPad; CPU OS \(iosVersion) like Mac OS X) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) Version/\(iosVersionDot) Mobile/15E148 Safari/604.1"
        } else {
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosVersion) like Mac OS X) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) Version/\(iosVersionDot) Mobile/15E148 Safari/604.1"
        }
    }
    
    // LoneSword Browser UserAgent
    var loneSwordUserAgent: String {
        if isIPad {
            return "Mozilla/5.0 (iPad; CPU OS \(iosVersion) like Mac OS X) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) LoneSword/0.1 Mobile/15E148 Safari/604.1"
        } else {
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosVersion) like Mac OS X) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) LoneSword/0.1 Mobile/15E148 Safari/604.1"
        }
    }
    
    // Chrome iOS UserAgent
    var chromeIOSUserAgent: String {
        if isIPad {
            return "Mozilla/5.0 (iPad; CPU OS \(iosVersion) like Mac OS X) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) CriOS/120.0.6099.119 Mobile/15E148 Safari/604.1"
        } else {
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosVersion) like Mac OS X) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) CriOS/120.0.6099.119 Mobile/15E148 Safari/604.1"
        }
    }
    
    // Chrome PC UserAgent (Windows)
    var chromePCUserAgent: String {
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
}

#Preview {
    ContentView()
}
