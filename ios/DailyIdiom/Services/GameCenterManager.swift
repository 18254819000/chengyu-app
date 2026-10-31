import Foundation
import GameKit
import UIKit

/// Game Center 网关：认证、上报分数与成就、读取榜单与成就。
/// 榜单与成就 ID 必须与 App Store Connect 中创建的一致，否则上报失败（仅日志，不阻塞用户）。
/// 未登录时上报走本地缓存（分数与进度只增不减，登录后重试即不会丢）。
@MainActor
final class GameCenterManager: NSObject, ObservableObject, GKGameCenterControllerDelegate {

    // MARK: 榜单与成就 ID（与需求文档第 20 章一致）

    /// v1 不做成就（缺图标，ASC 成就必须配图）：入口与上报均关闭，只保留排行榜。
    /// 以后有图后改 true，并在 ASC 建 12 个成就即可恢复（本地进度一直在记，不会丢）。
    static let achievementsEnabled = false

    static let streakBoardID = "com.mengma.dailyidiom.lb.streak"
    static let checkinsBoardID = "com.mengma.dailyidiom.lb.checkins"
    static let quizBoardID = "com.mengma.dailyidiom.lb.quiz"

    struct AchievementDef: Identifiable {
        let key: String
        let title: String
        let desc: String
        var fullID: String { "com.mengma.dailyidiom.ach.\(key)" }
        var id: String { key }
    }

    static let achievementDefs: [AchievementDef] = [
        AchievementDef(key: "first_game", title: "First Game", desc: "Finish your first round"),
        AchievementDef(key: "sharp_eye", title: "Sharp Eye", desc: "10 correct in a row in Picture Guess"),
        AchievementDef(key: "perfect_round", title: "Perfect Round", desc: "A flawless 10/10 regular round"),
        AchievementDef(key: "marathon", title: "Marathon", desc: "25 correct in a row in Endless mode"),
        AchievementDef(key: "week_warrior", title: "Week Warrior", desc: "7-day check-in streak"),
        AchievementDef(key: "month_master", title: "Month Master", desc: "30-day check-in streak"),
        AchievementDef(key: "hundred_days", title: "Century Streak", desc: "100-day check-in streak"),
        AchievementDef(key: "century_scholar", title: "Century Scholar", desc: "Learn 100 idioms"),
        AchievementDef(key: "storyteller", title: "Storyteller", desc: "Read 20 idiom stories"),
        AchievementDef(key: "reviewer", title: "Diligent Reviewer", desc: "Complete 100 review judgments"),
        AchievementDef(key: "quiz_master", title: "Quiz Master", desc: "Full marks in all three quiz difficulties"),
        AchievementDef(key: "comeback", title: "Comeback", desc: "7-day streak after a broken streak"),
    ]

    // MARK: 状态

    @Published private(set) var isAuthenticated = false
    @Published private(set) var localPlayerName: String?

    private var authViewPresented = false

    // MARK: 认证

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let vc = vc, !self.authViewPresented {
                    self.authViewPresented = true
                    self.present(vc)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self.isAuthenticated = true
                    self.localPlayerName = GKLocalPlayer.local.displayName
                    self.flushPending()
                } else if let error = error {
                    print("[GameCenter] auth failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 用户在榜单页点「登录」时调用：允许再次弹出系统登录（认证弹窗只弹一次，拒绝后需手动重试）
    func retryAuthentication() {
        authViewPresented = false
        authenticate()
    }

    private func present(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(vc, animated: true)
    }

    // MARK: 上报（结算点调用，幂等：重复提交同一最好成绩无害）

    func submitScore(_ value: Int, board: String) {
        guard isAuthenticated else {
            LocalStore.cacheScore(board: board, value: value)
            return
        }
        GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board]) { error in
            if let error = error {
                print("[GameCenter] submitScore failed: \(error.localizedDescription)")
            }
        }
    }

    func reportAchievement(_ fullID: String, percent: Double) {
        guard Self.achievementsEnabled else { return }
        let p = min(100, max(0, percent))
        guard p > 0 else { return }
        guard isAuthenticated else {
            LocalStore.cacheAchievement(id: fullID, percent: p)
            return
        }
        var reported = LocalStore.reportedAchievements
        guard p > (reported[fullID] ?? 0) else { return }
        reported[fullID] = p
        LocalStore.reportedAchievements = reported
        let ach = GKAchievement(identifier: fullID)
        ach.percentComplete = p
        ach.showsCompletionBanner = true
        GKAchievement.report([ach]) { error in
            if let error = error {
                print("[GameCenter] reportAchievement failed: \(error.localizedDescription)")
            }
        }
    }

    /// 登录后把缓存的最高分与成就进度补上报（分数与进度只增不减，乐观清除安全）
    private func flushPending() {
        let scores = LocalStore.pendingScores
        if !scores.isEmpty {
            LocalStore.pendingScores = [:]
            for (board, value) in scores { submitScore(value, board: board) }
        }
        let achs = LocalStore.pendingAchievements
        if !achs.isEmpty {
            LocalStore.pendingAchievements = [:]
            for (id, percent) in achs { reportAchievement(id, percent: percent) }
        }
    }

