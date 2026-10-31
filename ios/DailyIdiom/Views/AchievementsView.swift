import SwiftUI

/// 成就页（App 内展示，进度与 GameCenterManager 同口径）：
/// 已解锁盖朱红印，未解锁带进度条；成就可选，排行榜可独立存在。
struct AchievementsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                let unlocked = GameCenterManager.achievementDefs.filter {
                    GameCenterManager.localProgress(for: $0.key) >= 100
                }.count
                Text(String(format: L("%d of %d unlocked"), unlocked, GameCenterManager.achievementDefs.count))
                    .font(.system(size: 13))
                    .foregroundColor(.ink2)
                    .padding(.top, 16)

                ForEach(GameCenterManager.achievementDefs) { def in
                    achievementRow(def)
                    Divider()
                }

                Text(L("Achievements sync with Game Center and follow your Apple ID across devices. Progress is tracked locally first, so it never gets lost when offline."))
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
                    .lineSpacing(4)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 30)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle(L("Achievements"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func achievementRow(_ def: GameCenterManager.AchievementDef) -> some View {
        let progress = GameCenterManager.localProgress(for: def.key)
        let unlocked = progress >= 100
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.accentRed : Color.cardBg)
                    .frame(width: 42, height: 42)
                Text(unlocked ? "✓" : "🔒")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(unlocked ? .white : .ink3)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L(def.title))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.ink)
                Text(L(def.desc))
                    .font(.system(size: 13))
                    .foregroundColor(.ink2)
                if !unlocked {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.line)
                                .frame(height: 5)
                            Rectangle()
                                .fill(Color.accentRed)
                                .frame(width: geo.size.width * CGFloat(progress / 100), height: 5)
                        }
                    }
                    .frame(height: 5)
                    .padding(.top, 4)
                    Text("\(Int(progress))%")
                        .font(.system(size: 12))
                        .foregroundColor(.ink3)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }
}
