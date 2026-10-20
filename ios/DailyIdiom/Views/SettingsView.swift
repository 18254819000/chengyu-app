import SwiftUI

/// 个人中心内容：由首页右上角个人中心入口以 NavigationLink 推入本页。
/// 调用方（LearnView 的导航目标）负责设置导航标题。
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: StoreManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                subscriptionRow
                rowDivider
                actionRow("恢复购买", trailing: store.isRestoring ? "恢复中…" : nil) {
                    Task { await store.restorePurchases() }
                }
                rowDivider
                actionRow("管理订阅") {
                    openManageSubscriptions()
                }
                rowDivider
                NavigationLink {
                    WidgetGuideView()
                } label: {
                    rowLabel("把小组件加到桌面", trailing: nil)
                }
                rowDivider
                actionRow("隐私政策") {
                    openURL(AppConfig.privacyPolicyURL)
                }
                rowDivider
                actionRow("用户协议") {
                    openURL(AppConfig.termsOfUseURL)
                }
                rowDivider
                actionRow("联系客服") {
                    if let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                        openURL(url)
                    }
                }
                rowDivider

                Text("每日成语 版本 \(AppConfig.appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.ink3)
                    .tracking(1)
                    .padding(.top, 26)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .alert("提示", isPresented: messageBinding) {
            Button("知道了") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )
    }

    // MARK: 订阅状态行

    private var subscriptionRow: some View {
        Button {
            if state.isEntitled {
                openManageSubscriptions()
            } else {
                state.showPaywall = true
            }
        } label: {
            HStack {
                Text("我的订阅")
                    .font(.system(size: 15))
                    .foregroundColor(.ink)
                Spacer()
                Text(subscriptionStatusText)
                    .font(.system(size: 13))
                    .foregroundColor(state.isEntitled ? .ink3 : .accentRed)
                    .fontWeight(state.isEntitled ? .regular : .semibold)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.ink3)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subscriptionStatusText: String {
        guard state.isEntitled else { return "未订阅 · 去订阅" }
        if let date = state.entitlement?.expiresDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "yyyy年M月d日"
            return "订阅中 · 到期 \(f.string(from: date))"
        }
        return "订阅中"
    }

    // MARK: 通用行

    private func actionRow(_ title: String, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(title, trailing: trailing)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, trailing: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.ink)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 13))
                    .foregroundColor(.ink3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.ink3)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.line)
            .frame(height: 1)
    }

    private func openManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(url)
        }
    }
}
