import SwiftUI
import WebKit
import os

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    private static let logger = Logger(subsystem: "com.lonesword.browser", category: "UI")
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = viewModel.ensureWebView()
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setNeedsLayout()
        webView.layoutIfNeeded()
        
        attachRefreshControl(to: webView, coordinator: context.coordinator)
        
        if webView.url == nil, let url = URL(string: viewModel.currentURL) {
            webView.load(URLRequest(url: url))
        }
        
        Self.logger.debug("makeUIView: frame.size=\(webView.frame.size.width)x\(webView.frame.size.height)")
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.setNeedsLayout()
        
        Self.logger.debug("updateUIView: frame.size=\(uiView.frame.size.width)x\(uiView.frame.size.height)")
        
        // Only load if nothing has been loaded yet - avoid overriding in-progress navigation
        if uiView.url == nil, let url = URL(string: viewModel.currentURL) {
            uiView.load(URLRequest(url: url))
        }
    }
    
    private func attachRefreshControl(to webView: WKWebView, coordinator: Coordinator) {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject {
        let viewModel: BrowserViewModel
        init(viewModel: BrowserViewModel) {
            self.viewModel = viewModel
        }
        
        @objc func handleRefresh(_ sender: UIRefreshControl) {
            viewModel.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                sender.endRefreshing()
            }
        }
    }
}
