//Updated WebView
//
//  ContentView.swift
//  LoneSword
//
//  Created by LiuHongfeng on 3/11/25.
//

import SwiftUI
import SwiftData
import WebKit
import UIKit
import AVFoundation
import Photos
import OSLog
import Combine // Import Combine framework

// MARK: - Logger
let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LoneSword", category: "ContentView")

// MARK: - Notification Name for Cancellation
extension Notification.Name {
    static let cancelWebViewAndSummary = Notification.Name("cancelWebViewAndSummaryNotification")
    static let translateWebPage = Notification.Name("translateWebPageNotification")
}

// MARK: - API Error Enum
enum APIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case requestFailed(statusCode: Int)
    case invalidResponseFormat
    case apiError(message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key for Qwen (DASHSCOPE_API_KEY) is missing in environment variables."
        case .invalidURL:
            return "The API endpoint URL is invalid."
        case .networkError(let underlyingError):
            return "Network error: \(underlyingError.localizedDescription)"
        case .requestFailed(let statusCode):
            return "API request failed with status code: \(statusCode)"
        case .invalidResponseFormat:
            return "Could not decode the API response."
        case .apiError(let message):
            return "API returned an error: \(message)"
        case .timeout:
            return "The API request timed out."
        }
    }
}

// MARK: - API Request/Response Structures (OpenAI Compatible)
struct QwenRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let stream: Bool = true // Streaming is enabled
}

// Original Response struct (Not used for stream decoding, keep for reference? Or remove?)
// We might not need this if we only handle streams
struct QwenResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let index: Int
        let message: Message
        let finish_reason: String?
    }
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
}

// New struct for decoding individual stream chunks (SSE data payload)
struct QwenStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let role: String?
            let content: String?
        }
        let index: Int
        let delta: Delta
        let finish_reason: String?
    }
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]? // Choices might be optional in some chunks
}

// MARK: - Qwen API Manager
// Qwen3模型通过enable_thinking参数控制思考过程（开源版默认True，商业版默认False）
//  使用Qwen3开源版模型时，若未启用流式输出，请将下行取消注释，否则会报错
// extra_body={"enable_thinking": False},
struct QwenAPIManager {
    private let endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let modelName = "qwen3-235b-a22b" // Switched to a known model, adjust if needed
    private let requestTimeout: TimeInterval = 30 // Increased timeout for potentially longer streams
    private let apiKey = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"]

    func getAPIKey() -> String? {
        return apiKey;
    }

    // Updated summarize function to handle SSE stream
    func summarize(text: String) async throws -> String {
        logger.info("Starting summarization (stream) for text length: \(text.count)")
        guard let apiKey = getAPIKey() else {
            logger.error("API Key missing.")
            throw APIError.missingAPIKey
        }

        guard let url = URL(string: endpoint) else {
            logger.error("Invalid API endpoint URL: \(self.endpoint)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept") // Explicitly accept SSE
        let prompt = """
        请根据以下要求对提供的网页内容进行分析总结：

        1. 判断内容是否为AI生成，并简要说明判断依据（如语言模式、逻辑结构、数据来源等）；
        2. 使用总分结构总结文章的核心观点及分项论点；
        3. 输出使用 Markdown 格式，格式如下：

        # 一、  此文章**是/不是**AI生成，判断依据：[一句话总结具体分析特征]/n

        # 二、核心观点:/n  
        [用一句话概括文章主旨]
        /n
        ## 三、分项论点解析
        /n
        1. **[论点1]**  
           - 支撑依据：[具体内容]  
           - 数据/案例：[具体引用]  

        2. **[论点2]**  
           - 关键论据：[具体分析]  
           - 逻辑链条：[推导过程]  

        ...

        请严格遵循上述格式要求，确保内容客观准确，分项论点不超过5个，每个论点包含至少两个支撑细节。
        ：\n\n---\n\(text)\n---
        """
        let baseRequestBody = QwenRequest(
            model: modelName,
            messages: [QwenRequest.Message(role: "user", content: prompt)]
            // stream is true by default
        )

        do {
            // 1. Encode the base request to a dictionary
            let encoder = JSONEncoder()
            // encoder.outputFormatting = .prettyPrinted // Optional for debugging
            let baseData = try encoder.encode(baseRequestBody)
            guard var requestDict = try JSONSerialization.jsonObject(with: baseData, options: []) as? [String: Any] else {
                logger.error("Failed to convert base request to dictionary.")
                throw APIError.invalidResponseFormat // Or a more specific internal error
            }

            // 2. Add the extra_body parameter
            // Note: This assumes enable_thinking is always false for this setup.
            // If it needs to be dynamic, adjust accordingly.
            requestDict["extra_body"] = ["enable_thinking": false]
            logger.debug("Added extra_body: [\"enable_thinking\": false] to request dictionary.")

            // 3. Encode the modified dictionary back to Data
            request.httpBody = try JSONSerialization.data(withJSONObject: requestDict, options: [])
            logger.debug("Sending stream request to Qwen API with extra_body.")

        } catch let error as EncodingError {
            logger.error("Failed to encode request body (EncodingError): \(error.localizedDescription)")
            throw APIError.invalidResponseFormat
        } catch {
            logger.error("Failed to encode or modify request body: \(error.localizedDescription)")
            throw APIError.invalidResponseFormat
        }

        var accumulatedSummary = ""
        let jsonDecoder = JSONDecoder()

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response received from server.")
                throw APIError.invalidResponseFormat
            }

            logger.info("Received stream response header. Status: \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                 // Try to read initial error data if status code is bad
                 var errorData = Data()
                 for try await byte in bytes {
                     errorData.append(byte)
                     // Limit read size for errors
                     if errorData.count > 1024 { break }
                 }
                 let errorBody = String(data: errorData, encoding: .utf8) ?? "No error body"
                 logger.error("API stream request failed. Status: \(httpResponse.statusCode), Body: \(errorBody)")
                 throw APIError.requestFailed(statusCode: httpResponse.statusCode)
            }

            // Process the stream line by line
            for try await line in bytes.lines {
                logger.debug("Received stream line: \(line)")
                if line.hasPrefix("data:") {
                    let dataString = String(line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines))
                    if dataString == "[DONE]" {
                        logger.info("Stream finished [DONE].")
                        break // End of stream
                    }
                    guard let jsonData = dataString.data(using: .utf8) else {
                         logger.warning("Could not convert stream data string to Data: \(dataString)")
                         continue
                    }
                    
                    do {
                        let chunk = try jsonDecoder.decode(QwenStreamChunk.self, from: jsonData)
                        if let contentDelta = chunk.choices?.first?.delta.content {
                            accumulatedSummary += contentDelta
                            // logger.trace("Accumulated Summary: \(accumulatedSummary)") // Very verbose
                        }
                    } catch {
                        logger.error("Failed to decode stream chunk JSON: \(error.localizedDescription). JSON: \(dataString)")
                        // Continue processing other lines, maybe log the error and proceed
                        // Or depending on severity, you might want to throw here
                        // throw APIError.invalidResponseFormat
                    }
                }
            }
            
