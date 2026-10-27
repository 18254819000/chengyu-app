import SafariServices
import SwiftUI

/// App 内打开网页：SFSafariViewController，不跳外部浏览器。
/// 仅用于 http(s) 内容页（隐私政策、使用条款）；mailto 与 App Store 订阅管理仍走系统外部打开。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
