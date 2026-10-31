import SwiftUI

/// 应用内欢迎页：冷启动后由 RootView 的 ZStack 顶层短暂呈现（约 1.6 秒后淡出），
/// 与系统启动屏（UILaunchScreen 的底色 + AppLogo 图）衔接成一段完整的开场。
/// 纯展示，不承载任何业务逻辑；消失时机由 RootView 的定时器控制。
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.paperBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("AppLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 148 * 0.22))

                Text("Daily Chengyu")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.ink)
                    .padding(.top, 22)

                Text(L("One idiom a day, wisdom for a lifetime."))
                    .font(.system(size: 15))
                    .foregroundColor(.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 48)
                    .padding(.top, 10)

                Spacer()
            }
        }
    }
}
