import SwiftUI
import StoreKit

/// 订阅页（付费墙 Sheet）：权益对比、年/月商品卡（价格用商品本地化价格）、试用信息、恢复购买、续订条款与协议链接。
struct PaywallView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: StoreManager
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.openURL) private var openURL
    @State private var selectedProductID: String?

    private var selectedProduct: Product? {
        guard let id = selectedProductID else { return store.products.first }
        return store.product(for: id) ?? store.products.first
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    comparisonTable
                        .padding(.top, 24)
                    plans
                        .padding(.top, 22)
                    buyButton
                        .padding(.top, 22)
                    restoreButton
                    legal
                        .padding(.top, 18)
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .background(Color.paperBg.ignoresSafeArea())
            .navigationTitle("订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.ink2)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            if store.products.isEmpty {
                await store.loadProducts()
            }
            if selectedProductID == nil {
                selectedProductID = store.products.first?.id
            }
        }
        .onChange(of: state.isEntitled) { entitled in
            if entitled {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert("提示", isPresented: messageBinding) {
            Button("知道了") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )
    }

    // MARK: 头部文案

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text("解锁") + Text("全部成语").foregroundColor(.accentRed))
                .font(.system(size: 26, weight: .bold))
            Text("每天学一个，积累成多")
                .font(.system(size: 26, weight: .bold))
            Text("订阅后可查阅成语库全部内容，包含后续新增的每一个成语。")
                .font(.system(size: 13.5))
                .foregroundColor(.ink2)
                .lineSpacing(5)
                .padding(.top, 2)
        }
    }

    // MARK: 权益对比（免费数量取后台配置）

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            compareRow(name: "", free: "免费", pro: "订阅", isHeader: true)
            Divider().overlay(Color.line)
            compareRow(name: "可学成语", free: "\(state.freeCount) 个", pro: "全部", isHeader: false)
            Divider().overlay(Color.line)
            compareRow(name: "例句完整内容", free: "\(state.freeCount) 个内", pro: "全部", isHeader: false)
            Divider().overlay(Color.line)
            compareRow(name: "后续新增成语", free: "—", pro: "同步解锁", isHeader: false)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line, lineWidth: 1))
    }

    private func compareRow(name: String, free: String, pro: String, isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.ink3)
            Text(pro)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.accentRed)
        }
        .font(.system(size: isHeader ? 12.5 : 13.5, weight: isHeader ? .semibold : .regular))
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(isHeader ? Color.cardBg : Color.clear)
    }

    // MARK: 商品卡

    private var plans: some View {
        VStack(spacing: 12) {
            if store.products.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在加载订阅商品…")
                        .font(.system(size: 13.5))
                        .foregroundColor(.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
            }
            ForEach(store.products) { product in
                planCard(product)
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isYearly = product.id == state.effectiveProductIDs.yearly
        let selected = selectedProduct?.id == product.id
        return Button {
            selectedProductID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(isYearly ? "年订阅" : "月订阅")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.ink)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.ink)
                        Text(isYearly ? "/ 年" : "/ 月")
                            .font(.system(size: 12.5))
                            .foregroundColor(.ink2)
                    }
                }
                HStack(spacing: 4) {
                    if let trial = store.trialDescription(for: product) {
                        Text(trial)
                            .foregroundColor(.accentRed)
                            .fontWeight(.semibold)
                        Text("·")
                    }
                    Text(isYearly ? "折合每月约 \(monthlyEquivalent(of: product))" : "随时可取消")
                }
                .font(.system(size: 12.5))
                .foregroundColor(.ink2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentSoft.opacity(0.35) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.accentRed : Color.line, lineWidth: selected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isYearly {
                    Text("更划算")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.accentRed)
                        .cornerRadius(999)
                        .offset(x: -14, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 年订阅折合月价，用商品自身的本地化格式，避免写死美元
    private func monthlyEquivalent(of product: Product) -> String {
        let monthly = product.price / 12
        return product.priceFormatStyle.format(monthly)
    }

    // MARK: 购买与恢复

    private var buyButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await store.purchase(product) }
        } label: {
            HStack(spacing: 10) {
                if store.isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text(buyButtonTitle)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentRed)
            .cornerRadius(999)
        }
        .disabled(selectedProduct == nil || store.isPurchasing)
        .opacity(selectedProduct == nil ? 0.5 : 1)
    }

    private var buyButtonTitle: String {
        guard let product = selectedProduct,
              store.trialDescription(for: product) != nil else {
            return "立即订阅"
        }
        return "免费试用并订阅"
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            HStack(spacing: 8) {
                if store.isRestoring {
                    ProgressView()
                }
                Text("恢复购买")
                    .font(.system(size: 13.5))
            }
            .foregroundColor(.ink2)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
        .disabled(store.isRestoring)
    }

    // MARK: 条款（苹果审核要求：续订说明 + 协议与隐私链接）

    private var legal: some View {
        VStack(spacing: 8) {
            Text("试用期结束后按所选方案自动续订扣费，到期前 24 小时内扣款。\n可随时在 iPhone 的「设置 - 订阅」中取消，取消后到期停止续订。")
                .font(.system(size: 11))
                .foregroundColor(.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            HStack(spacing: 6) {
                Button("隐私政策") { openURL(AppConfig.privacyPolicyURL) }
                Text("·").foregroundColor(.ink3)
                Button("用户协议") { openURL(AppConfig.termsOfUseURL) }
            }
            .font(.system(size: 11))
            .foregroundColor(.ink2)
        }
        .frame(maxWidth: .infinity)
    }
}
