import Foundation

/// 全局集中配置。App 与小组件共用同一份。
enum AppConfig {
    /// 后端 API 地址（不带结尾斜杠）。
    /// 本地联调：模拟器直接用 localhost；真机调试改成开发机局域网 IP，如 http://192.168.1.10:3000。
    /// 上线时改为正式域名，如 https://api.example.com。
    static let apiBaseURL = URL(string: "https://chengyu-backend.onrender.com")!
    static let apiPrefix = "/api/v1"

    /// App Group：App 与小组件共享数据的容器，两个 Target 的 entitlements 必须一致
    static let appGroupID = "group.com.mengma.dailyidiom2"

    /// 深链接 Scheme（与 App Info.plist 的 CFBundleURLSchemes 一致）
    static let urlScheme = "dailyidiom"

    /// 后台未配置商品 ID 时的兜底值，与 App Store Connect 中创建的自动续期订阅商品 ID 保持一致
    static let defaultMonthlyProductID = "com.mengma.dailyidiom.monthly"
    static let defaultYearlyProductID = "com.mengma.dailyidiom.yearly"

    // 隐私政策 / 用户协议：由后端公开页提供，内容在管理端「协议与政策」中维护
    static let privacyPolicyURL = URL(string: "https://chengyu-backend.onrender.com/pages/privacy")!
    static let termsOfUseURL = URL(string: "https://chengyu-backend.onrender.com/pages/terms")!
    // 客服邮箱（与隐私政策中的联系邮箱一致）
    static let supportEmail = "kingsummerai@gmail.com"

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
