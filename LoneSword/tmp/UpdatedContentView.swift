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

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    }
}

struct ContentView: View {
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            // 搜索框和按钮组
            HStack(spacing: 15) {
                // 搜索框
                HStack {
                    TextField("Slash a web or Search anything!", text: $searchText)
                        .font(.system(size: 16))
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // 搜索按钮
                Button(action: {
                    // 搜索操作
                }) {
                    Text("Go !")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 44)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                
                // 功能按钮组
                HStack(spacing: 10) {
                    Button(action: {
                        // 识别AI生成
                    }) {
                        Text("识别AI生成")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // AI总结
                    }) {
                        Text("AI总结")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // 翻译
                    }) {
                        Text("翻译")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // 紫色文字显示区域
            ScrollView {
                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur nec arcu molestie, mollis purus sit amet, sodales libero. Nulla id odio maximus, congue.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.8))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.95, green: 0.95, blue: 1.0))
                    .cornerRadius(8)
            }
            .frame(height: 70)
            .padding(.horizontal, 20)
            
            // 黑色文字显示区域（使用WKWebView）
            WebView(urlString: "https://wallstreetcn.com/live/global")
            .background(Color.white)
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
    }
}

#Preview {
    ContentView()
}
