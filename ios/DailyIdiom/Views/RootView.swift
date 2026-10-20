import SwiftUI

/// 主结构：无底部栏。首页（学习页）为导航根页面，「全部」列表与个人中心由首页
/// 右上角两个入口以 NavigationLink 推入（激活状态在 AppState 里，弹窗/深链接可驱动）。
/// 本层承载新增提醒卡（设计方案 A「内容预览卡」，ZStack 覆盖层呈现）、订阅页 Sheet 与深链接处理。
struct RootView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    /// 应用内欢迎页（SplashView）是否呈现：冷启动时为 true，约 1.6 秒后由定时器置 false 淡出。
    /// 只在本视图首次出现时调度一次，从后台切回前台不会重新出现。
    @State private var showSplash = true

    /// 本批新增成语的预览条目：从新成语 id 集合中按全量列表的现有顺序取前 3 条，
    /// 在全量列表里查不到的（已下架等）自动跳过；结果为空表示这次不该弹卡。
    private var newIdiomPreview: [Idiom] {
        Array(state.idioms.filter { state.newIdiomIds.contains($0.id) }.prefix(3))
    }

    /// 提醒卡是否呈现：沿用原触发开关 showNewIdiomsAlert，另加「预览不为空」的兜底，
    /// 保证新增数为 0 或新成语全部查不到时绝不出现空卡。
    private var showNewIdiomsCard: Bool {
        state.showNewIdiomsAlert && !newIdiomPreview.isEmpty
    }

    var body: some View {
        ZStack {
            NavigationView {
                LearnView()
                    // 首页用自定义顶栏（字标 + 日期 + 两个入口），隐藏系统导航栏
                    .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .accentColor(.accentRed)
            .background(Color.paperBg)

            if showNewIdiomsCard {
                NewIdiomsCardView(
                    totalCount: state.pendingNewCount,
                    preview: newIdiomPreview,
                    onTakeALook: {
                        // 关闭即视为本批已提醒（去重靠同步时的版本号推进，这里只复位呈现开关）
                        state.showNewIdiomsAlert = false
                        state.showAllList = true
                    },
                    onLater: {
                        state.showNewIdiomsAlert = false
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.28), value: showNewIdiomsCard)
        .animation(.easeOut(duration: 0.45), value: showSplash)
        .onAppear {
            // 欢迎页只在冷启动呈现：固定约 1.6 秒后淡出，不等首次同步，
            // 因此同步再慢也不会把欢迎页拖过约 2.4 秒。guard 保证即便
            // onAppear 再次触发也不会重新调度（消失后本层不再出现）。
            guard showSplash else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                showSplash = false
            }
        }
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
        .sheet(isPresented: $state.showPaywall) {
            PaywallView()
        }
    }
}

/// 新增成语提醒卡（设计稿方案 A「内容预览卡」）：半透明遮罩 + 居中纸面卡。
/// 遮罩不响应点击，只能用卡上的两个按钮关闭，避免误触把提醒弄丢。
private struct NewIdiomsCardView: View {
    /// 本批新增总数（副文案与「+ N more」用）
    let totalCount: Int
    /// 预览条目（最多 3 条，已按全量列表顺序排好）
    let preview: [Idiom]
    let onTakeALook: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            Color.ink.opacity(0.38)
                .ignoresSafeArea()

            card
                .padding(.horizontal, 26)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标签行：朱红小方印「新」+ NEW ARRIVALS
            HStack(spacing: 9) {
                Text("新")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 27, height: 27)
                    .background(Color.accentRed)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("NEW ARRIVALS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(.accentRed)
            }

            Text("New Idioms Are Here")
                .font(.system(size: 20.5, weight: .bold))
                .foregroundColor(.ink)
                .padding(.top, 14)

            Text("\(totalCount) new idioms have been added to your collection. Come and meet them.")
                .font(.system(size: 13.5))
                .foregroundColor(.ink2)
                .lineSpacing(5)
                .padding(.top, 7)

            // 新成语列表：最多 3 条，细线分隔（最后一行无线）
            VStack(spacing: 0) {
                ForEach(Array(preview.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.idiom)
                                .font(.system(size: 17, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.ink)
                            Text(item.pinyin)
                                .font(.system(size: 12.5, design: .serif))
                                .foregroundColor(.ink3)
                        }
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.9)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.accentRed)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.vertical, 11)

                    if index < preview.count - 1 {
                        Rectangle()
                            .fill(Color.line)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.top, 16)

            if totalCount > 3 {
                Text("+ \(totalCount - 3) more in All Idioms")
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
                    .padding(.top, 10)
            }

            Button(action: onTakeALook) {
                Text("Take a Look")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentRed)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .padding(.top, 22)

            Button(action: onLater) {
                Text("Later")
                    .font(.system(size: 14))
                    .foregroundColor(.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.top, 26)
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
        .background(Color.paperBg)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.30), radius: 30, x: 0, y: 12)
    }
}