            logger.info("Stream processing complete. Final summary length: \(accumulatedSummary.count)")
            if accumulatedSummary.isEmpty {
                 logger.warning("Accumulated summary is empty after stream processing.")
                 // You might want to throw an error or return a specific message here
                 // depending on whether an empty summary is valid.
                 // throw APIError.invalidResponseFormat // Example
            }
            return accumulatedSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch let error as URLError where error.code == .timedOut {
             logger.error("API stream request timed out.")
             throw APIError.timeout
        } catch let error as APIError {
             throw error // Re-throw known API errors
        } catch {
            logger.error("An unexpected error occurred during stream processing: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
}

struct WebView: UIViewRepresentable {
    @Binding var urlString: String
    // Callback to pass extracted text back to ContentView
    var onTextExtracted: (String) -> Void
    // Callback to handle link clicks
    var onLinkClicked: ((String) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        // Set the delegate
        webView.navigationDelegate = context.coordinator
        // Store a weak reference to the webView instance in the coordinator
        context.coordinator.webViewInstance = webView
        logger.debug("makeUIView: Coordinator webViewInstance set.")
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle empty URL string case
        if urlString.isEmpty {
            // Only clear webView if it currently has content
            if webView.url != nil {
                logger.info("UpdateUIView: Clearing webView content due to empty URL")
                webView.stopLoading()
                context.coordinator.resetExtractionState()
                webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
                DispatchQueue.main.async {
                    self.onTextExtracted("Enter a URL and tap Slash.")
                }
            }
            return
        }
        
        // Process non-empty URL
        if let url = URL(string: urlString) {
            // Log current states for debugging
            logger.info("UpdateUIView called with urlString: \(urlString)")
            logger.info("Current webView.url: \(webView.url?.absoluteString ?? "nil")")
            
            // Check if we need to load a new URL
            // Consider URLs different if:
            // 1. webView has no URL loaded
            // 2. The base URLs are different (ignoring trailing slashes and schemes variations)
            let shouldLoad: Bool
            if let currentURL = webView.url {
                let normalizedCurrent = normalizeURL(currentURL.absoluteString)
                let normalizedNew = normalizeURL(urlString)
                shouldLoad = normalizedCurrent != normalizedNew
                logger.info("Normalized current: \(normalizedCurrent), Normalized new: \(normalizedNew), shouldLoad: \(shouldLoad)")
            } else {
                shouldLoad = true
                logger.info("WebView has no URL, shouldLoad: true")
            }
            
            if shouldLoad {
                logger.info("UpdateUIView: Loading new URL: \(self.urlString)")
                // Stop any current loading first
                webView.stopLoading()
                // Reset coordinator state for the new load
                context.coordinator.resetExtractionState()
                // Cancel any pending early extraction
                context.coordinator.cancelEarlyExtraction()
                
                // Start new loading session
                let sessionId = context.coordinator.startNewLoadingSession()
                
                // Load the new URL
                let request = URLRequest(url: url)
                webView.load(request)

                // --- Start: Attempt early text extraction after 3 seconds ---
                let script = "document.body.innerText || document.documentElement.innerText"
                
                // Create cancellable work item for early extraction
                let workItem = DispatchWorkItem { [weak webView, weak coordinator = context.coordinator, urlString = self.urlString, sessionId] in
                    guard let webView = webView, let coordinator = coordinator else { return }
                    
                    // Check if session is still valid
                    guard coordinator.isSessionValid(sessionId) else {
                        logger.info("Early extraction cancelled: session invalid")
                        return
                    }
                    
                    // Check if the webView is still potentially loading the requested URL
                    if ((webView.url?.absoluteString.contains(urlString)) ?? false || webView.isLoading) {
                        logger.info("Attempting EARLY text extraction (3s after load start)... URL: \(urlString)")
                        webView.evaluateJavaScript(script) { (result, error) in
                            DispatchQueue.main.async {
                                // Verify session again after async operation
                                guard coordinator.isSessionValid(sessionId) else {
                                    logger.info("Early extraction result discarded: session invalid")
                                    return
                                }
                                
                                if let error = error {
                                    logger.warning("Early JavaScript evaluation failed: \(error.localizedDescription)")
                                    return
                                }
                                if let earlyText = result as? String, !earlyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    // Process the extracted early text
                                    coordinator.processExtractedText(earlyText, fromEarlyAttempt: true, sessionId: sessionId)
                                } else {
                                    logger.info("No text found during early extraction attempt.")
                                    // Ensure state reflects no early summary if no text found early
                                    coordinator.didSummarizeEarly = false
                                }
                            }
                        }
                    } else {
                        logger.info("Skipping early text extraction: URL changed, load finished quickly, or summary already done. Current WebView URL: \(webView.url?.absoluteString ?? "nil") vs Requested: \(urlString)")
                    }
                }
                
                // Store and execute the work item
                context.coordinator.setEarlyExtractionWorkItem(workItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
                // --- End: Attempt early text extraction ---
            } else {
                logger.debug("UpdateUIView: URL unchanged, skipping load. Current: \(webView.url?.absoluteString ?? "nil")")
            }
        } else {
            logger.warning("UpdateUIView: Invalid URL string: \(urlString)")
            DispatchQueue.main.async {
                self.onTextExtracted("Invalid URL format")
            }
        }
    }
    
    // Helper function to normalize URLs for comparison
    private func normalizeURL(_ urlString: String) -> String {
        var normalized = urlString.lowercased()
        // Remove trailing slashes
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        // Remove www. prefix if present
        normalized = normalized.replacingOccurrences(of: "://www.", with: "://")
        // Remove fragment identifiers
        if let fragmentRange = normalized.range(of: "#") {
            normalized = String(normalized[..<fragmentRange.lowerBound])
        }
        return normalized
    }
    
    // Coordinator to handle potential future delegates
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        private let apiManager = QwenAPIManager() // Instance of the API manager
        // Weak reference to the managed WKWebView
        weak var webViewInstance: WKWebView?
        // Handle to the potentially running summarization task
        private var currentSummarizationTask: Task<Void, Never>?
        
        // Session management for better cancellation control
        private var currentLoadingSession: UUID?
        private var earlyExtractionWorkItem: DispatchWorkItem?
        
        // State for early extraction comparison
        var earlyExtractedText: String? = nil
        var earlyExtractedLength: Int = 0
        var didSummarizeEarly: Bool = false
        
        init(_ parent: WebView) {
            self.parent = parent
            super.init() // Needed for NSObject subclass
            // Register to observe the cancellation notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCancelNotification(_:)),
                name: .cancelWebViewAndSummary,
                object: nil
            )
            // Register to observe the translation notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTranslateNotification(_:)),
                name: .translateWebPage,
                object: nil
            )
            logger.debug("Coordinator init: Notification observers added.")
        }
        
