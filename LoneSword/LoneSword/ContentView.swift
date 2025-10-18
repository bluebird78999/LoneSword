//
//  ContentView.swift
//  LoneSword
//
//  Created by LiuHongfeng on 2025/10/18.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @StateObject private var browserViewModel = BrowserViewModel()
    
    var isLandscape: Bool {
        // 更可靠的检测方法：竖屏是 vertical，横屏是 regular
        verticalSizeClass == .compact
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.98, blue: 0.98)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    // 横屏布局：左侧 2/3 网页 + 右侧 1/3 AI
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            BrowserToolbarView(viewModel: browserViewModel)
                            
                            WebViewContainer(viewModel: browserViewModel)
                                .ignoresSafeArea(.all, edges: .all)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: geometry.size.width * 2 / 3, height: geometry.size.height)
                        
                        VStack(spacing: 0) {
                            AIAssistantView()
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
                                .ignoresSafeArea(.all, edges: .all)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(height: geometry.size.height * 2 / 3)
                        
                        AIAssistantView()
                            .environmentObject(browserViewModel)
                            .frame(height: geometry.size.height * 1 / 3)
                    }
                }
            }
        }
        .onAppear {
            // 历史写入
            browserViewModel.onPageFinished = { url, title in
                let record = BrowserHistory(url: url, title: title)
                modelContext.insert(record)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
