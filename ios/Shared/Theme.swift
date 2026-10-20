import SwiftUI

/// 视觉 token，与 UI 定稿一致：米白纸面 / 墨色 / 朱红点缀。App 与小组件共用。
extension Color {
    /// 纸面背景 #FAF8F4
    static let paperBg = Color(red: 250 / 255, green: 248 / 255, blue: 244 / 255)
    /// 墨色主文字 #23272B
    static let ink = Color(red: 35 / 255, green: 39 / 255, blue: 43 / 255)
    /// 次级文字 #5C636B
    static let ink2 = Color(red: 92 / 255, green: 99 / 255, blue: 107 / 255)
    /// 弱文字 #9AA1A9
    static let ink3 = Color(red: 154 / 255, green: 161 / 255, blue: 169 / 255)
    /// 卡片底 #F2EFE8
    static let cardBg = Color(red: 242 / 255, green: 239 / 255, blue: 232 / 255)
    /// 细线 #E7E2D8
    static let line = Color(red: 231 / 255, green: 226 / 255, blue: 216 / 255)
    /// 朱红点缀 #B8402F
    static let accentRed = Color(red: 184 / 255, green: 64 / 255, blue: 47 / 255)
    /// 朱红浅底 #F7E9E5
    static let accentSoft = Color(red: 247 / 255, green: 233 / 255, blue: 229 / 255)
}

/// 细分隔线：整条浅色，左侧一段朱红。与首页 UI 稿一致。
struct AccentDivider: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.line)
                .frame(height: 1)
            Rectangle()
                .fill(Color.accentRed)
                .frame(width: 44, height: 1)
        }
    }
}

/// 顶栏同款图标按钮的外观规格：36pt 圆、1pt 细线色描边、墨色 16pt 图标。
/// 首页顶栏四个入口（测试 / 全部 / 分享 / 个人中心）共用，保证视觉完全一致：
/// NavigationLink 与普通 Button 的 label 都用 TopBarIconLabel 渲染。
enum TopBarIconSpec {
    static let diameter: CGFloat = 36
    static let iconSize: CGFloat = 16
}

struct TopBarIconLabel: View {
    let systemName: String
    /// 禁用态（如当前成语已锁定、不可分享时）图标转弱灰
    var isEnabled: Bool = true

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: TopBarIconSpec.iconSize, weight: .medium))
            .foregroundColor(isEnabled ? .ink : .ink3)
            .frame(width: TopBarIconSpec.diameter, height: TopBarIconSpec.diameter)
            .overlay(
                Circle().stroke(Color.line, lineWidth: 1)
            )
            .contentShape(Circle())
    }
}
