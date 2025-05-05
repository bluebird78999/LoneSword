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

// MARK: - Logger
let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.LoneSword", category: "QwenAPI")

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
struct QwenAPIManager {
    private let endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let modelName = "qwen3-235b-a22b" // Switched to a known model, adjust if needed
    private let requestTimeout: TimeInterval = 60 // Increased timeout for potentially longer streams
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

        let prompt = "请对以下从网页提取的文本内容进行总结，提取核心要点：\n\n---\n\(text)\n---"
        let requestBody = QwenRequest(
            model: modelName,
            messages: [QwenRequest.Message(role: "user", content: prompt)]
            // stream is true by default in QwenRequest struct
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            logger.debug("Sending stream request to Qwen API.")
        } catch {
            logger.error("Failed to encode request body: \(error.localizedDescription)")
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
        // Optionally observe progress (though we'll use didFinish)
        // webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if the urlString actually changed and is different from current webView URL
        if let url = URL(string: urlString), webView.url?.absoluteString != urlString {
            let request = URLRequest(url: url)
            logger.info("UpdateUIView: Loading new URL: \(self.urlString)")
            webView.load(request)

            // --- Start: Attempt early text extraction after 3 seconds ---
            let script = "document.body.innerText || document.documentElement.innerText"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak webView, self] in
                guard let webView = webView else { return }
                // Check if the webView is still potentially loading the requested URL
                // Use contains as the exact URL might change slightly during loading (e.g., redirects)
                if (webView.url?.absoluteString.contains(self.urlString)) ?? false || webView.isLoading {
                     logger.info("Attempting EARLY text extraction (3s after load start)...")
                     webView.evaluateJavaScript(script) { (result, error) in
                        DispatchQueue.main.async { // Ensure UI update is on main
                            if let error = error {
                                logger.warning("Early JavaScript evaluation failed: \(error.localizedDescription)")
                                // Optionally update display text, but might conflict with loading messages
                                // self.onTextExtracted("Early extraction failed.")
                                return
                            }
                            if let earlyText = result as? String, !earlyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                logger.info("Early Extracted Text Length: \(earlyText.count)")
                                // Do not summarize early text, just display it
                                // self.onTextExtracted("(Early) \(earlyText)")
                            } else {
                                logger.info("No text for early extraction.")
                                // Don't overwrite loading/error messages with "no text found" here
                            }
                        }
                    }
                } else {
                    logger.info("Skipping early text extraction: URL changed or load finished too quickly.")
                }
            }
             // --- End: Attempt early text extraction ---

        } else if urlString.isEmpty && webView.url != nil {
             // Handle case where urlString is cleared
             webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
             DispatchQueue.main.async {
                 // Use weak self here as well if accessing parent properties directly
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
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // --- WKNavigationDelegate Methods ---
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
             // Update status when navigation starts
            DispatchQueue.main.async {
                 // Check if the URL string is valid before showing loading message
                 if URL(string: self.parent.urlString) != nil {
                    self.parent.onTextExtracted("Loading \(self.parent.urlString)...")
                 } else {
                    // Handle case where an invalid URL might have been passed initially
                     self.parent.onTextExtracted("Invalid URL provided.")
                 }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page finished loading, attempt to extract text immediately
            logger.info("Page finished loading, attempting text extraction for \(self.parent.urlString)")
            self.extractTextAndSummarize(from: webView) // Modified call
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Handle navigation errors
            logger.error("Webview navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.onTextExtracted("Error loading page: \(error.localizedDescription)")
            }
        }
         func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
             // Handle errors that occur before the page starts loading (e.g., server not found)
             logger.error("Webview provisional navigation failed: \(error.localizedDescription)")
             DispatchQueue.main.async {
                 self.parent.onTextExtracted("Error loading page: \(error.localizedDescription)")
             }
         }

        // --- Text Extraction & AI submit---
        private func extractTextAndSummarize(from webView: WKWebView) {
            let script = "document.body.innerText || document.documentElement.innerText"
            webView.evaluateJavaScript(script) { [weak self] (result, error) in
                 guard let self = self else { return }

                 if let error = error {
                     logger.error("JavaScript evaluation failed: \(error.localizedDescription)")
                      DispatchQueue.main.async {
                         self.parent.onTextExtracted("Error extracting text from page.")
                      }
                     return
                 }

                 guard let extractedText = result as? String, !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                     logger.warning("No text extracted or result was not a string after page load.")
                      DispatchQueue.main.async {
                         self.parent.onTextExtracted("No text content found on page to summarize.")
                      }
                     return
                 }

                 // Log the extracted text (optional)
                 // logger.info("Extracted Text: \(extractedText)") 
                 logger.info("Successfully extracted text, length: \(extractedText.count). Submitting for summarization.")

                 // Update UI to indicate summarization is starting
                 DispatchQueue.main.async {
                      self.parent.onTextExtracted("Summarizing extracted text...")
                 }

                 // Call API manager in a background task
                 Task {
                     do {
                         let summary = try await self.apiManager.summarize(text: extractedText)
                         logger.info("Summarization successful.")
                         // Update UI on main thread with the summary
                         await MainActor.run {
                             self.parent.onTextExtracted(summary)
                         }
                     } catch let error as APIError {
                         logger.error("Summarization failed: \(error.localizedDescription)")
                         await MainActor.run {
                             self.parent.onTextExtracted("Summarization Error: \(error.localizedDescription)")
                         }
                     } catch {
                          logger.error("Unexpected error during summarization: \(error.localizedDescription)")
                         await MainActor.run {
                              self.parent.onTextExtracted("An unexpected error occurred during summarization.")
                         }
                     }
                 }
                 // DO NOT call onTextExtracted here with the raw text
                 // self.parent.onTextExtracted(extractedText) <-- This was incorrect
            }
        }

         // Cleanup observer if you were using KVO for estimatedProgress
         // deinit {
         //    // If you added the observer, you must remove it
         //     // webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
         // }

         // KVO method if observing estimatedProgress (alternative to didFinish)
         /*
         override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
             if keyPath == #keyPath(WKWebView.estimatedProgress) {
                 if let webView = object as? WKWebView {
                     print("Progress: \(webView.estimatedProgress)")
                     DispatchQueue.main.async {
                          self.parent.onTextExtracted("Loading... \(Int(webView.estimatedProgress * 100))%")
                     }
                     // Trigger extraction near completion (e.g., > 0.95)
                     // Be cautious, might fire multiple times or not at all if load is fast/fails
                     if webView.estimatedProgress > 0.95 {
                          // Maybe add a flag to extract only once per load cycle
                          // extractText(from: webView)
                     }
                 }
             }
         }
         */
    }
}

