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
                actionRow("Restore Purchases", trailing: store.isRestoring ? "Restoring…" : nil) {
                    Task { await store.restorePurchases() }
                }
                rowDivider
                actionRow("Manage Subscription") {
                    openManageSubscriptions()
                }
                rowDivider
                NavigationLink {
                    WidgetGuideView()
                } label: {
                    rowLabel("Add Widget to Home Screen", trailing: nil)
                }
                rowDivider
                actionRow("Privacy Policy") {
                    openURL(AppConfig.privacyPolicyURL)
                }
                rowDivider
                actionRow("Terms of Use") {
                    openURL(AppConfig.termsOfUseURL)
                }
                rowDivider
                actionRow("Contact Us") {
                    if let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                        openURL(url)
                    }
                }
                rowDivider

                Text("Daily Chengyu · Version \(AppConfig.appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.ink3)
                    .tracking(1)
                    .padding(.top, 26)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .alert("Notice", isPresented: messageBinding) {
            Button("OK") { store.message = nil }
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
                Text("My Subscription")
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
        guard state.isEntitled else { return "Not Subscribed · Subscribe" }
        if let date = state.entitlement?.expiresDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "MMM d, yyyy"
            return "Subscribed · Expires \(f.string(from: date))"
        }
        return "Subscribed"
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
