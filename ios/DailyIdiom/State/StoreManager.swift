import Foundation
import StoreKit

enum StoreError: Error {
    case failedVerification
}

/// StoreKit 2 全链路：取商品、购买、交易监听、当前权益、恢复购买。
/// 所有已验签交易统一走「提交后端 verify -> 用后端返回刷新权益」的管道，权益发放以后端为准。
@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var isRestoring = false
    /// 购买 / 恢复等动作的提示文案（成功、失败、取消、处理中都有明确文案），View 层以 Alert 展示
    @Published var message: String?

    weak var appState: AppState?
    private var updatesTask: Task<Void, Never>?
    private var didStart = false

    /// App 启动时调用一次：开启交易监听（续费、恢复等系统侧交易都会从这里进来）
    func start() {
        guard !didStart else { return }
        didStart = true
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.process(result)
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshCurrentEntitlements()
        }
    }

    // MARK: 商品

    /// 按当前 config 的商品 ID 拉取（config 为空时用默认 ID）；年订阅排前面
    func loadProducts() async {
        guard let ids = appState?.effectiveProductIDs else { return }
        do {
            let fetched = try await Product.products(for: [ids.yearly, ids.monthly])
            // 年订阅排前面（订阅页默认选中第一个，即年订阅）
            products = fetched.sorted { a, b in
                if a.id == ids.yearly { return true }
                if b.id == ids.yearly { return false }
                return a.id < b.id
            }
        } catch {
            products = []
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// 试用文案，如「免费试用 7 天」；无免费试用时返回 nil
    func trialDescription(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return "免费试用 \(offer.period.value) \(unitText(offer.period.unit))"
    }

    private func unitText(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return "天"
        case .week: return "周"
        case .month: return "个月"
        case .year: return "年"
        @unknown default: return "天"
        }
    }

    // MARK: 购买

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await process(verification)
                if appState?.isEntitled == true {
                    message = "订阅成功，全部成语已解锁"
                } else {
                    message = "购买已完成，权益正在确认中，请稍候片刻"
                }
            case .userCancelled:
                message = "已取消购买"
            case .pending:
                message = "购买处理中：等待批准完成后将自动解锁"
            @unknown default:
                message = "购买未完成，请稍后重试"
            }
        } catch {
            message = "购买失败：\(error.localizedDescription)"
        }
    }

    /// 恢复购买：同步 App Store 交易后重走权益管道
    func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshCurrentEntitlements()
            message = appState?.isEntitled == true ? "已恢复你的订阅" : "未找到可恢复的订阅"
        } catch {
            message = "恢复购买失败：\(error.localizedDescription)"
        }
    }

    // MARK: 权益管道

    /// 遍历 StoreKit 当前权益取最新一笔自动续期交易提交后端；无本地权益时用存量交易号向后端对账（退款/到期后回收）
    func refreshCurrentEntitlements() async {
        var latest: VerificationResult<Transaction>?
        var latestExpiration: Date = .distantPast
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productType == .autoRenewable else { continue }
            let expiration = transaction.expirationDate ?? .distantPast
            if expiration >= latestExpiration {
                latestExpiration = expiration
                latest = result
            }
        }
        if let latest = latest {
            await process(latest)
        } else if let txId = SharedStore.originalTransactionId,
                  let status = try? await APIClient().fetchEntitlementStatus(originalTransactionId: txId) {
            appState?.applyEntitlement(status)
        }
    }

    /// 验签 -> 提交后端 verify -> 刷新权益 -> finish。未通过本地验签的交易直接忽略。
    private func process(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        SharedStore.originalTransactionId = String(transaction.originalID)
        if let status = try? await APIClient().verifyTransaction(jws: result.jwsRepresentation) {
            appState?.applyEntitlement(status)
        }
        await transaction.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