    /// 一次性同步：榜单（连答最佳、累计打卡、测验最高分）+ 12 个成就进度。
    /// 由本地计数推导，调用点：游戏结算、打卡记账、故事打开、复习判定、回到前台。
    func syncProgress() {
        submitScore(LocalStore.pictureEndlessBest, board: Self.streakBoardID)
        submitScore(LocalStore.totalCheckInDays, board: Self.checkinsBoardID)
        submitScore(LocalStore.quizBestOverall, board: Self.quizBoardID)
        let streak = Double(LocalStore.currentStreak)
        let learned = Double(Set(LocalStore.learnedIdiomIds).count)
        let stories = Double(Set(LocalStore.storyReadIds).count)
        let gamesPlayed = LocalStore.quizRoundsTotal + LocalStore.pictureRoundsTotal
        let fullMarkDifficulties = ["easy", "medium", "hard"]
            .filter { LocalStore.quizBestScore(difficultyKey: $0) >= 100 }.count
        let progress: [(String, Double)] = [
            ("first_game", gamesPlayed > 0 ? 100 : 0),
            ("sharp_eye", min(100, Double(LocalStore.pictureBestStreak) / 10 * 100)),
            ("perfect_round", LocalStore.pictureRegularBest >= 10 ? 100 : 0),
            ("marathon", min(100, Double(LocalStore.pictureEndlessBest) / 25 * 100)),
            ("week_warrior", min(100, streak / 7 * 100)),
            ("month_master", min(100, streak / 30 * 100)),
            ("hundred_days", min(100, streak / 100 * 100)),
            ("century_scholar", min(100, learned / 100 * 100)),
            ("storyteller", min(100, stories / 20 * 100)),
            ("reviewer", min(100, Double(LocalStore.reviewActionsTotal) / 100 * 100)),
            ("quiz_master", Double(fullMarkDifficulties) / 3 * 100),
            ("comeback", LocalStore.hasHadStreakBreak ? min(100, streak / 7 * 100) : 0),
        ]
        for (key, percent) in progress {
            reportAchievement("com.mengma.dailyidiom.ach.\(key)", percent: percent)
        }
    }

    /// 成就页本地进度（与 syncProgress 同口径，未登录时也以此展示）
    static func localProgress(for key: String) -> Double {
        let streak = Double(LocalStore.currentStreak)
        switch key {
        case "first_game":
            return (LocalStore.quizRoundsTotal + LocalStore.pictureRoundsTotal) > 0 ? 100 : 0
        case "sharp_eye":
            return min(100, Double(LocalStore.pictureBestStreak) / 10 * 100)
        case "perfect_round":
            return LocalStore.pictureRegularBest >= 10 ? 100 : 0
        case "marathon":
            return min(100, Double(LocalStore.pictureEndlessBest) / 25 * 100)
        case "week_warrior":
            return min(100, streak / 7 * 100)
        case "month_master":
            return min(100, streak / 30 * 100)
        case "hundred_days":
            return min(100, streak / 100 * 100)
        case "century_scholar":
            return min(100, Double(Set(LocalStore.learnedIdiomIds).count) / 100 * 100)
        case "storyteller":
            return min(100, Double(Set(LocalStore.storyReadIds).count) / 20 * 100)
        case "reviewer":
            return min(100, Double(LocalStore.reviewActionsTotal) / 100 * 100)
        case "quiz_master":
            let full = ["easy", "medium", "hard"]
                .filter { LocalStore.quizBestScore(difficultyKey: $0) >= 100 }.count
            return Double(full) / 3 * 100
        case "comeback":
            return LocalStore.hasHadStreakBreak ? min(100, streak / 7 * 100) : 0
        default:
            return 0
        }
    }

    // MARK: 读取榜单与成就

    struct LeaderboardEntry: Identifiable {
        let id: String
        let rank: Int
        let name: String
        let score: Int
        let isLocalPlayer: Bool
    }

    struct LeaderboardResult {
        let entries: [LeaderboardEntry]
        let localEntry: LeaderboardEntry?
        let totalCount: Int
    }

    func loadLeaderboard(board: String, timeScope: GKLeaderboard.TimeScope) async -> LeaderboardResult? {
        guard isAuthenticated else { return nil }
        return await withCheckedContinuation { continuation in
            GKLeaderboard.loadLeaderboards(IDs: [board]) { boards, error in
                guard let board = boards?.first, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                board.loadEntries(for: .global, timeScope: timeScope, range: NSRange(location: 1, length: 25)) { local, entries, total, error in
                    guard error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let localID = GKLocalPlayer.local.gamePlayerID
                    let mapped = (entries ?? []).map { e in
                        LeaderboardEntry(id: e.player.gamePlayerID, rank: e.rank, name: e.player.displayName, score: e.score, isLocalPlayer: e.player.gamePlayerID == localID)
                    }
                    let localMapped = local.map { e in
                        LeaderboardEntry(id: e.player.gamePlayerID, rank: e.rank, name: e.player.displayName, score: e.score, isLocalPlayer: true)
                    }
                    continuation.resume(returning: LeaderboardResult(entries: mapped, localEntry: localMapped, totalCount: total))
                }
            }
        }
    }

    // MARK: 系统面板（次要入口）

    func presentGameCenter(state: GKGameCenterViewControllerState) {
        let vc = GKGameCenterViewController()
        vc.viewState = state
        vc.gameCenterDelegate = self
        present(vc)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
