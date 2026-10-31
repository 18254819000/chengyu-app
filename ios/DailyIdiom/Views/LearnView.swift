import SwiftUI
import UIKit

/// 学习页（首页）：顶部字标栏（字标 + 四个同款圆形描边图标入口：测试 / 全部 / 分享 / 个人中心）+ 成语翻页区。
/// 按 UI 定稿：无标签、无个数、无进度、无切换按钮，翻页只靠左右滑。
/// 分享作用于当前显示的成语，渲染成语分享卡（英文版）走系统分享面板（原详情页内的分享按钮已删除，入口统一在此）。
struct LearnView: View {
    @EnvironmentObject var state: AppState

    @State private var shareItem: ShareItem?

    /// 首次安装滑动提示是否已看过：首次翻页（左滑/右滑）后置 true，此后不再出现。
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var hintNudge = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.isEntitled {
                streakBar
            }
            content
        }
        .background(Color.paperBg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            // 滑动提示只对订阅用户：免费用户不可滑动，教滑动等于引导用户去撞付费墙
            if state.isEntitled && !hasSeenSwipeHint && state.idioms.count > 1 {
                swipeHint
            }
        }
        .onAppear {
            state.refreshStreak()
        }
        .onChange(of: state.currentIndex) { _ in
            state.savePosition()
            // 翻到的成语计入已学（去重）；锁定页不计（免费用户点列表进锁定页不算学过）
            // 第一次翻页即视为已学会滑动，提示不再出现
            if let idiom = state.currentIdiom, !idiom.locked {
                LocalStore.recordLearned(id: idiom.id)
            }
            if !hasSeenSwipeHint {
                hasSeenSwipeHint = true
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
    }

    /// 首次安装滑动提示：不拦截手势（allowsHitTesting false），只在底部漂浮，
    /// 左右箭头来回轻移，翻页后自动消失。
    private var swipeHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.left")
                .foregroundColor(.accentRed)
            Text(L("Swipe to explore more idioms"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.ink)
            Image(systemName: "chevron.right")
                .foregroundColor(.accentRed)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.cardBg)
        .cornerRadius(999)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .offset(x: hintNudge ? 6 : -6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                hintNudge = true
            }
        }
        .allowsHitTesting(false)
        .padding(.bottom, 36)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("每日成语")
                .font(.system(size: 19, weight: .bold))
                .tracking(2)
                .foregroundColor(.ink)
            Spacer()
            HStack(spacing: 8) {
                // 测试图标：已订阅直接进测试页，未订阅先弹订阅页（订阅成功后接力进测试页）；
                // 实际导航由下面这个空标签链接承载（isActive 驱动）
                Button {
                    state.quizIconTapped()
                } label: {
                    TopBarIconLabel(systemName: "doc.text.magnifyingglass")
                }
                NavigationLink(destination: AllIdiomsView(), isActive: $state.showAllList) {
                    TopBarIconLabel(systemName: "list.bullet")
                }
                Button {
                    shareCurrentIdiom()
                } label: {
                    TopBarIconLabel(systemName: "square.and.arrow.up", isEnabled: canShareCurrent)
                }
                .disabled(!canShareCurrent)
                NavigationLink(destination: settingsDestination, isActive: $state.showSettings) {
                    TopBarIconLabel(systemName: "person.crop.circle")
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
        // 空标签链接（isActive 驱动）放 background：不占布局，避免 HStack 间距
        // 把空视图也算一个间距，导致第一个按钮和第二个按钮间距翻倍。
        .background {
            Group {
                NavigationLink(destination: QuizView(), isActive: $state.showQuiz) {
                    EmptyView()
                }
                // 小组件引导页：首次安装小组件提示的主按钮驱动（空标签链接，isActive 驱动）
                NavigationLink(destination: WidgetGuideView(), isActive: $state.showWidgetGuide) {
                    EmptyView()
                }
            }
        }
    }

    /// 打卡 pill（设计稿样式：浅红底、朱红字、胶囊形、左对齐，顶栏下方 16pt 间距）：
    /// 只显示火焰 + 连续天数；不显示 Checked in 标签——打开 App 即算打卡，该状态恒为已完成，无信息量。
    /// 点击进入个人中心（内含日历入口）。
    private var streakBar: some View {
        Button {
            state.showSettings = true
        } label: {
            HStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 14))
                Text(state.streakDays > 0 ? String(format: L("%d-day streak"), state.streakDays) : L("Start your streak today"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentRed)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.accentSoft)
            .cornerRadius(999)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 个人中心页（设置内容复用 SettingsView），推入时带系统导航栏与标题
    private var settingsDestination: some View {
        SettingsView()
            .navigationTitle(L("Profile"))
            .navigationBarTitleDisplayMode(.inline)
    }

    /// 分享对象：订阅用户分享当前页；免费用户分享当日成语（首页只显示当日成语，
    /// currentIndex 可能被列表点击带偏到锁定页，不能拿它当分享对象）
    private var sharedIdiom: Idiom? {
        if state.isEntitled { return state.currentIdiom }
        return state.todayIdiom ?? state.currentIdiom
    }

    /// 当前成语可分享的条件：未锁定且释义齐全（锁定条目后端不下发释义，生成不了完整卡片）
    private var canShareCurrent: Bool {
        guard let idiom = sharedIdiom, !idiom.locked else { return false }
        return !(idiom.definitionZh ?? "").isEmpty && !(idiom.definitionEn ?? "").isEmpty
    }

    /// 点击时才渲染分享卡（1080×1350），生成成功才以 item 驱动面板（见 ShareItem 注释）
    private func shareCurrentIdiom() {
        guard let idiom = sharedIdiom, canShareCurrent else { return }
        if let image = ShareCardRenderer.render(IdiomShareCard(idiom: idiom)) {
            shareItem = ShareItem(image: image)
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.idioms.isEmpty {
            emptyState
        } else if state.isEntitled {
            PagerView(pageCount: state.idioms.count, currentIndex: $state.currentIndex) { index in
                IdiomPageView(idiom: state.idioms[index])
            }
        } else {
            freePage
        }
    }

    /// 免费用户首页：只有当日成语一页，不可翻页；横向滑动手势弹订阅页（纵向滚动不受影响，
    /// simultaneousGesture + 方向判定：只响应横向主导、位移 > 50pt 的滑动）
    @ViewBuilder
    private var freePage: some View {
        if let idiom = state.todayIdiom ?? state.currentIdiom {
            if (idiom.definitionZh ?? "").isEmpty {
                if state.isSyncing {
                    // 同步进行中：先给加载态
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        Text(L("Loading today's idiom…"))
                            .font(.system(size: 14))
                            .foregroundColor(.ink3)
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    // 同步已结束仍无内容（离线跨天、昨日缓存无释义）：给带重试的占位，
                    // 绝不能无限 loading——此前版本在这里同步成功但 syncError 为 nil 时会卡死
                    offlineTodayState
                }
            } else {
                IdiomPageView(idiom: idiom)
                    .onAppear {
                        LocalStore.recordLearned(id: idiom.id)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                if abs(dx) > 50 && abs(dx) > abs(dy) {
                                    state.showPaywall = true
                                }
                            }
                    )
            }
        }
    }

    /// 离线跨天占位：当日成语在缓存里无内容，联网同步后才能加载
    private var offlineTodayState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.ink3)
            Text(L("Today's idiom isn't available offline yet"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.ink)
            Text(L("Connect to the internet and reopen the app to load today's free idiom."))
                .font(.system(size: 13.5))
                .foregroundColor(.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            Button(L("Retry")) {
                Task { await state.sync() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.accentRed)
            .padding(.horizontal, 26)
            .padding(.vertical, 9)
            .overlay(
                Capsule().stroke(Color.line, lineWidth: 1)
            )
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            if state.isSyncing {
                ProgressView()
                Text(L("Loading idioms…"))
                    .font(.system(size: 14))
                    .foregroundColor(.ink3)
            } else {
                Text(state.syncError ?? L("No content yet"))
                    .font(.system(size: 15))
                    .foregroundColor(.ink2)
                    .multilineTextAlignment(.center)
                Button(L("Retry")) {
                    Task { await state.sync() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentRed)
                .padding(.horizontal, 26)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().stroke(Color.line, lineWidth: 1)
                )
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
