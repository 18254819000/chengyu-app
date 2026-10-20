import SwiftUI

/// 学习页（首页）：顶部字标栏（字标 + 日期 + 「全部」与个人中心两个跳页入口）+ 成语翻页区。
/// 按 UI 定稿：无标签、无个数、无进度、无切换按钮，翻页只靠左右滑。
struct LearnView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.paperBg.ignoresSafeArea())
        .onChange(of: state.currentIndex) { _ in
            state.savePosition()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("每日成语")
                    .font(.system(size: 19, weight: .bold))
                    .tracking(2)
                Text("。")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.accentRed)
            }
            Spacer()
            Text(DateUtil.displayString(from: Date()))
                .font(.system(size: 12))
                .foregroundColor(.ink3)
            NavigationLink(destination: AllIdiomsView(), isActive: $state.showAllList) {
                Text("全部")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(.ink2)
                    .frame(height: 34)
                    .padding(.horizontal, 6)
            }
            .padding(.leading, 8)
            NavigationLink(destination: settingsDestination, isActive: $state.showSettings) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 19))
                    .foregroundColor(.ink2)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().stroke(Color.line, lineWidth: 1)
                    )
            }
            .padding(.leading, 6)
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
    }

    /// 个人中心页（设置内容复用 SettingsView），推入时带系统导航栏与标题
    private var settingsDestination: some View {
        SettingsView()
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
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
                Text("正在加载成语…")
                    .font(.system(size: 14))
                    .foregroundColor(.ink3)
            } else {
                Text(state.syncError ?? "暂无内容")
                    .font(.system(size: 15))
                    .foregroundColor(.ink2)
                    .multilineTextAlignment(.center)
                Button("重试") {
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
