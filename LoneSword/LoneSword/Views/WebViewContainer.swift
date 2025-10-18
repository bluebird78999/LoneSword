import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = viewModel.ensureWebView()
        attachRefreshControl(to: webView)
        // 若还未加载任何页面，立即加载一次
        if webView.url == nil, let url = URL(string: viewModel.currentURL) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 不在 updateUIView 主动触发加载，避免覆盖 ViewModel 正在发起的导航
        // 仅在 WebView 还未加载任何页面时，执行一次性的纠偏加载
        if uiView.url == nil, let url = URL(string: viewModel.currentURL) {
            uiView.load(URLRequest(url: url))
        }
    }
    
    private func attachRefreshControl(to webView: WKWebView) {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(contextCoordinator(), action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    private func contextCoordinator() -> Coordinator {
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
