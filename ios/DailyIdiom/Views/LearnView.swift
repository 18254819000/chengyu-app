import SwiftUI

/// 学习页：顶部字标栏（字标 + 日期 + 齿轮设置入口）+ 成语翻页区。
/// 按 UI 定稿：无标签、无个数、无进度、无切换按钮，切换只靠左右滑。
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
            Button {
                state.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundColor(.ink2)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().stroke(Color.line, lineWidth: 1)
                    )
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
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
