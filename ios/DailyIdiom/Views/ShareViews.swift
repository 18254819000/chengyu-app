import SwiftUI
import UIKit

/// SwiftUI 视图转图（iOS 15 兼容方案）：UIHostingController 承载 + UIGraphicsImageRenderer 出图，
/// 不用 iOS 16 才有的新转图 API。目标尺寸 1080×1350（3:4 竖版），scale 固定 1 保证像素确切。
enum ShareCardRenderer {
    static let cardSize = CGSize(width: 1080, height: 1350)

    static func render<V: View>(_ view: V) -> UIImage? {
        let controller = UIHostingController(
            rootView: view.frame(width: cardSize.width, height: cardSize.height)
        )
        controller.view.bounds = CGRect(origin: .zero, size: cardSize)
        controller.view.backgroundColor = UIColor(red: 250 / 255, green: 248 / 255, blue: 244 / 255, alpha: 1)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: cardSize, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

/// 系统分享面板包装：UIActivityViewController。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 品牌印章：朱红圆角方块 + 白色加粗两行「Daily / Chengyu」，像盖章一样落在卡片一角。
/// 两张分享卡共用同一组件、同一规格，保证品牌标记一致。默认边长 160（在 1080×1350 画布上）。
struct BrandSeal: View {
    var size: CGFloat = 160

    var body: some View {
        VStack(spacing: size * 0.03) {
            Text("Daily")
            Text("Chengyu")
        }
        .font(.system(size: size * 0.24, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundColor(.white)
        .padding(.horizontal, size * 0.06)
        .frame(width: size, height: size)
        .background(Color.accentRed)
        .cornerRadius(size * 0.18)
    }
}

/// 成语分享卡（1080×1350），英文为主：英文小字标、成语汉字大字 + 逐字拼音、英文释义为主、
/// 中文释义小字为辅、例句（中文 + 英文译文），底部英文轻问句 + 品牌印章。
/// 有意保留的中文元素：成语汉字本体、中文释义（小字）、中文例句——卡片的分享对象要学的正是中文。
struct IdiomShareCard: View {
    let idiom: Idiom

    var body: some View {
        VStack(spacing: 0) {
            Text("Daily Chengyu")
                .font(.system(size: 36, weight: .bold))
                .tracking(5)
                .foregroundColor(.ink)

            Spacer(minLength: 40)

            pinyinUnits

            AccentDivider()
                .frame(width: 520)
                .padding(.top, 64)

            Text(idiom.definitionEn ?? "")
                .font(.system(size: 46, design: .serif))
                .foregroundColor(.ink)
                .lineSpacing(12)
                .multilineTextAlignment(.center)
                .padding(.top, 56)

            Text(idiom.definitionZh ?? "")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.ink3)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            if let exampleZh = idiom.exampleZh, !exampleZh.isEmpty {
                exampleCard(exampleZh: exampleZh)
                    .padding(.top, 56)
            }

            Spacer(minLength: 40)

            HStack(alignment: .center, spacing: 0) {
                Text("Can you read this one?")
                    .font(.system(size: 40, weight: .medium, design: .serif))
                    .foregroundColor(.ink)
                Spacer()
                BrandSeal()
            }
        }
        .padding(.horizontal, 92)
        .padding(.vertical, 96)
        .frame(width: 1080, height: 1350)
        .background(Color.paperBg)
    }

    /// 逐字对齐：拼音在上、汉字在下，与详情页同式；逐字拼音缺失 / 数量不对时退回完整拼音
    private var pinyinUnits: some View {
        let chars = Array(idiom.idiom)
        let pinyins = idiom.charPinyins
        return Group {
            if pinyins.count == chars.count {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(chars.enumerated()), id: \.offset) { item in
                        VStack(spacing: 16) {
                            Text(pinyins[item.offset])
                                .font(.system(size: 40, design: .serif))
                                .foregroundColor(.ink2)
                            Text(String(item.element))
                                .font(.system(size: 196, weight: .semibold))
                                .foregroundColor(.ink)
                        }
                        if item.offset < chars.count - 1 {
                            Spacer(minLength: 8)
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Text(idiom.pinyin)
                        .font(.system(size: 40, design: .serif))
                        .foregroundColor(.ink2)
                    Text(idiom.idiom)
                        .font(.system(size: 196, weight: .semibold))
                        .foregroundColor(.ink)
                }
            }
        }
    }

    private func exampleCard(exampleZh: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            highlightedExample(exampleZh)
                .font(.system(size: 38))
                .lineSpacing(11)

            if let exampleEn = idiom.exampleEn, !exampleEn.isEmpty {
                Text(exampleEn)
                    .font(.system(size: 31, design: .serif))
                    .foregroundColor(.ink2)
                    .lineSpacing(8)
                    .padding(.top, 14)
            }
        }
        .padding(44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg)
        .cornerRadius(28)
    }

    /// 中文例句中成语本体朱红加粗（与详情页一致）
    private func highlightedExample(_ example: String) -> Text {
        guard let range = example.range(of: idiom.idiom) else { return Text(example) }
        let before = String(example[..<range.lowerBound])
        let after = String(example[range.upperBound...])
        return Text(before)
            + Text(idiom.idiom).foregroundColor(.accentRed).fontWeight(.semibold)
            + Text(after)
    }
}

/// 成绩分享卡（1080×1350），全英文：标题 Chengyu Quiz、难度标签 Easy/Medium/Hard、大号分数、
/// 「X/10 correct」、挑战语按成绩分档（英文，带表情为用户定的分享口径），底部英文日期 + 品牌印章。
struct ScoreShareCard: View {
    let difficulty: QuizDifficulty
    let score: Int
    let correct: Int
    let total: Int
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text("Chengyu Quiz")
                .font(.system(size: 44, weight: .bold))
                .tracking(4)
                .foregroundColor(.ink)

            Text(difficulty.englishTitle)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.accentRed)
                .padding(.horizontal, 30)
                .padding(.vertical, 13)
                .background(Color.accentSoft)
                .cornerRadius(999)
                .padding(.top, 54)

            Spacer(minLength: 40)

            Text("\(score)")
                .font(.system(size: 330, weight: .bold))
                .foregroundColor(.ink)

            Text("\(correct)/\(total) correct")
                .font(.system(size: 52, weight: .medium))
                .foregroundColor(.ink2)
                .padding(.top, 6)

            AccentDivider()
                .frame(width: 520)
                .padding(.top, 64)

            Text(Self.challengeLine(score: score))
                .font(.system(size: 54, weight: .semibold))
                .foregroundColor(.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.top, 56)

            Spacer(minLength: 40)

            HStack(alignment: .center, spacing: 0) {
                Text(DateUtil.englishString(from: date))
                    .font(.system(size: 30))
                    .foregroundColor(.ink3)
                Spacer()
                BrandSeal()
            }
        }
        .padding(.horizontal, 92)
        .padding(.vertical, 96)
        .frame(width: 1080, height: 1350)
        .background(Color.paperBg)
    }

    /// 挑战语分档（英文）：≥80（含满分）邀战 / 50~79 邀请挑战 / <50 自嘲式邀请
    static func challengeLine(score: Int) -> String {
        if score >= 80 {
            return "Think you can beat me? 😏"
        } else if score >= 50 {
            return "Come challenge me — how many can you get right? 🤔"
        } else {
            return "Tougher than it looks. Give it a try 💪"
        }
    }
}
