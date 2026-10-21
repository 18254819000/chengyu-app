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
                    redeemButton
                    legal
                        .padding(.top, 18)
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .background(Color.paperBg.ignoresSafeArea())
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
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
        .alert("Notice", isPresented: messageBinding) {
            Button("OK") { store.message = nil }
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
            (Text("Unlock ") + Text("All Idioms").foregroundColor(.accentRed))
                .font(.system(size: 26, weight: .bold))
            Text("One idiom a day adds up.")
                .font(.system(size: 26, weight: .bold))
            Text("Subscribe to access the full idiom library, including every new idiom we add.")
                .font(.system(size: 13.5))
                .foregroundColor(.ink2)
                .lineSpacing(5)
                .padding(.top, 2)
        }
    }

    // MARK: 权益对比（免费数量取后台配置）

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            compareRow(name: "", free: "Free", pro: "Premium", isHeader: true)
            Divider().overlay(Color.line)
            compareRow(name: "Idioms to learn", free: "\(state.freeCount)", pro: "All", isHeader: false)
            Divider().overlay(Color.line)
            compareRow(name: "Full example sentences", free: "First \(state.freeCount)", pro: "All", isHeader: false)
            Divider().overlay(Color.line)
            compareRow(name: "New idioms as they're added", free: "—", pro: "Unlocked automatically", isHeader: false)
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
                    Text("Loading plans…")
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
                    Text(isYearly ? "Yearly" : "Monthly")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.ink)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.ink)
                        Text(isYearly ? "/ year" : "/ month")
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
                    Text(isYearly ? "About \(monthlyEquivalent(of: product))/month" : "Cancel anytime")
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
                    Text("Best Value")
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
            return "Subscribe Now"
        }
        return "Start Free Trial"
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            HStack(spacing: 8) {
                if store.isRestoring {
                    ProgressView()
                }
                Text("Restore Purchases")
                    .font(.system(size: 13.5))
            }
            .foregroundColor(.ink2)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
        .disabled(store.isRestoring)
    }

    /// Apple offer-code redemption entry: presents Apple's own system redemption sheet.
    /// A redeemed offer produces a normal StoreKit transaction, which StoreManager's existing
    /// Transaction.updates listener picks up and refreshes entitlement from automatically.
    private var redeemButton: some View {
        Button {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        } label: {
            Text("Redeem Code")
                .font(.system(size: 13.5))
                .foregroundColor(.ink2)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    // MARK: 条款（苹果审核要求：续订说明 + 协议与隐私链接）

    private var legal: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID at confirmation of purchase. Your subscription automatically renews unless canceled at least 24 hours before the end of the current period, and your account will be charged for renewal within 24 hours prior to that. You can manage or cancel your subscription anytime in your App Store account settings.")
                .font(.system(size: 11))
                .foregroundColor(.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            HStack(spacing: 6) {
                Button("Privacy Policy") { openURL(AppConfig.privacyPolicyURL) }
                Text("·").foregroundColor(.ink3)
                Button("Terms of Use") { openURL(AppConfig.termsOfUseURL) }
            }
            .font(.system(size: 11))
            .foregroundColor(.ink2)
        }
        .frame(maxWidth: .infinity)
    }
}
