import SwiftUI

/// 应用介绍页：由个人中心（SettingsView）的「About Daily Chengyu」入口推入。
/// 顶部 Logo + 应用名 + 版本号，中段四段介绍（含图标故事），底部联系邮箱。
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 110 * 0.22))
                    .padding(.top, 28)

                Text("Daily Chengyu")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.ink)
                    .padding(.top, 16)

                Text("Version \(AppConfig.appVersion)")
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Daily Chengyu brings you one Chinese idiom (chengyu) every day. Each idiom comes with character-by-character pinyin, meanings in English and Chinese, and a bilingual example sentence.")
                    Text("Test yourself with three levels of quizzes, from everyday meanings to fill-in-the-blank challenges, and share beautiful idiom cards with friends.")
                    Text("Our logo tells the story of The Old Man Who Moved the Mountains (愚公移山): a tiny figure, a huge mountain, and progress made one basket at a time. That is exactly how we hope you learn — one idiom a day, every day.")
                    Text("New idioms are added regularly. The first 20 are free; a subscription unlocks the full collection.")
                }
                .font(.system(size: 14.5))
                .foregroundColor(.ink2)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)

                Text("Questions or feedback: \(AppConfig.supportEmail)")
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
