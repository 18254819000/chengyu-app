import SwiftUI

/// 复习页：错题本（测验 + 看图猜答错自动进入）+ 待复习队列（错题优先，1 / 3 / 7 天轮换）。
/// 复习判定「掌握了」推进间隔（3 天 → 7 天 → 清除），「还没掌握」次日再出现；一次判定即计入学习动作。
struct ReviewView: View {
    @EnvironmentObject var state: AppState

    @State private var dueIds: [Int] = []
    @State private var sessionIndex = 0
    @State private var inSession = false
    @State private var revealed = false
    @State private var sessionGotIt = 0

    private var today: String { LocalStore.dayString() }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if inSession {
                    sessionView
                } else {
                    overviewView
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle(L("Review"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
    }

    // MARK: 总览

    private var overviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("Due today"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.ink)
                    Spacer()
                    Text(String(format: L("%d idioms"), dueIds.count))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentRed)
                }
                Text(L("Mistakes first, then due reviews · 1 / 3 / 7-day rotation"))
                    .font(.system(size: 13))
                    .foregroundColor(.ink2)
                Button {
                    guard !dueIds.isEmpty else { return }
                    sessionIndex = 0
                    sessionGotIt = 0
                    revealed = false
                    inSession = true
                } label: {
                    Text(dueIds.isEmpty ? L("Nothing Due Today 🎉") : L("Start Review"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(dueIds.isEmpty ? Color.cardBg : Color.accentRed)
                        .foregroundColor(dueIds.isEmpty ? .ink2 : .white)
                        .cornerRadius(999)
                }
                .disabled(dueIds.isEmpty)
                .padding(.top, 12)
            }
            .padding(18)
            .background(Color.cardBg)
            .cornerRadius(16)

            Text(String(format: L("Mistake book (%d)"), mistakes.count))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.ink)
                .padding(.top, 26)
                .padding(.bottom, 6)
            if mistakes.isEmpty {
                Text(L("No mistakes yet — keep playing and anything you miss will land here."))
                    .font(.system(size: 13))
                    .foregroundColor(.ink3)
                    .lineSpacing(4)
            } else {
                ForEach(mistakes, id: \.id) { item in
                    NavigationLink(destination: IdiomDetailPushView(idiom: item.idiom)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.idiom.idiom)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.ink)
                                Text(String(format: L("Missed %d× · last missed %@"), item.info.wrongCount, item.info.lastWrong))
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.ink3)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.ink3)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    Divider()
                }
            }

            Text(L("How review works: see the idiom → recall it → tap to reveal the meaning → “Got it” moves it to a later round, “Still learning” brings it back tomorrow."))
                .font(.system(size: 12.5))
                .foregroundColor(.ink3)
                .lineSpacing(4)
                .padding(.top, 20)
        }
    }

    private var mistakes: [(id: Int, idiom: Idiom, info: LocalStore.MistakeInfo)] {
        LocalStore.mistakeBook().compactMap { (id, info) in
            guard let idiom = state.idioms.first(where: { $0.id == id }) else { return nil }
            return (id: id, idiom: idiom, info: info)
        }.sorted {
            if $0.info.wrongCount != $1.info.wrongCount { return $0.info.wrongCount > $1.info.wrongCount }
            return $0.info.lastWrong > $1.info.lastWrong
        }
    }

    // MARK: 复习会话

    @ViewBuilder
    private var sessionView: some View {
        if sessionIndex < dueIds.count,
           let idiom = state.idioms.first(where: { $0.id == dueIds[sessionIndex] }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(String(format: L("Review %d/%d"), sessionIndex + 1, dueIds.count))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.ink3)
                    Spacer()
                    Button(L("End")) {
                        inSession = false
                        refresh()
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.ink3)
                }

                Text(idiom.idiom)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.ink)
                    .padding(.top, 30)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(idiom.pinyin)
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.ink2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                if revealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(idiom.definitionZh ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .lineSpacing(6)
                        Text(idiom.definitionEn ?? "")
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(.ink2)
                            .lineSpacing(5)
                    }
                    .padding(.top, 26)

                    HStack(spacing: 12) {
                        Button {
                            judge(gotIt: false, idiom: idiom)
                        } label: {
                            Text(L("Still Learning"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accentRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .overlay(Capsule().stroke(Color.accentRed, lineWidth: 1))
                        }
                        Button {
                            judge(gotIt: true, idiom: idiom)
                        } label: {
                            Text(L("Got It"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.accentRed)
                                .cornerRadius(999)
                        }
                    }
                    .padding(.top, 30)
                } else {
                    Button {
                        revealed = true
                    } label: {
                        Text(L("Reveal Meaning"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.accentRed)
                            .cornerRadius(999)
                    }
                    .padding(.top, 30)
                }
            }
        } else {
            VStack(spacing: 12) {
                Text(L("Review Complete 🎉"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.ink)
                    .padding(.top, 40)
                Text(String(format: L("%d of %d mastered this round"), sessionGotIt, dueIds.count))
                    .font(.system(size: 14))
                    .foregroundColor(.ink2)
                Button {
                    inSession = false
                    refresh()
                } label: {
                    Text(L("Back to Review"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accentRed)
                        .cornerRadius(999)
                }
                .padding(.top, 20)
            }
        }
    }

    private func judge(gotIt: Bool, idiom: Idiom) {
        LocalStore.applyReviewResult(id: idiom.id, gotIt: gotIt)
        if gotIt { sessionGotIt += 1 }
        state.gameCenter.syncProgress()
        state.refreshStreak()
        sessionIndex += 1
        revealed = false
        if sessionIndex >= dueIds.count {
            // 会话结束留在完成页（sessionView 的 else 分支），不立即切回总览
        }
    }

    private func refresh() {
        dueIds = LocalStore.dueReviewIds(today: today)
            .filter { id in state.idioms.contains(where: { $0.id == id }) }
    }
}

/// 错题本行内跳转详情：复用详情页（不经过翻页器）
private struct IdiomDetailPushView: View {
    let idiom: Idiom

    var body: some View {
        IdiomPageView(idiom: idiom)
            .navigationTitle(L("Idiom"))
            .navigationBarTitleDisplayMode(.inline)
    }
}
