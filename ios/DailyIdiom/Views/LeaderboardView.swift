import SwiftUI
import GameKit

/// 排行榜（App 内原生展示，Game Center 数据）：3 个全球榜 + 本周/全部时间筛选。
/// 未登录 Game Center 时显示本地最好成绩并给登录入口；榜单不与订阅状态挂钩。
struct LeaderboardView: View {
    @EnvironmentObject var state: AppState

    private enum Board: String, CaseIterable, Identifiable {
        case streak
        case checkins
        case quiz

        var id: String { rawValue }

        var title: String {
            switch self {
            case .streak: return "Longest streak"
            case .checkins: return "Check-in days"
            case .quiz: return "Quiz best"
            }
        }

        var boardID: String {
            switch self {
            case .streak: return GameCenterManager.streakBoardID
            case .checkins: return GameCenterManager.checkinsBoardID
            case .quiz: return GameCenterManager.quizBoardID
            }
        }

        var sortNote: String {
            switch self {
            case .streak: return "Sorted by longest endless streak, highest first"
            case .checkins: return "Sorted by total check-in days, highest first"
            case .quiz: return "Sorted by best single-round quiz score, highest first"
            }
        }

        /// 未登录时的本地最好成绩
        var localBest: Int {
            switch self {
            case .streak: return LocalStore.pictureEndlessBest
            case .checkins: return LocalStore.totalCheckInDays
            case .quiz: return LocalStore.quizBestOverall
            }
        }
    }

    @State private var board: Board = .streak
    @State private var timeScope: GKLeaderboard.TimeScope = .allTime
    @State private var result: GameCenterManager.LeaderboardResult?
    @State private var isLoading = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                boardTabs
                timeToggle
                Text(board.sortNote + " · ties go to whoever reached it first · your best score only")
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
                    .padding(.top, 10)

                if !state.gameCenter.isAuthenticated {
                    unauthenticatedBlock
                } else if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                } else if let result = result, !result.entries.isEmpty {
                    leaderboardList(result)
                } else {
                    Text("No scores yet — be the first on this board!")
                        .font(.system(size: 14))
                        .foregroundColor(.ink2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }

                Button {
                    state.gameCenter.presentGameCenter(state: .leaderboards)
                } label: {
                    Text("View in Game Center ↗")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(.ink2)
                        .padding(.vertical, 10)
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: board) { await load() }
        .task(id: timeScope) { await load() }
    }

    // MARK: 榜单切换

    private var boardTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Board.allCases) { b in
                    Button {
                        board = b
                    } label: {
                        Text(b.title)
                            .font(.system(size: 13.5, weight: board == b ? .semibold : .regular))
                            .foregroundColor(board == b ? .white : .ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(board == b ? Color.accentRed : Color.cardBg)
                            .cornerRadius(999)
                    }
                }
            }
        }
    }

    private var timeToggle: some View {
        HStack(spacing: 8) {
            timeButton("All time", scope: .allTime)
            timeButton("This week", scope: .week)
        }
        .padding(.top, 12)
    }

    private func timeButton(_ title: String, scope: GKLeaderboard.TimeScope) -> some View {
        Button {
            timeScope = scope
        } label: {
            Text(title)
                .font(.system(size: 13, weight: timeScope == scope ? .semibold : .regular))
                .foregroundColor(timeScope == scope ? .accentRed : .ink2)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(timeScope == scope ? Color.accentSoft : Color.cardBg)
                .cornerRadius(999)
        }
    }

    // MARK: 列表

    private func leaderboardList(_ result: GameCenterManager.LeaderboardResult) -> some View {
        VStack(spacing: 0) {
            ForEach(result.entries) { entry in
                rankRow(entry)
                Divider()
            }
            if let local = result.localEntry,
               !result.entries.contains(where: { $0.id == local.id }) {
                HStack {
                    Text("…")
                        .font(.system(size: 13))
                        .foregroundColor(.ink3)
                }
                .padding(.vertical, 8)
                rankRow(local, highlighted: true)
            }
            Text("\(result.totalCount) players on this board")
                .font(.system(size: 12.5))
                .foregroundColor(.ink3)
                .padding(.top, 14)
        }
        .padding(.top, 10)
    }

    private func rankRow(_ entry: GameCenterManager.LeaderboardEntry, highlighted: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.rank)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(entry.rank <= 3 ? .accentRed : .ink3)
                .frame(width: 28, alignment: .center)
            Text(entry.name)
                .font(.system(size: 15, weight: entry.isLocalPlayer ? .semibold : .regular))
                .foregroundColor(.ink)
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.ink)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, highlighted ? 10 : 0)
        .background(highlighted ? Color.accentSoft : Color.clear)
        .cornerRadius(10)
    }

    private var unauthenticatedBlock: some View {
        VStack(spacing: 0) {
            Text("Your best on this board: \(board.localBest)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.ink)
                .padding(.top, 30)
            Text("Sign in to Game Center to see the global leaderboard and rank against other players.")
                .font(.system(size: 13))
                .foregroundColor(.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Button {
                state.gameCenter.retryAuthentication()
            } label: {
                Text("Sign in to Game Center")
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

    private func load() async {
        guard state.gameCenter.isAuthenticated else { return }
        isLoading = true
        result = await state.gameCenter.loadLeaderboard(board: board.boardID, timeScope: timeScope)
        isLoading = false
    }
}
