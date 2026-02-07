import Foundation
import Combine
import WebKit
import SwiftData

@MainActor
class BrowserViewModel: NSObject, ObservableObject {
    @Published var currentURL: String = "https://www.chinadaily.com.cn"
    @Published var loadingProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var pageTitle: String = ""
    
    // 自定义导航历史栈（持久化）
    @Published var navigationHistory: [BrowserHistory] = []
    private var currentHistoryIndex: Int = -1
    private var nextVisitOrder: Int = 0
    private var isNavigatingInHistory: Bool = false // 标记是否正在历史导航中
    
    // 单一回调（兼容已有使用）
    var onPageFinished: ((String, String) -> Void)?
    // 多播回调集合
    private var pageFinishedHandlers: [((String, String) -> Void)] = []
    
    var webView: WKWebView?
    private var progressObserver: NSKeyValueObservation?
    
    // SwiftData ModelContext reference
    private var modelContext: ModelContext?
    
    
    override init() {
        super.init()
        print("DEBUG: BrowserViewModel init() called")
        setupWebView()
        // 应用启动即加载初始 URL
        print("DEBUG: BrowserViewModel init() calling loadURL with: \(currentURL)")
        loadURL(currentURL)
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        if #available(iOS 15.0, *) {
            config.applicationNameForUserAgent = "LoneSwordBrowser"
        }
        
        webView = WKWebView(frame: .zero, configuration: config)
        // Ensure a stable custom UA for all requests
        webView?.customUserAgent = "LoneSword Browser"
        webView?.navigationDelegate = self
        webView?.uiDelegate = self
        webView?.allowsBackForwardNavigationGestures = true
        
        setupProgressObserver()
        