        deinit {
            logger.debug("Coordinator deinit: Removing observers and cancelling all operations.")
            cancelAllOperations()
            NotificationCenter.default.removeObserver(self, name: .cancelWebViewAndSummary, object: nil)
            NotificationCenter.default.removeObserver(self, name: .translateWebPage, object: nil)
        }
        
        // Start a new loading session and return its ID
        func startNewLoadingSession() -> UUID {
            let newSession = UUID()
            currentLoadingSession = newSession
            logger.info("Started new loading session: \(newSession)")
            return newSession
        }
        
        // Check if a session is still valid
        func isSessionValid(_ session: UUID?) -> Bool {
            guard let session = session else { return false }
            return currentLoadingSession == session
        }
        
        // Cancel all ongoing operations
        func cancelAllOperations() {
            logger.info("Cancelling all operations")
            
            // Cancel WebView loading
            webViewInstance?.stopLoading()
            
            // Cancel early extraction
            cancelEarlyExtraction()
            
            // Cancel summarization task
            currentSummarizationTask?.cancel()
            currentSummarizationTask = nil
            
            // Reset all states
            resetExtractionState()
            
            // Invalidate current session
            currentLoadingSession = nil
        }
        
        // Cancel early extraction task
        func cancelEarlyExtraction() {
            earlyExtractionWorkItem?.cancel()
            earlyExtractionWorkItem = nil
        }
        
        // Set new early extraction work item
        func setEarlyExtractionWorkItem(_ workItem: DispatchWorkItem) {
            // Cancel any existing work item first
            cancelEarlyExtraction()
            earlyExtractionWorkItem = workItem
        }
        
        // Reset state for a new URL load or cancellation
        func resetExtractionState() {
            logger.debug("Resetting coordinator extraction state.")
            earlyExtractedText = nil
            earlyExtractedLength = 0
            didSummarizeEarly = false
        }
        
