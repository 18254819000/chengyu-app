import SwiftUI

/// 主结构：无底部栏。首页（学习页）为导航根页面，「全部」列表与个人中心由首页
/// 右上角两个入口以 NavigationLink 推入（激活状态在 AppState 里，弹窗/深链接可驱动）。
/// 本层承载新增提醒弹窗、订阅页 Sheet 与深链接处理。
struct RootView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationView {
            LearnView()
                // 首页用自定义顶栏（字标 + 日期 + 两个入口），隐藏系统导航栏
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(.accentRed)
        .background(Color.paperBg)
        .task {
            await state.bootstrap()
        }
        .onOpenURL { url in
            state.handle(url: url)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await state.refreshOnForeground() }
            }
        }
        .alert("新增成语", isPresented: $state.showNewIdiomsAlert) {
            Button("去看看") {
                state.showAllList = true
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text("新增了 \(state.pendingNewCount) 个成语，快来学习吧")
        }
        .sheet(isPresented: $state.showPaywall) {
            PaywallView()
        }
    }
}
