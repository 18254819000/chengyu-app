import SwiftUI

/// 全 App 通用弹窗（替代系统 .alert）：与新增提醒卡同一套铬——遮罩、纸面卡、阴影、主次按钮全部一致。
/// 规则：遮罩不可点消（必须点按钮关闭，与新增提醒卡一致，避免误触弄丢重要提示）。
/// 系统 .alert 已从 App 内全部移除；分享面板、Game Center 面板、苹果兑换码面板为苹果系统浮层，无法改样式，不在此列。
struct AppDialogView: View {
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        ZStack {
            Color.ink.opacity(0.38)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.ink)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.ink2)
                    .lineSpacing(5)
                    .padding(.top, 8)

                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentRed)
                        .cornerRadius(999)
                }
                .buttonStyle(.plain)
                .padding(.top, 22)

                if let secondaryTitle = secondaryTitle {
                    Button(action: { secondaryAction?() }) {
                        Text(secondaryTitle)
                            .font(.system(size: 14))
                            .foregroundColor(.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
            }
            .padding(.top, 26)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .background(Color.paperBg)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.black.opacity(0.30), radius: 30, x: 0, y: 12)
            .padding(.horizontal, 26)
        }
    }
}

extension View {
    /// 通用弹窗：isPresented 为 true 时以覆盖层呈现 AppDialogView。
    /// 单按钮时只传 primary；双按钮时 secondary 为次按钮（灰字）。
    func appDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                AppDialogView(
                    title: title,
                    message: message,
                    primaryTitle: primaryTitle,
                    primaryAction: primaryAction,
                    secondaryTitle: secondaryTitle,
                    secondaryAction: secondaryAction
                )
            }
        }
    }
}
