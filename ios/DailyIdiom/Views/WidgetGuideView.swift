import SwiftUI

/// 添加小组件引导：三步图文说明（第一版只提供大尺寸小组件）。
struct WidgetGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                widgetPreview
                    .padding(.top, 10)

                step(number: 1,
                     title: "长按桌面空白处",
                     detail: "在主屏幕上长按任意空白区域，直到 App 图标开始抖动。")
                step(number: 2,
                     title: "点左上角的「+」",
                     detail: "在小组件列表中向下找到「每日成语」，点它进入。")
                step(number: 3,
                     title: "选择大尺寸并添加",
                     detail: "左右滑动选到大尺寸，点「添加小组件」，再点「完成」即可。每天打开桌面就能看到一个新的成语。")

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 22)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle("添加小组件")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 大尺寸小组件效果示意（与组件实际样式一致：成语大字 + 中英解释）
    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array("画蛇添足".enumerated()), id: \.offset) { item in
                    Text(String(item.element))
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.ink)
                    if item.offset < 3 { Spacer(minLength: 4) }
                }
            }
            AccentDivider()
                .padding(.top, 14)
            Text("比喻做了多余的事，反而把事情弄糟。")
                .font(.system(size: 14, weight: .medium))
                .padding(.top, 12)
            Text("To ruin something by adding what is superfluous; to gild the lily.")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.ink2)
                .padding(.top, 5)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
    }

    private func step(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Color.accentRed)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.ink)
                Text(detail)
                    .font(.system(size: 13.5))
                    .foregroundColor(.ink2)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 22)
    }
}