        print("DEBUG: setupWebView() completed, webView=\(webView != nil ? "created" : "nil")")
    }

    /// Ensure a configured WKWebView exists and return it (used by UI wrapper)
    func ensureWebView() -> WKWebView {
        if let existing = webView { return existing }
        setupWebView()
        return webView!
    }
    
    private func setupProgressObserver() {
        guard let webView = webView else { return }
        
        progressObserver = webView.observe(\.estimatedProgress) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.loadingProgress = webView.estimatedProgress
            }
        }
    }
    
    func addOnPageFinishedHandler(_ handler: @escaping (String, String) -> Void) {
        pageFinishedHandlers.append(handler)
    }
    
    func extractWebText(completion: @escaping (String) -> Void) {
        guard let webView = webView else { completion(""); return }
        webView.evaluateJavaScript("document.documentElement.innerText") { result, error in
            if let text = result as? String, error == nil {
                completion(text)
            } else {
                completion("")
            }
        }
    }
    
    func loadURL(_ url: String) {
        guard let webView = webView else {
            print("ERROR: loadURL called but webView is nil!")
            return
        }
        
        let processedURL = processURL(url)
        print("DEBUG: loadURL called with url=\(url), processedURL=\(processedURL)")
        
        let willPostURLChange = processedURL != self.currentURL
        
        // 检测URL是否真正变化
        if willPostURLChange {
            // 触发URL变化通知（在更新currentURL之前）
            print("DEBUG: loadURL sending URL change notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("WebViewURLDidChange"),
                object: nil,
                userInfo: ["url": processedURL]
            )
        }
        
        currentURL = processedURL
        
        // Stop any ongoing load before starting a new one to avoid conflicts
        webView.stopLoading()
        
        if let urlObj = URL(string: processedURL) {
            let request = URLRequest(url: urlObj, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60)
            print("DEBUG: loadURL calling webView.load() with URL: \(urlObj)")
            webView.load(request)
            isLoading = true
            loadingProgress = 0
        } else {
            print("ERROR: Failed to create URL object from: \(processedURL)")
        }
    }
    
    func reload() {
        if let url = webView?.url?.absoluteString, !url.isEmpty {
            loadURL(url)
        } else {
            loadURL(currentURL)
        }
    }
    
    func stopLoading() {
        webView?.stopLoading()
        isLoading = false
    }
    
    func goBack() {
        guard canGoBack, currentHistoryIndex > 0 else { return }
        
        isNavigatingInHistory = true
        currentHistoryIndex -= 1
        
        let record = navigationHistory[currentHistoryIndex]
        currentURL = record.url
        pageTitle = record.title
        
        // 加载历史URL
        if let url = URL(string: record.url) {
            webView?.load(URLRequest(url: url))
        }
        
        updateNavigationButtonStates()
        
        print("DEBUG: goBack to index=\(currentHistoryIndex), url=\(record.url)")
    }
    
    func goForward() {
        guard canGoForward, currentHistoryIndex < navigationHistory.count - 1 else { return }
        
        isNavigatingInHistory = true
        currentHistoryIndex += 1
        
        let record = navigationHistory[currentHistoryIndex]
        currentURL = record.url
        pageTitle = record.title
        
        // 加载历史URL
        if let url = URL(string: record.url) {
            webView?.load(URLRequest(url: url))
        }
        
        updateNavigationButtonStates()
        
        print("DEBUG: goForward to index=\(currentHistoryIndex), url=\(record.url)")
    }
    
    // MARK: - 历史记录管理
    
    /// 设置 ModelContext 引用
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// 从 SwiftData 加载最近100条历史记录
    func loadHistoryFromStorage() {
        guard let context = modelContext else {
            print("DEBUG: ModelContext not set, cannot load history")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<BrowserHistory>(
                sortBy: [SortDescriptor(\.visitOrder, order: .reverse)]
            )
            let allHistory = try context.fetch(descriptor)
            
            // 只取最近100条
            let recentHistory = Array(allHistory.prefix(100))
            
            // 反转顺序，使最旧的在前，最新的在后
            navigationHistory = recentHistory.reversed()
            
            // 设置当前索引为最后一条（最新的）
            currentHistoryIndex = navigationHistory.isEmpty ? -1 : navigationHistory.count - 1
            
            // 设置下一个 visitOrder
            if let lastOrder = allHistory.first?.visitOrder {
                nextVisitOrder = lastOrder + 1
            } else {
                nextVisitOrder = 0
            }
            
            // 更新导航按钮状态
            updateNavigationButtonStates()
            
            print("DEBUG: Loaded \(navigationHistory.count) history records, currentIndex=\(currentHistoryIndex)")
            
            // 如果历史为空，确保初始URL被加载
            if navigationHistory.isEmpty && !currentURL.isEmpty {
                print("DEBUG: History is empty, ensuring initial URL is loaded: \(currentURL)")
                // 不需要再次调用 loadURL，因为 init() 中已经调用过了
                // 只需要确保 WebView 已经在加载
            }
        } catch {
            print("ERROR: Failed to load history: \(error)")
        }
    }
    
    /// 添加新的历史记录
    private func addToHistory(url: String, title: String) {
        guard let context = modelContext else { return }
        
        // 如果当前不在最新位置，删除当前位置之后的所有记录
        if currentHistoryIndex < navigationHistory.count - 1 {
            let recordsToRemove = navigationHistory[(currentHistoryIndex + 1)...]
            for record in recordsToRemove {
                context.delete(record)
            }
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        // 创建新记录
        let newRecord = BrowserHistory(
            url: url,
            title: title,
            timestamp: Date(),
            visitOrder: nextVisitOrder
        )
        nextVisitOrder += 1
        
        // 添加到历史栈
        navigationHistory.append(newRecord)
        currentHistoryIndex = navigationHistory.count - 1
        
        // 保存到 SwiftData
        context.insert(newRecord)
        
        // 限制历史记录数量为100条
        trimHistoryIfNeeded()
        
        // 更新导航按钮状态
        updateNavigationButtonStates()
        
        print("DEBUG: Added history record: \(url), currentIndex=\(currentHistoryIndex)")
    }
    
    /// 限制历史记录最多100条
    private func trimHistoryIfNeeded() {
        guard let context = modelContext else { return }
        
        if navigationHistory.count > 100 {
            let removeCount = navigationHistory.count - 100
            let recordsToRemove = navigationHistory.prefix(removeCount)
            
            for record in recordsToRemove {
                context.delete(record)
            }
            
            navigationHistory.removeFirst(removeCount)
            currentHistoryIndex -= removeCount
            print("DEBUG: Trimmed history to 100 records")
        }
    }
    
    /// 更新前进后退按钮状态
    private func updateNavigationButtonStates() {
        canGoBack = currentHistoryIndex > 0
        canGoForward = currentHistoryIndex < navigationHistory.count - 1
        print("DEBUG: Navigation state - canGoBack=\(canGoBack), canGoForward=\(canGoForward), index=\(currentHistoryIndex)")
    }
    
    private func processURL(_ urlString: String) -> String {
        var processed = urlString.trimmingCharacters(in: .whitespaces)
        
        if !processed.hasPrefix("http://") && !processed.hasPrefix("https://") {
            if processed.hasPrefix("www.") {
                processed = "https://" + processed
            } else if !processed.contains(".") {
                processed = "https://www." + processed
            } else {
                processed = "https://" + processed
            }
        }
        
        return processed
    }
    
    deinit {
        progressObserver?.invalidate()
    }
}