struct ContentView: View {
    @State private var searchText: String = "https://www.chinanews.com.cn/cj/2025/05-05/10410615.shtml"
    @State private var currentURL: String = "https://wallstreetcn.com/live/global" // Initial URL
    // State variable to hold the text extracted from the web page or status messages
    @State private var displayText: String = "Enter a URL and tap Slash."
    
    var body: some View {
        VStack(spacing: 15) {
            // 搜索框和按钮组
            HStack(spacing: 15) {
                // 搜索框
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
                
                // Slash按钮
                Button(action: loadURL) { // Action now calls loadURL
                    Text("Slash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 44)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                
                // 功能按钮组 (Kept for layout, actions can be added later)
                HStack(spacing: 10) {
                    Button(action: { }) { Text("识别AI生成").buttonStyle() }
                    Button(action: { }) { Text("AI总结").buttonStyle() }
                    Button(action: { }) { Text("翻译").buttonStyle() }
                }
            }
            .padding(.horizontal, 20)
            
            // 紫色文字显示区域
            ScrollView {
                Text(displayText) // Display the state variable here
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.8))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.95, green: 0.95, blue: 1.0))
                    .cornerRadius(8)
            }
            .frame(height: 100) // Increased height slightly for more text
            .padding(.horizontal, 20)
            
            // WKWebView 显示区域
            WebView(urlString: $currentURL, onTextExtracted: { text in
                // This closure is called by the Coordinator
                self.displayText = text
            })
                .background(Color.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        // Update display text when the view appears based on initial URL
        .onAppear { checkAPIKeyAndSetInitialMessage() }
    }
    
    // Function to load the URL
    private func loadURL() {
        var urlToLoad = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlToLoad.isEmpty {
             logger.info("Search text is empty.")
             displayText = "Please enter a URL."
             return
        }
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        if let _ = URL(string: urlToLoad) {
            // Set loading status *before* updating URL to trigger WebView reload
            // Note: The Coordinator's didStartProvisionalNavigation will likely overwrite this message quickly.
            // displayText = "Preparing to load \(urlToLoad)..."

            // Update the URL, which will trigger WebView updateUIView
            currentURL = urlToLoad
            logger.info("Loading URL: \(self.currentURL)")
            
        } else {
            logger.warning("Invalid URL entered: \(self.searchText)")
            displayText = "Invalid URL: \(searchText)"
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
