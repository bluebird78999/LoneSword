import SwiftUI
import SwiftData
import WebKit
import os

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @StateObject private var browserViewModel = BrowserViewModel()
    @StateObject private var aiAssistantViewModel = AIAssistantViewModel()
    @StateObject private var speechService = SpeechRecognitionService()
    
    private static let logger = Logger(subsystem: "com.lonesword.browser", category: "UI")
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                Color.clear
                
                if geometry.size.width > geometry.size.height {
                    landscapeLayout(in: geometry.size)
                } else {
                    portraitLayout(in: geometry.size)
                }
            }
        }
        .onAppear {
            Self.logger.debug("ContentView onAppear")
            browserViewModel.setModelContext(modelContext)
            browserViewModel.loadHistoryFromStorage()
            
            aiAssistantViewModel.setModelContext(modelContext)
            aiAssistantViewModel.loadAPIKeyFromKeychain()
            aiAssistantViewModel.loadSettings()
            
            aiAssistantViewModel.webContentProvider = { [weak browserViewModel] in
                await withCheckedContinuation { continuation in
                    browserViewModel?.webView?.evaluateJavaScript("document.documentElement.innerText") { result, _ in
                        if let text = result as? String { continuation.resume(returning: text) }
                        else { continuation.resume(returning: "") }
                    }
                }
            }
        }
    }
    
    // MARK: - Layout helpers
    
    @ViewBuilder
    private func landscapeLayout(in size: CGSize) -> some View {
        if aiAssistantViewModel.aiInsightEnabled {
            HStack(spacing: 0) {
                BrowserPageView(viewModel: browserViewModel, aiViewModel: aiAssistantViewModel)
                    .frame(width: size.width * 2 / 3, height: size.height)
                
                AIAssistantView(vm: aiAssistantViewModel, speech: speechService)
                    .environmentObject(browserViewModel)
                    .frame(width: size.width * 1 / 3, height: size.height)
            }
            .frame(width: size.width, height: size.height)
        } else {
            BrowserPageView(viewModel: browserViewModel, aiViewModel: aiAssistantViewModel)
                .frame(width: size.width, height: size.height)
        }
    }
    
    @ViewBuilder
    private func portraitLayout(in size: CGSize) -> some View {
        if aiAssistantViewModel.aiInsightEnabled {
            VStack(spacing: 0) {
                BrowserPageView(viewModel: browserViewModel, aiViewModel: aiAssistantViewModel)
                    .frame(height: size.height * 2 / 3)
                
                AIAssistantView(vm: aiAssistantViewModel, speech: speechService)
                    .environmentObject(browserViewModel)
                    .frame(height: size.height * 1 / 3)
            }
        } else {
            BrowserPageView(viewModel: browserViewModel, aiViewModel: aiAssistantViewModel)
                .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - Reusable browser page (toolbar + webview)

/// Combines the browser toolbar and web view container into a single reusable component.
/// Eliminates layout duplication between landscape and portrait modes.
struct BrowserPageView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @ObservedObject var aiViewModel: AIAssistantViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbarView(viewModel: viewModel, aiViewModel: aiViewModel)
            WebViewContainer(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BrowserHistory.self, inMemory: true)
}