extension BrowserViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("DEBUG: didStartProvisionalNavigation url=\(webView.url?.absoluteString ?? "nil")")
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingProgress = 0
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("DEBUG: didCommit url=\(webView.url?.absoluteString ?? "nil")")
        DispatchQueue.main.async {
            let newURL = webView.url?.absoluteString ?? self.currentURL
            // 检测URL是否真正变化（包括锚点链接）
            if newURL != self.currentURL {
                self.currentURL = newURL
                // 触发URL变化通知（作为后备，处理前进/后退/重定向等场景）
                print("DEBUG: didCommit sending URL change notification")
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebViewURLDidChange"),
                    object: nil,
                    userInfo: ["url": newURL]
                )
            }
            self.pageTitle = webView.title ?? ""
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("DEBUG: didFinish url=\(webView.url?.absoluteString ?? "nil"), isNavigatingInHistory=\(isNavigatingInHistory)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingProgress = 1.0
            self.pageTitle = webView.title ?? ""
            self.currentURL = webView.url?.absoluteString ?? self.currentURL
            
            if !self.currentURL.isEmpty {
                // 只有在非历史导航时才添加到历史记录
                if !self.isNavigatingInHistory {
                    self.addToHistory(url: self.currentURL, title: self.pageTitle)
                } else {
                    // 重置历史导航标志
                    self.isNavigatingInHistory = false
                }
                
                // 触发回调（用于其他功能，如AI分析）
                self.onPageFinished?(self.currentURL, self.pageTitle)
                for handler in self.pageFinishedHandlers { handler(self.currentURL, self.pageTitle) }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("DEBUG: didFail error=\(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingProgress = 0
        }
    }
    
    // 移除内链拦截逻辑，让网页内部链接正常跳转
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let tappedURL = navigationAction.request.url?.absoluteString ?? "nil"
        print("DEBUG: decidePolicyFor type=\(navigationAction.navigationType.rawValue) url=\(tappedURL) targetFrameIsNil=\(navigationAction.targetFrame == nil)")
        // 对用户点击的链接进行地址栏与加载状态的即时更新，但不拦截加载
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url?.absoluteString {
            // 检测URL是否真正变化
            if url != self.currentURL {
                // 触发URL变化通知（在更新currentURL之前）
                print("DEBUG: decidePolicyFor sending URL change notification")
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebViewURLDidChange"),
                    object: nil,
                    userInfo: ["url": url]
                )
            }
            self.currentURL = url
            self.isLoading = true
            self.loadingProgress = 0
        }
        // 允许所有导航，包括内部链接
        decisionHandler(.allow)
    }
}

extension BrowserViewModel: WKUIDelegate {
    // 处理 target=_blank 等新窗口打开场景，改为在当前 webView 打开
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else { return nil }
        print("DEBUG: createWebViewWith opening in current webView url=\(url.absoluteString)")
        webView.load(URLRequest(url: url))
        return nil
    }
}

