import SwiftUI

/// 主结构：学习 / 全部 / 我的三 Tab，承载新增提醒弹窗、订阅页与设置页 Sheet、深链接。
struct RootView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $state.selectedTab) {
            LearnView()
                .tabItem { Label("学习", systemImage: "book") }
                .tag(AppState.Tab.learn)

            AllIdiomsView()
                .tabItem { Label("全部", systemImage: "list.bullet") }
                .tag(AppState.Tab.all)

            NavigationView {
                SettingsView()
                    .navigationTitle("我的")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("我的", systemImage: "person") }
            .tag(AppState.Tab.mine)
        }
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
                state.selectedTab = .all
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text("新增了 \(state.pendingNewCount) 个成语，快来学习吧")
        }
        .sheet(isPresented: $state.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $state.showSettings) {
            SettingsSheetView()
        }
    }
}
