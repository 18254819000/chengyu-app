import Foundation
import WidgetKit

/// 全局状态与同步流程：
/// 启动先读缓存渲染 -> 拉 /config 比对 content_version -> 变化才拉全量 -> 写缓存与 App Group 共享存储 -> 刷新小组件。
@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfigResponse?
    @Published var idioms: [Idiom] = []
    @Published var entitlement: EntitlementStatus?
    @Published var isSyncing = false
    /// 同步失败提示（有缓存时仅弱提示，无缓存时页面给重试入口）
    @Published var syncError: String?
    @Published var currentIndex: Int = 0
    /// 首页右上角「全部」入口 NavigationLink 的激活状态（true = 列表页已推入）
    @Published var showAllList = false
    @Published var showPaywall = false
    /// 首页右上角个人中心入口 NavigationLink 的激活状态（true = 个人中心已推入）
    @Published var showSettings = false
    /// 首页右上角「测试」入口 NavigationLink 的激活状态（true = 测试页已推入）
    @Published var showQuiz = false
    @Published var newIdiomIds: Set<Int> = []
    @Published var pendingNewCount: Int = 0
    @Published var showNewIdiomsAlert = false

    let store = StoreManager()
    let api = APIClient()

    private var didBootstrap = false
    /// 每天首次打开需落在当日每日成语：缓存阶段先按「同日恢复位置」占位，同步拿到 daily 后再纠正
    private var needsDailyPositioning = false
    private var pendingDeepLinkId: Int?

    init() {
        store.appState = self
    }

    // MARK: 派生状态

    var isEntitled: Bool { entitlement?.entitled ?? false }
    var freeCount: Int { config?.freeCount ?? 20 }

    var effectiveProductIDs: (monthly: String, yearly: String) {
        let monthly = (config?.monthlyProductId.isEmpty == false)
            ? config!.monthlyProductId : AppConfig.defaultMonthlyProductID
        let yearly = (config?.yearlyProductId.isEmpty == false)
            ? config!.yearlyProductId : AppConfig.defaultYearlyProductID
        return (monthly, yearly)
    }

    var currentIdiom: Idiom? {
        idioms.indices.contains(currentIndex) ? idioms[currentIndex] : nil
    }

    // MARK: 启动

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        // 1. 先读缓存立即渲染
        let cached = LocalStore.loadCachedIdioms()
        idioms = cached
        newIdiomIds = Set(LocalStore.newIdiomIds)
        entitlement = LocalStore.loadCachedEntitlement()

        // 2. 落点占位：同一天再打开恢复上次位置；跨天（每日首次）等同步拿到 daily 后定位
        let today = DateUtil.todayString()
        if LocalStore.lastVisitDate == today,
           let lastId = LocalStore.lastIdiomId,
           let idx = cached.firstIndex(where: { $0.id == lastId }) {
            currentIndex = idx
        } else {
            needsDailyPositioning = true
        }
        if let pending = pendingDeepLinkId {
            pendingDeepLinkId = nil
            selectIdiom(id: pending)
        }

        // 3. 交易监听与商品 / 权益恢复
        store.start()

        // 4. 同步内容
        await sync()
    }

    /// 从后台切回前台时重新确认权益与内容（需求：订阅状态在切回时重新确认）
    func refreshOnForeground() async {
        guard didBootstrap else { return }
        await store.refreshCurrentEntitlements()
        await sync()
    }

    // MARK: 同步

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let cfg = try await api.fetchConfig()
            let isFirstSync = !LocalStore.hasCompletedFirstSync
            let versionChanged = cfg.contentVersion != LocalStore.lastSeenContentVersion
            config = cfg
            // 商品 ID 以后台配置为准，拿到 config 后按最新 ID 刷新商品（启动时先用默认 ID 拉过一次）
            await store.loadProducts()

            if versionChanged || idioms.isEmpty {
                let oldIds = Set(idioms.map { $0.id })
                let all = try await api.fetchAllIdioms()
                idioms = all
                LocalStore.saveIdioms(all)
                clampCurrentIndex()

                // 新增提醒：非首次安装、且确实有新增已发布成语时才弹，同批只弹一次（靠版本号推进保证）
                if !isFirstSync {
                    let added = Set(all.map { $0.id }).subtracting(oldIds)
                    if !added.isEmpty {
                        newIdiomIds.formUnion(added)
                        LocalStore.newIdiomIds = Array(newIdiomIds)
                        pendingNewCount = added.count
                        showNewIdiomsAlert = true
                    }
                }
                if isFirstSync { LocalStore.hasCompletedFirstSync = true }
                LocalStore.lastSeenContentVersion = cfg.contentVersion
            }

            // 每日成语定位 + 未来 7 天写入共享存储供小组件使用
            let today = DateUtil.todayString()
            let daily = try? await api.fetchDaily(date: today)
            if let week = try? await api.fetchDailyWeek(from: today) {
                SharedStore.saveWeek(week)
            }
            positionForToday(dailyId: daily?.id)
            WidgetCenter.shared.reloadAllTimelines()

            if let pending = pendingDeepLinkId {
                pendingDeepLinkId = nil
                selectIdiom(id: pending)
            }
            syncError = nil
        } catch {
            syncError = idioms.isEmpty
                ? "Couldn't load content. Check your connection and try again."
                : "You're offline. Showing cached content."
            // 断网兜底：用本地缓存与轮换公式定位当日成语，小组件继续用共享缓存
            positionForToday(dailyId: nil)
        }
    }

    /// 权益变化后内容锁定状态随之变化，强制重新拉取全量（绕过版本比对）
    private func reloadContentAfterEntitlementChange() async {
        if let all = try? await api.fetchAllIdioms() {
            idioms = all
            LocalStore.saveIdioms(all)
            clampCurrentIndex()
        }
        if let week = try? await api.fetchDailyWeek(from: DateUtil.todayString()) {
            SharedStore.saveWeek(week)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clampCurrentIndex() {
        if idioms.isEmpty {
            currentIndex = 0
        } else if currentIndex >= idioms.count {
            currentIndex = idioms.count - 1
        }
    }

    /// 落点规则：每天首次打开落在当日每日成语；同一天再打开在 bootstrap 阶段已恢复位置，这里不覆盖。
    private func positionForToday(dailyId: Int?) {
        guard needsDailyPositioning, !idioms.isEmpty else { return }
        var targetId = dailyId
        if targetId == nil {
            // 离线兜底：按与后端相同的轮换公式从本地缓存算当日成语
            let idx = DateUtil.dailyIndex(dateString: DateUtil.todayString(), count: idioms.count)
            targetId = idioms[idx].id
        }
        if let targetId = targetId,
           let idx = idioms.firstIndex(where: { $0.id == targetId }) {
            currentIndex = idx
        }
        needsDailyPositioning = false
        LocalStore.lastVisitDate = DateUtil.todayString()
        savePosition()
    }

    // MARK: 位置与导航

    /// 学习页当前页变化时调用：保存上次位置（idiomId + 日期）
    func savePosition() {
        guard let idiom = currentIdiom else { return }
        LocalStore.lastIdiomId = idiom.id
        LocalStore.lastVisitDate = DateUtil.todayString()
    }

    /// 从列表 / 深链接定位到某个成语（回到首页并翻到对应页），并清除其「新」角标
    func selectIdiom(id: Int) {
        guard let idx = idioms.firstIndex(where: { $0.id == id }) else {
            pendingDeepLinkId = id
            return
        }
        if newIdiomIds.contains(id) {
            newIdiomIds.remove(id)
            LocalStore.newIdiomIds = Array(newIdiomIds)
        }
        // 收起可能推入中的列表页 / 个人中心 / 测试页回到首页，PagerView 会按 currentIndex 动画跳页
        showAllList = false
        showSettings = false
        showQuiz = false
        currentIndex = idx
        savePosition()
    }

    /// 深链接 dailyidiom://idiom/{id}
    func handle(url: URL) {
        guard url.scheme == AppConfig.urlScheme,
              url.host == "idiom",
              let id = Int(url.lastPathComponent) else { return }
        if didBootstrap {
            selectIdiom(id: id)
        } else {
            pendingDeepLinkId = id
        }
    }

    // MARK: 权益

    /// 权益统一入口：StoreManager 每次从后端拿到最新状态后调用。权益翻转时重新拉取内容以刷新锁定状态。
    func applyEntitlement(_ status: EntitlementStatus) {
        let wasEntitled = isEntitled
        entitlement = status
        LocalStore.saveEntitlement(status)
        if let txId = status.originalTransactionId {
            SharedStore.originalTransactionId = txId
        }
        if status.entitled != wasEntitled {
            Task { [weak self] in
                await self?.reloadContentAfterEntitlementChange()
            }
        }
    }
}
