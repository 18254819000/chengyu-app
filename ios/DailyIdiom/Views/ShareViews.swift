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

/// 成语分享卡（1080×1350）：纸面极简——字标、逐字拼音 + 成语大字、朱红细线、中英释义、
/// 例句浅卡，底部一句轻问句 + App 名。朱红只作点缀，无渐变、无大面积彩色。
struct IdiomShareCard: View {
    let idiom: Idiom

    var body: some View {
        VStack(spacing: 0) {
            wordmark

            Spacer(minLength: 40)

            pinyinUnits

            AccentDivider()
                .frame(width: 520)
                .padding(.top, 64)

            Text(idiom.definitionZh ?? "")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.ink)
                .lineSpacing(14)
                .multilineTextAlignment(.center)
                .padding(.top, 56)

            Text(idiom.definitionEn ?? "")
                .font(.system(size: 37, design: .serif))
                .foregroundColor(.ink2)
                .lineSpacing(10)
                .multilineTextAlignment(.center)
                .padding(.top, 26)

            if let exampleZh = idiom.exampleZh, !exampleZh.isEmpty {
                exampleCard(exampleZh: exampleZh)
                    .padding(.top, 60)
            }

            Spacer(minLength: 40)

            Text("这个成语，你读对了吗？")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.ink)

            Text("每 日 成 语")
                .font(.system(size: 29))
                .tracking(4)
                .foregroundColor(.ink3)
                .padding(.top, 22)
        }
        .padding(.horizontal, 92)
        .padding(.vertical, 96)
        .frame(width: 1080, height: 1350)
        .background(Color.paperBg)
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("每日成语")
                .font(.system(size: 42, weight: .bold))
                .tracking(6)
            Text("。")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.accentRed)
        }
        .foregroundColor(.ink)
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
                .font(.system(size: 40))
                .lineSpacing(12)

            Text(idiom.exampleEn ?? "")
                .font(.system(size: 33, design: .serif))
                .foregroundColor(.ink2)
                .lineSpacing(8)
                .padding(.top, 16)
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

/// 成绩分享卡（1080×1350）：难度标签、大号分数、答对题数，底部挑战语按成绩分档
/// （带表情的文案是用户定的分享口径，卡片其余部分保持纸面极简）。
struct ScoreShareCard: View {
    let difficulty: QuizDifficulty
    let score: Int
    let correct: Int
    let total: Int
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text("每日成语 · 成语测试")
                .font(.system(size: 42, weight: .bold))
                .tracking(4)
                .foregroundColor(.ink)

            Text(difficulty.tagText)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.accentRed)
                .padding(.horizontal, 30)
                .padding(.vertical, 13)
                .background(Color.accentSoft)
                .cornerRadius(999)
                .padding(.top, 54)

            Spacer(minLength: 40)

            HStack(alignment: .bottom, spacing: 10) {
                Text("\(score)")
                    .font(.system(size: 330, weight: .bold))
                    .foregroundColor(.ink)
                Text("分")
                    .font(.system(size: 66, weight: .semibold))
                    .foregroundColor(.ink)
                    .padding(.bottom, 52)
            }

            Text("答对 \(correct)/\(total) 题")
                .font(.system(size: 54, weight: .medium))
                .foregroundColor(.ink2)
                .padding(.top, 10)

            AccentDivider()
                .frame(width: 520)
                .padding(.top, 64)

            Text(Self.challengeLine(score: score))
                .font(.system(size: 58, weight: .semibold))
                .foregroundColor(.ink)
                .padding(.top, 56)

            Spacer(minLength: 40)

            Text(DateUtil.displayString(from: date))
                .font(.system(size: 30))
                .foregroundColor(.ink3)

            Text("每 日 成 语")
                .font(.system(size: 29))
                .tracking(4)
                .foregroundColor(.ink3)
                .padding(.top, 18)
        }
        .padding(.horizontal, 92)
        .padding(.vertical, 96)
        .frame(width: 1080, height: 1350)
        .background(Color.paperBg)
    }

    /// 挑战语分档：≥80（含满分）邀战 / 50~79 邀请挑战 / <50 自嘲式邀请
    static func challengeLine(score: Int) -> String {
        if score >= 80 {
            return "不服来战 😏"
        } else if score >= 50 {
            return "来挑战，你能对几道？🤔"
        } else {
            return "这套题有点东西，来试试 💪"
        }
    }
}
