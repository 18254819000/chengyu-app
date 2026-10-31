import SwiftUI
import StoreKit

/// 个人中心内容：由首页右上角个人中心入口以 NavigationLink 推入本页。
/// 调用方（LearnView 的导航目标）负责设置导航标题。
/// 布局仿 iOS 系统设置：InsetGroupedListStyle 分组列表，按功能分 4 个 section。
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: StoreManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section(header: Text(L("SUBSCRIPTION"))) {
                subscriptionRow
                actionRow(icon: "arrow.clockwise", iconColor: .gray, "Restore Purchases", trailing: store.isRestoring ? "Restoring…" : nil) {
                    Task { await store.restorePurchases() }
                }
                actionRow(icon: "creditcard.fill", iconColor: .blue, "Manage Subscription") {
                    openManageSubscriptions()
                }
                actionRow(icon: "gift.fill", iconColor: .purple, "Redeem Code") {
                    SKPaymentQueue.default().presentCodeRedemptionSheet()
                }
            }
            // 学习功能只对订阅用户：免费用户没有打卡、日历、复习、排行榜、成就，整个 section 隐藏
            if state.isEntitled {
                Section(header: Text(L("LEARNING"))) {
                NavigationLink {
                    CheckInCalendarView()
                } label: {
                    rowContent(icon: "flame.fill", iconColor: .orange, title: L("Check-in Calendar"), trailing: state.streakDays > 0 ? String(format: L("%d days"), state.streakDays) : nil)
                }
                NavigationLink {
                    ReviewView()
                } label: {
                    rowContent(icon: "book.fill", iconColor: .green, title: L("Review"), trailing: nil)
                }
                NavigationLink {
                    LeaderboardView()
                } label: {
                    rowContent(icon: "trophy.fill", iconColor: .yellow, title: L("Leaderboard"), trailing: nil)
                }
                if GameCenterManager.achievementsEnabled {
                    NavigationLink {
                        AchievementsView()
                    } label: {
                        rowContent(icon: "crown.fill", iconColor: .indigo, title: L("Achievements"), trailing: nil)
                    }
                }
                }
            }
            Section(header: Text(L("HOME SCREEN"))) {
                NavigationLink {
                    WidgetGuideView()
                } label: {
                    rowContent(icon: "square.grid.2x2.fill", iconColor: .teal, title: L("Add Widget to Home Screen"), trailing: nil)
                }
            }
            Section(header: Text(L("ABOUT")), footer: Text(String(format: L("Daily-Chengyu · Version %@"), AppConfig.appVersion))) {
                actionRow(icon: "lock.fill", iconColor: .blue, L("Privacy Policy")) {
                    state.openWeb(AppConfig.privacyPolicyURL)
                }
                actionRow(icon: "doc.text.fill", iconColor: .gray, L("Terms of Use")) {
                    state.openWeb(AppConfig.termsOfUseURL)
                }
                actionRow(icon: "envelope.fill", iconColor: .pink, L("Contact Us")) {
                    if let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                        openURL(url)
                    }
                }
                NavigationLink {
                    AboutView()
                } label: {
                    rowContent(icon: "info.circle.fill", iconColor: .gray, title: L("About Daily-Chengyu"), trailing: nil)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .appDialog(
            isPresented: messageBinding,
            title: L("Notice"),
            message: store.message ?? "",
            primaryTitle: L("OK"),
            primaryAction: { store.message = nil }
        )
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
            HStack(spacing: 12) {
                iconView("star.fill", color: .accentRed)
                Text(L("My Subscription"))
                    .font(.system(size: 17))
                    .foregroundColor(.ink)
                Spacer()
                Text(subscriptionStatusText)
                    .font(.system(size: 15))
                    .foregroundColor(state.isEntitled ? .ink3 : .accentRed)
                    .fontWeight(state.isEntitled ? .regular : .semibold)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    private var subscriptionStatusText: String {
        guard state.isEntitled else { return L("Not Subscribed · Subscribe") }
        if let date = state.entitlement?.expiresDate {
            let f = DateFormatter()
            f.locale = AppLanguage.displayLocale
            f.dateFormat = "MMM d, yyyy"
            return String(format: L("Subscribed · Expires %@"), f.string(from: date))
        }
        return L("Subscribed")
    }

    // MARK: 通用行（iOS 设置风格：彩色圆角图标 + 标题 + 右侧值 + 箭头）

    private func actionRow(icon: String, iconColor: Color, _ title: String, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                rowContent(icon: icon, iconColor: iconColor, title: title, trailing: trailing)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    private func rowContent(icon: String, iconColor: Color, title: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            iconView(icon, color: iconColor)
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.ink)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 17))
                    .foregroundColor(.ink3)
                    .lineLimit(1)
            }
        }
    }

    private func iconView(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(7)
    }

    private func openManageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(url)
        }
    }
}
