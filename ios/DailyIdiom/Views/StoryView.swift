import SwiftUI

/// 故事页：详情页故事入口弹出的全屏 sheet。
/// 图片区仅当 imageUrl 非空时出现；英文故事区仅当 storyEn 非空时出现；加载失败显示浅色占位，不阻断阅读。
struct StoryView: View {
    let idiom: Idiom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.cardBg)
                            .frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.ink2)
                    }
                }
                Spacer()
                Text("STORY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.ink3)
                Spacer()
                Color.clear.frame(width: 30, height: 30)
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if idiom.hasStoryImage, let url = URL(string: idiom.imageUrl ?? "") {
                        storyImage(url: url)
                            .padding(.top, 14)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(idiom.idiom)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.ink)
                        Text(idiom.pinyin)
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(.ink2)
                    }
                    .padding(.top, 20)

                    AccentDivider()
                        .padding(.top, 18)

                    Text("典源与故事")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(.ink3)
                        .padding(.top, 22)

                    Text(idiom.storyZh ?? "")
                        .font(.system(size: 16.5))
                        .lineSpacing(10)
                        .padding(.top, 10)

                    if let storyEn = idiom.storyEn,
                       !storyEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        AccentDivider()
                            .padding(.top, 26)

                        Text("ENGLISH STORY")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(.ink3)
                            .padding(.top, 22)

                        Text(storyEn)
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(.ink2)
                            .lineSpacing(6)
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.paperBg.ignoresSafeArea())
    }

    /// 故事配图：16:9 填充裁剪；加载失败时显示浅色占位图
    private func storyImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
            default:
                ZStack {
                    Color.cardBg
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.ink3)
                }
                .aspectRatio(16 / 9, contentMode: .fill)
            }
        }
        .clipped()
        .cornerRadius(16)
    }
}
