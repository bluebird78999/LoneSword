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
        // Only load if the urlString actually changed and is different from current webView URL
        if let url = URL(string: urlString), webView.url?.absoluteString != urlString {
            // Note: Cancellation is handled via Notification before this point
            let request = URLRequest(url: url)
            logger.info("UpdateUIView: Loading new URL: \(self.urlString)")
            // Reset coordinator state for the new load
            context.coordinator.resetExtractionState()
            webView.load(request)

            // --- Start: Attempt early text extraction after 3 seconds ---
            let script = "document.body.innerText || document.documentElement.innerText"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak webView, coordinator = context.coordinator, urlString = self.urlString] in // Capture necessary values
                guard let webView = webView else { return }
                // Check if the webView is still potentially loading the requested URL
                // Use contains as the exact URL might change slightly during loading (e.g., redirects)
                // Also check if an early summarization hasn't already completed for this URL
                if ((webView.url?.absoluteString.contains(urlString)) ?? false || webView.isLoading) { // && !coordinator.didSummarizeEarly Removed didSummarizeEarly check here
                    logger.info("Attempting EARLY text extraction (3s after load start)... URL: \(urlString)")
                    webView.evaluateJavaScript(script) { (result, error) in
                        // Run processing logic on the main thread
                        DispatchQueue.main.async {
                            if let error = error {
                                logger.warning("Early JavaScript evaluation failed: \(error.localizedDescription)")
                                return
                            }
                            if let earlyText = result as? String, !earlyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // Process the extracted early text
                                coordinator.processExtractedText(earlyText, fromEarlyAttempt: true)
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
            // --- End: Attempt early text extraction ---

        } else if urlString.isEmpty && webView.url != nil {
             // Handle case where urlString is cleared (also stops loading)
             webView.stopLoading() // Explicitly stop loading if URL is cleared
             context.coordinator.resetExtractionState() // Reset state when cleared
             webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
             DispatchQueue.main.async {
                 self.onTextExtracted("Enter a URL and tap Slash.")
             }
        }
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
            logger.debug("Coordinator init: Notification observer added.")
        }
        
        deinit {
            logger.debug("Coordinator deinit: Removing observer and cancelling task.")
            // Cancel any ongoing task when the Coordinator is deallocated
            currentSummarizationTask?.cancel()
            // Remove the notification observer
            NotificationCenter.default.removeObserver(self, name: .cancelWebViewAndSummary, object: nil)
        }
        
        // Reset state for a new URL load or cancellation
        func resetExtractionState() {
            logger.debug("Resetting coordinator extraction state.")
            earlyExtractedText = nil
            earlyExtractedLength = 0
            didSummarizeEarly = false
            // Cancel any task associated with the previous state
            currentSummarizationTask?.cancel()
        }
        
        // --- Notification Handler ---
        @objc private func handleCancelNotification(_ notification: Notification) {
            logger.info("Cancellation notification received.")
            DispatchQueue.main.async { // Ensure WKWebView/UI updates are on main thread
                logger.info("Executing cancellation: Stopping WebView load and cancelling summary task.")
                self.webViewInstance?.stopLoading()
                // Reset state upon cancellation
                self.resetExtractionState()
                // Optionally update the display text
                // self.parent.onTextExtracted("Operations cancelled.")
            }
        }
        
        // --- WKNavigationDelegate Methods ---
        
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

            // Add checks similar to the early extraction to ensure we process the correct page
            guard let webViewURL = webView.url, (webViewURL.absoluteString == requestedURL || webViewURL.absoluteString.contains(requestedURL)) else {
                 logger.warning("didFinish: WebView URL does not match requested URL. Skipping final extraction. WebView: \(currentWebViewURL ?? "nil"), Requested: \(requestedURL)")
                 return
            }

            // Check if the task was cancelled
            if Task.isCancelled { // Consider checking associated task
                 logger.info("Skipping final text extraction as task seems cancelled.")
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
            webView.evaluateJavaScript(script) { [weak self] (result, error) in
                guard let self = self else { return }
                DispatchQueue.main.async { // Ensure UI/state updates are on main thread
                    if let error = error {
                        logger.error("Final JavaScript evaluation failed: \(error.localizedDescription)")
                         self.parent.onTextExtracted("Error extracting final text from page.")
                        return
                    }
                    guard let finalExtractedText = result as? String, !finalExtractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        logger.warning("No text extracted or result was not a string after page load (didFinish). URL: \(requestedURL)")
                        // If early summary happened but final is empty, maybe revert?
                        // For now, just report no text found.
                        if !self.didSummarizeEarly { // Only update if no early summary is showing
                             self.parent.onTextExtracted("No text content found on page to summarize.")
                        }
                        return
                    }
                    // Process the extracted final text
                    self.processExtractedText(finalExtractedText, fromEarlyAttempt: false)
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
        func processExtractedText(_ text: String, fromEarlyAttempt: Bool) {
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
                        self.parent.onTextExtracted("Early text > 2000 chars. Summarizing preview...")
                        // Start the summarization task
                        submitForSummarization(text: text)
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
                        submitForSummarization(text: text)
                    } else {
                        logger.info("Final text length (\(currentTextLength)) not > 2x early length (\(self.earlyExtractedLength)). Keeping early summary.")
                        // Do nothing, keep the summary already displayed from the early attempt.
                        // Optionally update display text to confirm? e.g.:
                        // self.parent.onTextExtracted("完整网页文本与预览相似，保留早期总结。\n---\n" + (currentSummary ?? "")) // Need to store current summary if doing this
                    }
                } else {
                    // No early summary was performed, summarize the final text.
                    logger.info("No early summary was performed previously. Summarizing final text.")
                     // Update UI immediately before async task
                     self.parent.onTextExtracted("Summarizing extracted text...")
                    // Submit the final text for summarization
                    submitForSummarization(text: text)
                }
                // Resetting state here might be premature if didFinish gets called multiple times?
                // Consider resetting only when a new load starts or is cancelled.
            }
        }

        // --- Submits text for API Summarization ---
        private func submitForSummarization(text: String) {
            // Cancel any previous summarization task before starting a new one
            currentSummarizationTask?.cancel() // Cancel previous task if any
            logger.debug("submitForSummarization: Previous summary task cancelled (if existed). Starting new task.")

            // Store the handle to the new task
            self.currentSummarizationTask = Task { // Assign to instance variable
                do {
                    // Check for cancellation *before* starting the network request
                    try Task.checkCancellation()
                    logger.info("Starting API summarization task for text length: \(text.count).")

                    let summary = try await self.apiManager.summarize(text: text)

                    // Check for cancellation *after* the network request completes
                    try Task.checkCancellation()
                    logger.info("Summarization successful.")

                    await MainActor.run { [weak self] in // Use weak self
                        guard let self = self else { return }
                        // Final check before UI update
                        guard !Task.isCancelled else {
                            logger.info("Summarization task cancelled just before UI update.")
                            return
                        }
                        logger.debug("Updating display text with summary.")
                        self.parent.onTextExtracted(summary)
                    }
                } catch is CancellationError {
                     logger.info("Summarization Task cancelled.")
                     // Optionally update UI on main thread to indicate cancellation
                     // await MainActor.run { [weak self] in self?.parent.onTextExtracted("Summarization cancelled.") }
                } catch let error as APIError {
                    logger.error("Summarization failed: \(error.localizedDescription)")
                    await MainActor.run { [weak self] in // Use weak self
                        // Check for cancellation before showing error
                        if !Task.isCancelled {
                            self?.parent.onTextExtracted("Summarization Error: \(error.localizedDescription)")
                        }
                    }
                } catch {
                     logger.error("Unexpected error during summarization: \(error.localizedDescription)")
                    await MainActor.run { [weak self] in // Use weak self
                         // Check for cancellation before showing error
                        if !Task.isCancelled {
                            self?.parent.onTextExtracted("An unexpected error occurred during summarization.")
                        }
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var searchText: String = "https://www.chinanews.com.cn/cj/2025/05-05/10410615.shtml"
    @State private var currentURL: String = "https://www.chinadaily.com.cn/a/202505/05/WS6818d781a310a04af22bd883.html" // Initial URL
    // State variable to hold the text extracted from the web page or status messages
    @State private var displayText: String = "Enter a URL and tap Slash."
    // State variable to control the summary view expansion
    @State private var isSummaryExpanded: Bool = false // Changed default to false (collapsed)
    // State variables for adaptive height calculation
    @State private var summaryContentHeight: CGFloat = 0
    @State private var webViewContainerHeight: CGFloat = 0

    // Define collapsed height and estimated padding/button height
    private let collapsedHeight: CGFloat = 60
    private let estimatedPaddingAndButtonHeight: CGFloat = 40 // Estimate for padding + button row

    var body: some View {
        VStack(spacing: 0) { // Use 0 spacing for manual control
            // Top Bar: Search Box and Buttons
            HStack(spacing: 15) {
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
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Slash Button
                Button(action: loadURL) {
                    Text("Slash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 44)
                        .background(Color.orange)
                        .cornerRadius(8)
                }

                // Feature Buttons (Placeholder)
                HStack(spacing: 10) {
                    Button(action: { }) { Text("翻译").buttonStyle() }
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
        .onAppear { checkAPIKeyAndSetInitialMessage() }
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
        var urlToLoad = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlToLoad.isEmpty {
            logger.info("Search text is empty.")
            // Maybe clear display text or show a message?
            // displayText = "Please enter a URL."
            return // Don't proceed if empty
        }
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }

        // Check if the URL is the same as the current one
        if urlToLoad == currentURL {
            logger.info("Attempted to load the same URL (\(urlToLoad)). No action taken.")
            return // Do nothing if the URL hasn't changed
        }

        // --- If URL is different, proceed with cancellation and loading ---

        // Post notification FIRST to cancel ongoing WebView loading and API calls
        NotificationCenter.default.post(name: .cancelWebViewAndSummary, object: nil)
        logger.info("Posted cancellation notification.")

        // Validate the potentially modified URL
        if let _ = URL(string: urlToLoad) {
            // Update the URL, which will trigger WebView updateUIView
            currentURL = urlToLoad
            logger.info("Loading URL: \(self.currentURL)")
        } else {
            // This case should be less likely now due to prefixing logic, but keep for safety
            logger.warning("Invalid URL after processing: \(urlToLoad)")
            displayText = "Invalid URL: \(searchText)" // Show original input in error
        }
    }

    private func checkAPIKeyAndSetInitialMessage() {
        if ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] == nil {
             displayText = "⚠️ Error: DASHSCOPE_API_KEY environment variable not set. Summarization disabled."
             logger.critical("DASHSCOPE_API_KEY not found in environment variables!")
        } else {
             if URL(string: currentURL) != nil {
                 displayText = "Initial page loaded. Enter a new URL or tap Slash to reload and summarize."
             } else {
                 displayText = "Enter a valid URL and tap Slash."
             }
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
            // Optionally, you could also immediately trigger loadURL() here if desired
            // loadURL()
        } else {
            // logger.debug("Pasteboard URL '\(pastedString)' is the same as current searchText. No update needed.")
        }
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