        // --- Notification Handler ---
        @objc private func handleCancelNotification(_ notification: Notification) {
            logger.info("Cancellation notification received.")
            // Get new session ID from notification if provided
            let newSession = notification.object as? UUID
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Cancel all operations
                self.cancelAllOperations()
                
                // If new session provided, set it
                if let session = newSession {
                    self.currentLoadingSession = session
                    logger.info("Set new session from notification: \(session)")
                }
                
                // Update display text
                self.parent.onTextExtracted("正在取消之前的操作...")
            }
        }
        
        @objc private func handleTranslateNotification(_ notification: Notification) {
            logger.info("Translation notification received.")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.extractAndTranslateContent()
            }
        }
        
        // 提取并翻译网页内容
        private func extractAndTranslateContent() {
            guard let webView = webViewInstance else {
                logger.error("WebView instance is nil")
                parent.onTextExtracted("翻译失败：WebView未准备好")
                return
            }
            
            // JavaScript代码：获取所有文本节点并标记它们
            let extractScript = """
            (function() {
                var textNodes = [];
                var nodeIndex = 0;
                
                function getTextNodes(node) {
                    if (node.nodeType === 3 && node.textContent.trim()) {
                        // 检测是否包含非中文字符（排除空白字符）
                        var text = node.textContent.trim();
                        if (text && !/^[\\u4e00-\\u9fff\\s\\d\\p{P}]+$/u.test(text)) {
                            node.setAttribute = function(name, value) {
                                if (name === 'data-translation-id') {
                                    var span = document.createElement('span');
                                    span.setAttribute('data-translation-id', value);
                                    node.parentNode.replaceChild(span, node);
                                    span.appendChild(node);
                                }
                            };
                            node.setAttribute('data-translation-id', nodeIndex);
                            textNodes.push({
                                id: nodeIndex,
                                text: text
                            });
                            nodeIndex++;
                        }
                    } else if (node.nodeType === 1) {
                        for (var i = 0; i < node.childNodes.length; i++) {
                            getTextNodes(node.childNodes[i]);
                        }
                    }
                }
                
                getTextNodes(document.body);
                return textNodes;
            })();
            """
            
            webView.evaluateJavaScript(extractScript) { [weak self] (result, error) in
                guard let self = self else { return }
                
                if let error = error {
                    logger.error("Failed to extract text nodes: \(error.localizedDescription)")
                    self.parent.onTextExtracted("翻译失败：无法提取页面文本")
                    return
                }
                
                guard let textNodes = result as? [[String: Any]], !textNodes.isEmpty else {
                    logger.info("No non-Chinese text found to translate")
                    self.parent.onTextExtracted("未找到需要翻译的非中文文本")
                    return
                }
                
                logger.info("Found \(textNodes.count) text nodes to translate")
                
                // 批量翻译文本
                self.translateTextNodes(textNodes)
            }
        }
        
        // 批量翻译文本节点
        private func translateTextNodes(_ textNodes: [[String: Any]]) {
            // 提取所有文本
            var textsToTranslate: [(id: Int, text: String)] = []
            for node in textNodes {
                if let id = node["id"] as? Int,
                   let text = node["text"] as? String {
                    textsToTranslate.append((id: id, text: text))
                }
            }
            
            // 构建翻译请求的prompt
            let textsOnly = textsToTranslate.map { $0.text }
            let combinedText = textsOnly.enumerated().map { "[\($0.offset)]: \($0.element)" }.joined(separator: "\n")
            
            let prompt = """
            请将以下编号的文本翻译成中文，保持编号格式不变，直接返回翻译结果：
            
            \(combinedText)
            """
            
            // 显示翻译进度
            parent.onTextExtracted("正在翻译 \(textsToTranslate.count) 段文本...")
            
            // 使用现有的API管理器进行翻译
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    let translationResult = try await self.apiManager.summarize(text: prompt)
                    
                    // 解析翻译结果
                    let translations = self.parseTranslations(translationResult, originalTexts: textsToTranslate)
                    
                    // 应用翻译到网页
                    await MainActor.run {
                        self.applyTranslations(translations)
                    }
                } catch {
                    logger.error("Translation failed: \(error.localizedDescription)")
                    await MainActor.run {
                        self.parent.onTextExtracted("翻译失败: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 解析翻译结果
        private func parseTranslations(_ result: String, originalTexts: [(id: Int, text: String)]) -> [Int: String] {
            var translations: [Int: String] = [:]
            
            let lines = result.components(separatedBy: .newlines)
            for line in lines {
                // 匹配格式 [数字]: 翻译文本
                if let match = line.firstMatch(of: /\[(\d+)\]:\s*(.+)/) {
                    if let id = Int(match.1) {
                        translations[id] = String(match.2).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            // 如果某些文本没有翻译结果，保持原文
            for (id, _) in originalTexts {
                if translations[id] == nil {
                    logger.warning("No translation found for text id \(id)")
                }
            }
            
            return translations
        }
        
        // 应用翻译到网页
        private func applyTranslations(_ translations: [Int: String]) {
            guard let webView = webViewInstance else { return }
            
            // 生成JavaScript代码来替换文本
            var jsCode = "(() => {\n"
            for (id, translation) in translations {
                let escapedTranslation = translation
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                
                jsCode += """
                var element = document.querySelector('[data-translation-id="\(id)"]');
                if (element && element.firstChild && element.firstChild.nodeType === 3) {
                    element.firstChild.textContent = '\(escapedTranslation)';
                }
                
                """
            }
            jsCode += "})();"
            
            webView.evaluateJavaScript(jsCode) { [weak self] (_, error) in
                if let error = error {
                    logger.error("Failed to apply translations: \(error.localizedDescription)")
                    self?.parent.onTextExtracted("应用翻译时出错")
                } else {
                    logger.info("Successfully applied \(translations.count) translations")
                    self?.parent.onTextExtracted("翻译完成：已翻译 \(translations.count) 段文本")
                }
            }
        }
        
        // --- WKNavigationDelegate Methods ---
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 检查是否是用户点击链接
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    logger.info("用户点击了链接: \(url.absoluteString)")
                    
                    // 取消默认的导航行为，因为我们将通过loadURL来处理
                    decisionHandler(.cancel)
                    
                    // 确保在主线程上更新UI并触发loadURL
                    DispatchQueue.main.async {
                        // 通过调用parent的闭包来触发ContentView中的loadURL
                        self.parent.onLinkClicked?(url.absoluteString)
                    }
                    return
                }
            }
            
            // 其他类型的导航（如初始加载、表单提交等）允许进行
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                if URL(string: self.parent.urlString) != nil {
                   // Don't reset state here, wait for loadURL or cancellation notice
                   self.parent.onTextExtracted("Loading \(self.parent.urlString)... ")
                } else {
                    self.parent.onTextExtracted("Invalid URL provided.")
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let currentWebViewURL = webView.url?.absoluteString
            let requestedURL = self.parent.urlString
            logger.info("Page finished loading. WebView URL: \(currentWebViewURL ?? "nil"), Requested URL: \(requestedURL)")

            // Check session validity
            guard let session = currentLoadingSession else {
                logger.info("didFinish: No active session, skipping extraction")
                return
            }
            
            guard isSessionValid(session) else {
                logger.info("didFinish: Session invalid, skipping extraction")
                return
            }

            // Use more strict URL matching
            guard let webViewURL = webView.url else {
                logger.warning("didFinish: WebView URL is nil")
                return
            }
            
            // Use normalized URL comparison
            let normalizedWebViewURL = parent.normalizeURL(webViewURL.absoluteString)
            let normalizedRequestedURL = parent.normalizeURL(requestedURL)
            
            guard normalizedWebViewURL == normalizedRequestedURL else {
                logger.warning("didFinish: Normalized URL mismatch. WebView: \(normalizedWebViewURL), Requested: \(normalizedRequestedURL)")
                return
            }

            // Check webView loading state (should be false here, but good practice)
            guard !webView.isLoading else {
                logger.info("Skipping final text extraction as webView.isLoading is true (unexpected in didFinish).")
                return
            }

            logger.info("Proceeding with final text extraction for: \(requestedURL)")
            // Evaluate JS to get final text
            let script = "document.body.innerText || document.documentElement.innerText"
            webView.evaluateJavaScript(script) { [weak self, session] (result, error) in
                guard let self = self else { return }
                DispatchQueue.main.async { // Ensure UI/state updates are on main thread
                    // Verify session again
                    guard self.isSessionValid(session) else {
                        logger.info("Final extraction cancelled: session invalid")
                        return
                    }
                    
                    if let error = error {
                        logger.error("Final JavaScript evaluation failed: \(error.localizedDescription)")
                         self.parent.onTextExtracted("提取页面文本时出错")
                        return
                    }
                    guard let finalExtractedText = result as? String, !finalExtractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        logger.warning("No text extracted or result was not a string after page load (didFinish). URL: \(requestedURL)")
                        // If early summary happened but final is empty, maybe revert?
                        // For now, just report no text found.
                        if !self.didSummarizeEarly { // Only update if no early summary is showing
                             self.parent.onTextExtracted("页面没有找到可总结的文本内容")
                        }
                        return
                    }
                    // Process the extracted final text
                    self.processExtractedText(finalExtractedText, fromEarlyAttempt: false, sessionId: session)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
             let nsError = error as NSError
             if !(nsError.domain == "WebKitErrorDomain" && nsError.code == 102) {
                 logger.error("Webview navigation failed: \(error.localizedDescription)")
                 // Avoid overwriting existing summary/message if cancellation happened
                 if !Task.isCancelled && !(nsError.code == NSURLErrorCancelled) { // Double check cancellation
                     DispatchQueue.main.async {
                         self.parent.onTextExtracted("Error loading page: \(error.localizedDescription)")
                     }
                 }
                 // Reset state on failure? Might depend on the error.
                 // resetExtractionState()
             } else {
                  logger.info("Webview navigation failed with frame load interrupted (code 102), likely due to cancellation.")
                  // State should have been reset by cancellation handler
             }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
             if (error as NSError).code == NSURLErrorCancelled {
                 logger.info("Webview provisional navigation cancelled (NSURLErrorCancelled), likely normal due to new load or explicit cancel.")
                 // State should have been reset by loadURL or cancellation handler
                 return
             }
             logger.error("Webview provisional navigation failed: \(error.localizedDescription)")
             DispatchQueue.main.async {
                 // Avoid overwriting existing summary/message if cancellation happened
                 if !Task.isCancelled { // Check cancellation state
                    self.parent.onTextExtracted("Error loading page: \(error.localizedDescription)")
                 }
             }
             // Reset state on failure?
             // resetExtractionState()
        }

        // --- Text Processing Logic ---
        func processExtractedText(_ text: String, fromEarlyAttempt: Bool, sessionId: UUID? = nil) {
            // Verify session if provided
            if let sessionId = sessionId {
                guard isSessionValid(sessionId) else {
                    logger.info("processExtractedText cancelled: session invalid")
                    return
                }
            }
            
            let currentTextLength = text.count
            let textSnippet = String(text.prefix(100)).replacingOccurrences(of: "\n", with: " ") // For logging

            if fromEarlyAttempt {
                logger.info("Processing EARLY text. Length: \(currentTextLength). Snippet: '\(textSnippet)...'")
                self.earlyExtractedText = text
                self.earlyExtractedLength = currentTextLength

                if currentTextLength > 2000 {
                    // Only start early summary if one isn't already running/completed for this load cycle
                    if !self.didSummarizeEarly {
                        logger.info("Early text length (\(currentTextLength)) > 2000. Starting early summarization.")
                        self.didSummarizeEarly = true
                        // Update UI immediately before async task
                        self.parent.onTextExtracted("检测到文本长度 > 2000 字符，正在进行预览总结...")
                        // Start the summarization task with session ID
                        submitForSummarization(text: text, sessionId: sessionId)
                    } else {
                        logger.info("Early text length (\(currentTextLength)) > 2000, but early summarization flag already set. Skipping duplicate early summary.")
                    }
                } else {
                    logger.info("Early text length (\(currentTextLength)) <= 2000. No early summarization triggered.")
                    // Ensure flag is false if criteria not met early on
                    self.didSummarizeEarly = false
                }
            } else { // Processing final text from didFinish
                logger.info("Processing FINAL text. Length: \(currentTextLength). Snippet: '\(textSnippet)...'")

                if self.didSummarizeEarly {
                    // An early summary was performed. Check length difference.
                    if currentTextLength > self.earlyExtractedLength * 2 {
                        logger.info("Final text length (\(currentTextLength)) > 2x early length (\(self.earlyExtractedLength)). Re-summarizing with final text.")
                        // Update UI immediately before async task
                        self.parent.onTextExtracted("检测到完整网页文本差异较大，重新进行AI总结...")
                        // Submit the *final* text for summarization
                        submitForSummarization(text: text, sessionId: sessionId)
                    } else {
                        logger.info("Final text length (\(currentTextLength)) not > 2x early length (\(self.earlyExtractedLength)). Keeping early summary.")
                        // Do nothing, keep the summary already displayed from the early attempt.
                    }
                } else {
                    // No early summary was performed, summarize the final text.
                    logger.info("No early summary was performed previously. Summarizing final text.")
                     // Update UI immediately before async task
                     self.parent.onTextExtracted("正在总结提取的文本...")
                    // Submit the final text for summarization
                    submitForSummarization(text: text, sessionId: sessionId)
                }
            }
        }

        // --- Submits text for API Summarization ---
        private func submitForSummarization(text: String, sessionId: UUID? = nil) {
            // Cancel any previous summarization task before starting a new one
            currentSummarizationTask?.cancel() // Cancel previous task if any
            logger.debug("submitForSummarization: Previous summary task cancelled (if existed). Starting new task.")

            // Store the handle to the new task
            self.currentSummarizationTask = Task { [weak self] in // Use weak self from the start
                guard let self = self else { return }
                
                do {
                    // Check for cancellation *before* starting the network request
                    try Task.checkCancellation()
                    
                    // Verify session if provided
                    if let sessionId = sessionId {
                        guard self.isSessionValid(sessionId) else {
                            logger.info("Summarization cancelled: session invalid")
                            return
                        }
                    }
                    
                    logger.info("Starting API summarization task for text length: \(text.count).")

                    let summary = try await self.apiManager.summarize(text: text)

                    // Check for cancellation *after* the network request completes
                    try Task.checkCancellation()
                    
                    // Verify session again after network request
                    if let sessionId = sessionId {
                        guard self.isSessionValid(sessionId) else {
                            logger.info("Summarization result discarded: session invalid")
                            return
                        }
                    }
                    
                    logger.info("Summarization successful.")

                    await MainActor.run {
                        // Final check before UI update
                        guard !Task.isCancelled else {
                            logger.info("Summarization task cancelled just before UI update.")
                            return
                        }
                        
                        // Verify session one more time
                        if let sessionId = sessionId {
                            guard self.isSessionValid(sessionId) else {
                                logger.info("Summarization UI update cancelled: session invalid")
                                return
                            }
                        }
                        
                        logger.debug("Updating display text with summary.")
                        self.parent.onTextExtracted(summary)
                    }
                } catch is CancellationError {
                     logger.info("Summarization Task cancelled.")
                } catch let error as APIError {
                    logger.error("Summarization failed: \(error.localizedDescription)")
                    await MainActor.run {
                        // Check for cancellation before showing error
                        if !Task.isCancelled {
                            // Also check session validity
                            if let sessionId = sessionId, !self.isSessionValid(sessionId) {
                                return
                            }
                            self.parent.onTextExtracted("总结错误: \(error.localizedDescription)")
                        }
                    }
                } catch {
                     logger.error("Unexpected error during summarization: \(error.localizedDescription)")
                    await MainActor.run {
                         // Check for cancellation before showing error
                        if !Task.isCancelled {
                            // Also check session validity
                            if let sessionId = sessionId, !self.isSessionValid(sessionId) {
                                return
                            }
                            self.parent.onTextExtracted("总结时发生意外错误")
                        }
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var searchText: String = "https://9to5mac.com/2025/05/29/when-are-new-macs-coming/"
    @State private var currentURL: String = "https://9to5mac.com/2025/05/29/when-are-new-macs-coming/" // 设置初始URL
    @State private var displayText: String = "正在加载初始页面..."
    @State private var isSummaryExpanded: Bool = false
    @State private var summaryContentHeight: CGFloat = 0
    @State private var webViewContainerHeight: CGFloat = 0
    
    // URL历史记录管理
    @State private var urlHistory: [String] = ["https://9to5mac.com/2025/05/29/when-are-new-macs-coming/"] // 添加初始URL到历史记录
    @State private var currentHistoryIndex: Int = 0 // 设置初始索引
    @State private var isHistoryNavigation: Bool = false
    
    // 计算前进后退按钮的状态
    private var canGoBack: Bool {
        return currentHistoryIndex > 0
    }
    
    private var canGoForward: Bool {
        return currentHistoryIndex < urlHistory.count - 1
    }

    // Define collapsed height and estimated padding/button height
    private let collapsedHeight: CGFloat = 60
    private let estimatedPaddingAndButtonHeight: CGFloat = 40 // Estimate for padding + button row

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Search Box and Buttons
            HStack(spacing: 8) {
                // Search Box
                HStack {
                    TextField("Enter URL here", text: $searchText)
                        .font(.system(size: 16))
                        .padding(.leading, 8)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .onSubmit {
                            loadURL()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // 后退按钮
                Button(action: goBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(canGoBack ? Color.orange : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!canGoBack)

                // Slash Button
                Button(action: loadURL) {
                    Text("Slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 40)
                        .background(Color.orange)
                        .cornerRadius(8)
                }

                // 前进按钮
                Button(action: goForward) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(canGoForward ? Color.orange : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!canGoForward)

                // Feature Buttons (Placeholder)
                HStack(spacing: 6) {
                    Button(action: translatePage) { 
                        Text("翻译")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10) // Adjusted padding
            .background(Color(red: 0.95, green: 0.95, blue: 0.95)) // Give top bar its background
            .zIndex(1) // Ensure top bar stays above ZStack content

            // Main Content Area: WebView overlaid by Summary View
            // Use GeometryReader to get the height available for ZStack content
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // WebView (takes up space below top bar)
                    WebView(urlString: $currentURL, onTextExtracted: { text in
                        self.displayText = text
                    }, onLinkClicked: { url in
                        // 处理链接点击
                        logger.info("ContentView - 链接被点击: \(url)")
                        
                        // 重置历史导航标志
                        self.isHistoryNavigation = false
                        
                        // 更新搜索框文本
                        self.searchText = url
                        
                        // 调用loadURL来加载新链接
                        logger.info("ContentView - 调用loadURL加载: \(url)")
                        self.loadURL()
                    })
                    .background(Color.white) // WebView background

                    // Floating Summary View Container
                    VStack(spacing: 0) {
                        ScrollView {
                            // Wrap Text in a VStack for proper GeometryReader measurement
                            VStack {
                                Text(try! AttributedString(markdown: displayText) ?? AttributedString(displayText))
                                    // Increase font size and add line spacing
                                    .font(.system(size: 18)) // Increased font size
                                    .lineSpacing(8) // Increased line spacing
                                    // Apply bold and blue color
                                    .bold() 
                                    .foregroundColor(.blue) // Changed from purple to blue
                                    .padding() // Apply padding *inside* measurement
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    // Measure the height of the Text content
                                    .background(GeometryReader { textGeo in
                                        Color.clear // Needs a view for the background
                                            .onAppear { // Update height when it appears
                                                self.summaryContentHeight = textGeo.size.height
                                            }
                                            .onChange(of: displayText) { _, _ in // Update height when text changes
                                                // Need slight delay or ensure update happens after layout pass
                                                DispatchQueue.main.async {
                                                    self.summaryContentHeight = textGeo.size.height
                                                }
                                            }
                                    })
                            }
                        }
                        // .background(...) // Removed inner background

                        // Button positioned at the bottom-right of this VStack
                        HStack {
                            Spacer() // Pushes button to the right
                            Button(action: {
                                withAnimation(.easeInOut) { // Add animation
                                    isSummaryExpanded.toggle()
                                }
                            }) {
                                Text(isSummaryExpanded ? "收起" : "展开")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .foregroundColor(.white)
                                    .background(Color.gray.opacity(0.5))
                                    .cornerRadius(5)
                            }
                        }
                        .padding(.trailing, 8)
                        .padding(.bottom, 4)
                        // .background(...) // Removed inner background

                    }
                    // Calculate dynamic height
                    .frame(height: calculateFloatingViewHeight(containerHeight: geometry.size.height))
                    .background(.regularMaterial) // Semi-transparent background effect
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.horizontal, 20) // Horizontal padding for the floating view
                    .padding(.top, 10) // Space below the top bar

                } // End ZStack
                .onAppear {
                    // Store the container height when ZStack appears
                    self.webViewContainerHeight = geometry.size.height
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    // Update container height if it changes (e.g., rotation)
                     self.webViewContainerHeight = newHeight
                }
            } // End GeometryReader for ZStack
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.95)) // Overall background
        .edgesIgnoringSafeArea(.bottom) // Allow content to go to bottom edge
        .onAppear { 
            checkAPIKeyAndSetInitialMessage()
            // 确保在视图出现时加载初始URL
            if currentURL.isEmpty {
                currentURL = searchText
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkPasteboardForURL()
            }
        }
        // Add onReceive to check pasteboard whenever its content changes while app is active
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            // Check pasteboard only if the app is currently active
            if scenePhase == .active {
                checkPasteboardForURL()
            }
        }
    }
    
    // Function to calculate the floating view's height
    private func calculateFloatingViewHeight(containerHeight: CGFloat) -> CGFloat {
        if isSummaryExpanded {
            // Calculate the max allowed height (half of the container)
            let maxHeight = containerHeight / 2
            // Calculate the desired content height (measured text + padding/button)
            let desiredHeight = summaryContentHeight + estimatedPaddingAndButtonHeight
            // Return the minimum of the desired height and the max height
            // Also ensure a minimum reasonable height if content is very short
            return max(collapsedHeight, min(desiredHeight, maxHeight))
        } else {
            // Return the fixed collapsed height
            return collapsedHeight
        }
    }

    // Function to load the URL
    private func loadURL() {
        logger.info("=== Starting new URL load ===")
        logger.info("Called from: \(Thread.isMainThread ? "Main Thread" : "Background Thread")")
        
        var urlToLoad = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlToLoad.isEmpty {
            logger.info("Search text is empty.")
            displayText = "请输入一个URL"
            return
        }
        
        // Standardize URL
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        logger.info("urlToLoad: \(urlToLoad)")
        logger.info("currentURL before update: \(currentURL)")
        logger.info("isHistoryNavigation: \(isHistoryNavigation)")

        // Generate new session ID
        let newSession = UUID()
        logger.info("Generated new session ID: \(newSession)")

        // Post notification with session ID to cancel ongoing operations
        NotificationCenter.default.post(name: .cancelWebViewAndSummary, object: newSession)
        logger.info("Posted cancellation notification with new session")
        
        // Update UI immediately
        displayText = "正在加载: \(urlToLoad)..."

        // Validate and update URL
        if let validatedURL = URL(string: urlToLoad) {
            logger.info("URL validation successful: \(validatedURL.absoluteString)")
            
            // 更新历史记录（仅在非历史导航时）
            if !isHistoryNavigation {
                // 如果当前不在历史记录的末尾，删除当前位置之后的所有记录
                if currentHistoryIndex < urlHistory.count - 1 {
                    urlHistory.removeSubrange((currentHistoryIndex + 1)..<urlHistory.count)
                }
                
                // 添加新URL到历史记录
                urlHistory.append(urlToLoad)
                currentHistoryIndex = urlHistory.count - 1
                logger.info("URL added to history. History count: \(urlHistory.count), Current index: \(currentHistoryIndex)")
            } else {
                logger.info("History navigation - not adding to history")
            }
            
            // 立即更新currentURL
            self.currentURL = urlToLoad
            logger.info("currentURL updated to: \(self.currentURL)")
            
        } else {
            logger.warning("Invalid URL after processing: \(urlToLoad)")
            displayText = "无效的URL: \(searchText)"
        }
    }

    private func checkAPIKeyAndSetInitialMessage() {
        if ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] == nil {
            displayText = "⚠️ Error: DASHSCOPE_API_KEY environment variable not set. Summarization disabled."
            logger.critical("DASHSCOPE_API_KEY not found in environment variables!")
        } else {
            // 确保初始URL被加载
            if currentURL.isEmpty {
                currentURL = searchText
            }
            displayText = "正在加载初始页面..."
        }
    }

    // --- New Function to Check Pasteboard ---
    private func checkPasteboardForURL() {
        // Check if pasteboard has a string
        guard let pastedString = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !pastedString.isEmpty else {
            // logger.debug("Pasteboard does not contain a non-empty string.")
            return
        }

        // Basic URL validation: Check if it can be parsed and has http/https scheme
        guard let url = URL(string: pastedString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            // logger.debug("Pasteboard string '\(pastedString)' is not a valid HTTP/HTTPS URL.")
            return
        }

        // Check if the valid URL from pasteboard is different from the current text
        if pastedString != searchText {
            logger.info("Found valid URL in pasteboard: \(pastedString). Updating searchText.")
            searchText = pastedString
             loadURL()
        } else {
            // logger.debug("Pasteboard URL '\(pastedString)' is the same as current searchText. No update needed.")
        }
    }

    // 后退功能
    private func goBack() {
        guard canGoBack else { return }
        currentHistoryIndex -= 1
        let previousURL = urlHistory[currentHistoryIndex]
        searchText = previousURL
        logger.info("Going back to: \(previousURL)")
        isHistoryNavigation = true
        loadURL()
        isHistoryNavigation = false
    }
    
    // 前进功能
    private func goForward() {
        guard canGoForward else { return }
        currentHistoryIndex += 1
        let nextURL = urlHistory[currentHistoryIndex]
        searchText = nextURL
        logger.info("Going forward to: \(nextURL)")
        isHistoryNavigation = true
        loadURL()
        isHistoryNavigation = false
    }
    
    // 翻译页面功能
    private func translatePage() {
        logger.info("Translate button clicked")
        displayText = "正在翻译页面..."
        
        // 发送通知给WebView的Coordinator来执行翻译
        NotificationCenter.default.post(name: .translateWebPage, object: nil)
    }
}

// Helper extension for button styling (Optional but recommended for cleaner code)
extension Text {
    func buttonStyle() -> some View {
        self.font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
