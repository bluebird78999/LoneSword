import Foundation
import Combine
import WebKit

@MainActor
class BrowserViewModel: NSObject, ObservableObject {
    @Published var currentURL: String = "https://ai.quark.cn/"
    @Published var loadingProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var pageTitle: String = ""
    
    // 单一回调（兼容已有使用）
    var onPageFinished: ((String, String) -> Void)?
    // 多播回调集合
    private var pageFinishedHandlers: [((String, String) -> Void)] = []
    
    var webView: WKWebView?
    private var progressObserver: NSKeyValueObservation?
    
    override init() {
        super.init()
        setupWebView()
        // 应用启动即加载初始 URL
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
                self?.canGoBack = webView.canGoBack
                self?.canGoForward = webView.canGoForward
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
        guard let webView = webView else { return }
        
        let processedURL = processURL(url)
        
        // 检测URL是否真正变化
        if processedURL != self.currentURL {
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
            webView.load(request)
            isLoading = true
            loadingProgress = 0
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
        if canGoBack {
            webView?.goBack()
        }
    }
    
    func goForward() {
        if canGoForward {
            webView?.goForward()
        }
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
        print("DEBUG: didFinish url=\(webView.url?.absoluteString ?? "nil")")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingProgress = 1.0
            self.pageTitle = webView.title ?? ""
            self.currentURL = webView.url?.absoluteString ?? self.currentURL
            if !self.currentURL.isEmpty {
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
