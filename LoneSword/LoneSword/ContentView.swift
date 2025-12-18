//
//  ContentView.swift
//  LoneSword
//
//  Created by LiuHongfeng on 2025/10/18.
//

import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @StateObject private var browserViewModel = BrowserViewModel()
    @StateObject private var aiAssistantViewModel = AIAssistantViewModel()
    @State private var layoutReady = false
    
    var isLandscape: Bool {
        // 更可靠的检测方法：竖屏是 vertical，横屏是 regular
        verticalSizeClass == .compact
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let _ = print("DEBUG: ContentView GeometryReader size=\(geometry.size)")
                Color.clear
                    .onAppear {
                        if !layoutReady {
                            layoutReady = true
                            print("DEBUG: Layout is now ready")
                        }
                    }
                
                if geometry.size.width > geometry.size.height {
                    // 横屏布局：左侧 2/3 网页 + 右侧 1/3 AI
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            BrowserToolbarView(viewModel: browserViewModel)
                            
                            WebViewContainer(viewModel: browserViewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .id("webview-landscape-\(layoutReady)")
                        }
                        .frame(width: geometry.size.width * 2 / 3, height: geometry.size.height)
                        
                        VStack(spacing: 0) {
                            AIAssistantView(vm: aiAssistantViewModel)
                                .environmentObject(browserViewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: geometry.size.width * 1 / 3, height: geometry.size.height)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    // 竖屏布局：上部 2/3 网页 + 下部 1/3 AI
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            BrowserToolbarView(viewModel: browserViewModel)
                            
                            WebViewContainer(viewModel: browserViewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .id("webview-portrait-\(layoutReady)")
                        }
                        .frame(height: geometry.size.height * 2 / 3)
                        
                        AIAssistantView(vm: aiAssistantViewModel)
                            .environmentObject(browserViewModel)
                            .frame(height: geometry.size.height * 1 / 3)
                    }
                }
            }
        }
        .onAppear {
            print("DEBUG: ContentView onAppear called")
            // 设置 ModelContext 并加载历史记录
            browserViewModel.setModelContext(modelContext)
            browserViewModel.loadHistoryFromStorage()
            
            // 设置 AI Assistant 的 ModelContext
            aiAssistantViewModel.setModelContext(modelContext)
            aiAssistantViewModel.loadAPIKeyFromKeychain()
            
            // 设置 web content provider
            aiAssistantViewModel.webContentProvider = { [weak browserViewModel] in
                await withCheckedContinuation { continuation in
                    browserViewModel?.webView?.evaluateJavaScript("document.documentElement.innerText") { result, _ in
                        if let text = result as? String { continuation.resume(returning: text) }
                        else { continuation.resume(returning: "") }
                    }
                }
            }
            
            // 强制触发布局刷新
            DispatchQueue.main.async {
                // 这会触发 SwiftUI 重新计算布局
                print("DEBUG: Forcing layout refresh")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
