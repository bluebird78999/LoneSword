import Foundation
import Combine
import WebKit
import SwiftData
import os

@MainActor
class BrowserViewModel: NSObject, ObservableObject {
    @Published var currentURL: String = "https://www.chinadaily.com.cn"
    @Published var loadingProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var pageTitle: String = ""
    
    // Custom navigation history stack (persistent)
    @Published var navigationHistory: [BrowserHistory] = []
    private var currentHistoryIndex: Int = -1
    private var nextVisitOrder: Int = 0
    private var isNavigatingInHistory: Bool = false
    
    // Page finished callbacks
    var onPageFinished: ((String, String) -> Void)?
    private var pageFinishedHandlers: [((String, String) -> Void)] = []
    
    var webView: WKWebView?
    private var progressObserver: NSKeyValueObservation?
    
    private var modelContext: ModelContext?
    
    private static let logger = Logger(subsystem: "com.lonesword.browser", category: "Browser")
    
    override init() {
        super.init()
        Self.logger.debug("BrowserViewModel initialized")
        setupWebView()
        Self.logger.debug("Loading initial URL: \(self.currentURL)")
        loadURL(currentURL)
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        if #available(iOS 15.0, *) {
            config.applicationNameForUserAgent = "LoneSwordBrowser"
        }
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.customUserAgent = "LoneSword Browser"
        webView?.navigationDelegate = self
        webView?.uiDelegate = self
        webView?.allowsBackForwardNavigationGestures = true
        
        setupProgressObserver()
        
        Self.logger.debug("WebView created successfully")
    }

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
            Self.logger.error("loadURL called but webView is nil")
            return
        }
        
        let processedURL = processURL(url)
        Self.logger.debug("loadURL: \(url) -> \(processedURL)")
        
        let willPostURLChange = processedURL != self.currentURL
        
        if willPostURLChange {
            Self.logger.debug("Broadcasting URL change notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("WebViewURLDidChange"),
                object: nil,
                userInfo: ["url": processedURL]
            )
        }
        
        currentURL = processedURL
        
        webView.stopLoading()
        
        if let urlObj = URL(string: processedURL) {
            let request = URLRequest(url: urlObj, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60)
            Self.logger.debug("Loading: \(urlObj.absoluteString)")
            webView.load(request)
            isLoading = true
            loadingProgress = 0
        } else {
            Self.logger.error("Failed to create URL object from: \(processedURL)")
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
        
        if let url = URL(string: record.url) {
            webView?.load(URLRequest(url: url))
        }
        
        updateNavigationButtonStates()
        
        Self.logger.debug("goBack to index=\(self.currentHistoryIndex), url=\(record.url)")
    }
    
    func goForward() {
        guard canGoForward, currentHistoryIndex < navigationHistory.count - 1 else { return }
        
        isNavigatingInHistory = true
        currentHistoryIndex += 1
        
        let record = navigationHistory[currentHistoryIndex]
        currentURL = record.url
        pageTitle = record.title
        
        if let url = URL(string: record.url) {
            webView?.load(URLRequest(url: url))
        }
        
        updateNavigationButtonStates()
        
        Self.logger.debug("goForward to index=\(self.currentHistoryIndex), url=\(record.url)")
    }
    
    // MARK: - History Management
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadHistoryFromStorage() {
        guard let context = modelContext else {
            Self.logger.debug("ModelContext not set, cannot load history")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<BrowserHistory>(
                sortBy: [SortDescriptor(\.visitOrder, order: .reverse)]
            )
            let allHistory = try context.fetch(descriptor)
            let recentHistory = Array(allHistory.prefix(100))
            navigationHistory = recentHistory.reversed()
            currentHistoryIndex = navigationHistory.isEmpty ? -1 : navigationHistory.count - 1
            
            if let lastOrder = allHistory.first?.visitOrder {
                nextVisitOrder = lastOrder + 1
            } else {
                nextVisitOrder = 0
            }
            
            updateNavigationButtonStates()
            
            Self.logger.debug("Loaded \(self.navigationHistory.count) history records, currentIndex=\(self.currentHistoryIndex)")
        } catch {
            Self.logger.error("Failed to load history: \(error.localizedDescription)")
        }
    }
    
    private func addToHistory(url: String, title: String) {
        guard let context = modelContext else { return }
        
        if currentHistoryIndex < navigationHistory.count - 1 {
            let recordsToRemove = navigationHistory[(currentHistoryIndex + 1)...]
            for record in recordsToRemove {
                context.delete(record)
            }
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        let newRecord = BrowserHistory(
            url: url,
            title: title,
            timestamp: Date(),
            visitOrder: nextVisitOrder
        )
        nextVisitOrder += 1
        
        navigationHistory.append(newRecord)
        currentHistoryIndex = navigationHistory.count - 1
        
        context.insert(newRecord)
        trimHistoryIfNeeded()
        updateNavigationButtonStates()
        
        Self.logger.debug("Added history: \(url), currentIndex=\(self.currentHistoryIndex)")
    }
    
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
            Self.logger.debug("Trimmed history to 100 records")
        }
    }
    
    private func updateNavigationButtonStates() {
        canGoBack = currentHistoryIndex > 0
        canGoForward = currentHistoryIndex < navigationHistory.count - 1
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
        Self.logger.debug("didStartProvisionalNavigation: \(webView.url?.absoluteString ?? "nil")")
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingProgress = 0
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Self.logger.debug("didCommit: \(webView.url?.absoluteString ?? "nil")")
        DispatchQueue.main.async {
            let newURL = webView.url?.absoluteString ?? self.currentURL
            if newURL != self.currentURL {
                self.currentURL = newURL
                Self.logger.debug("didCommit broadcasting URL change")
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
        Self.logger.debug("didFinish: \(webView.url?.absoluteString ?? "nil")")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingProgress = 1.0
            self.pageTitle = webView.title ?? ""
            self.currentURL = webView.url?.absoluteString ?? self.currentURL
            
            if !self.currentURL.isEmpty {
                if !self.isNavigatingInHistory {
                    self.addToHistory(url: self.currentURL, title: self.pageTitle)
                } else {
                    self.isNavigatingInHistory = false
                }
                
                self.onPageFinished?(self.currentURL, self.pageTitle)
                for handler in self.pageFinishedHandlers { handler(self.currentURL, self.pageTitle) }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.logger.error("didFail: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadingProgress = 0
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let tappedURL = navigationAction.request.url?.absoluteString ?? "nil"
        Self.logger.debug("decidePolicyFor: type=\(navigationAction.navigationType.rawValue) url=\(tappedURL)")
        
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url?.absoluteString {
            if url != self.currentURL {
                Self.logger.debug("decidePolicyFor broadcasting URL change")
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
        decisionHandler(.allow)
    }
}

extension BrowserViewModel: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else { return nil }
        Self.logger.debug("createWebViewWith: opening \(url.absoluteString) in current webView")
        webView.load(URLRequest(url: url))
        return nil
    }
}
