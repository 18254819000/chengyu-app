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
            content
        }
        .background(Color.paperBg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if !hasSeenSwipeHint && state.idioms.count > 1 {
                swipeHint
            }
        }
        .onChange(of: state.currentIndex) { _ in
            state.savePosition()
            // 第一次翻页即视为已学会滑动，提示不再出现
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
            Text("Swipe to explore more idioms")
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
                NavigationLink(destination: QuizView(), isActive: $state.showQuiz) {
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
    }

    /// 个人中心页（设置内容复用 SettingsView），推入时带系统导航栏与标题
    private var settingsDestination: some View {
        SettingsView()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
    }

    /// 当前成语可分享的条件：未锁定且释义齐全（锁定条目后端不下发释义，生成不了完整卡片）
    private var canShareCurrent: Bool {
        guard let idiom = state.currentIdiom, !idiom.locked else { return false }
        return !(idiom.definitionZh ?? "").isEmpty && !(idiom.definitionEn ?? "").isEmpty
    }

    /// 点击时才渲染分享卡（1080×1350），生成成功才以 item 驱动面板（见 ShareItem 注释）
    private func shareCurrentIdiom() {
        guard let idiom = state.currentIdiom, canShareCurrent else { return }
        if let image = ShareCardRenderer.render(IdiomShareCard(idiom: idiom)) {
            shareItem = ShareItem(image: image)
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.idioms.isEmpty {
            emptyState
        } else {
            PagerView(pageCount: state.idioms.count, currentIndex: $state.currentIndex) { index in
                IdiomPageView(idiom: state.idioms[index])
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            if state.isSyncing {
                ProgressView()
                Text("Loading idioms…")
                    .font(.system(size: 14))
                    .foregroundColor(.ink3)
            } else {
                Text(state.syncError ?? "No content yet")
                    .font(.system(size: 15))
                    .foregroundColor(.ink2)
                    .multilineTextAlignment(.center)
                Button("Retry") {
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
