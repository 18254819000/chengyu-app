import SwiftUI

/// 单个成语页：有权益显示完整详情，锁定条目显示锁定页。
struct IdiomPageView: View {
    let idiom: Idiom
    @EnvironmentObject var state: AppState

    var body: some View {
        if idiom.locked {
            LockedIdiomView(idiom: idiom)
        } else {
            IdiomDetailView(idiom: idiom)
        }
    }
}

/// 详情页，按首页 UI 定稿：逐字拼音单元、细线、中英释义、例句浅卡（成语在例句中朱红加粗）。
/// 分享入口已统一到首页顶栏（作用于当前成语），本页内不再放分享按钮。
struct IdiomDetailView: View {
    let idiom: Idiom
    @State private var showingStory = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                pinyinUnits
                    .padding(.top, 46)

                if !idiom.tagList.isEmpty {
                    tagPills
                        .padding(.top, 20)
                }

                AccentDivider()
                    .padding(.top, 24)

                Text("MEANING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.ink3)
                    .padding(.top, 24)

                Text(idiom.definitionZh ?? "")
                    .font(.system(size: 17, weight: .medium))
                    .lineSpacing(8)
                    .padding(.top, 10)

                Text(idiom.definitionEn ?? "")
                    .font(.system(size: 14.5, design: .serif))
                    .foregroundColor(.ink2)
                    .lineSpacing(6)
                    .padding(.top, 8)

                exampleCard
                    .padding(.top, 26)

                if idiom.hasStory {
                    storyEntry
                        .padding(.top, 16)
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingStory) {
            StoryView(idiom: idiom)
        }
    }

    /// 分类标签行：成语下方、细线之前；多个标签横向排列
    private var tagPills: some View {
        HStack(spacing: 8) {
            ForEach(idiom.tagList, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.cardBg)
                    .cornerRadius(999)
            }
        }
    }

    /// 故事入口卡：仅有中文故事时出现，点击全屏 sheet 打开故事页
    private var storyEntry: some View {
        Button {
            LocalStore.recordStoryRead(id: idiom.id)
            showingStory = true
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(Color.cardBg)
                        .frame(width: 38, height: 38)
                    Image(systemName: "book")
                        .font(.system(size: 17))
                        .foregroundColor(.accentRed)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("典源与故事")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(.ink)
                    Text("ORIGIN & STORY")
                        .font(.system(size: 12))
                        .tracking(1)
                        .foregroundColor(.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ink3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    /// 详情字号：按排版单元数缩放，保证 375 宽以上机型上首尾字不被裁（5 单元 54，之后按内容区 319 宽反推：6 单元 49、7 单元 42、10 单元约 28）
    private var charSize: CGFloat {
        let n = idiom.displayUnits.count
        if n <= 5 { return 54 }
        return min(49, (319 - 4 * CGFloat(n - 1)) / CGFloat(n))
    }

    /// 逐字对齐：每个汉字一个纵向单元（拼音在上、汉字在下），等距排布；
    /// 带标点成语按 displayUnits 排，标点作分隔符（空白占拼音位、贴底对齐）
    private var pinyinUnits: some View {
        let units = idiom.displayUnits
        return Group {
            if idiom.charPinyins.count == idiom.hanChars.count {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(units.enumerated()), id: \.offset) { item in
                        VStack(spacing: 7) {
                            Text(item.element.pinyin ?? " ")
                                .font(.system(size: 15, design: .serif))
                                .foregroundColor(.ink2)
                            Text(item.element.text)
                                .font(.system(size: charSize, weight: .semibold))
                                .foregroundColor(.ink)
                        }
                        if item.offset < units.count - 1 {
                            Spacer(minLength: 4)
                        }
                    }
                }
            } else {
                // 逐字拼音与汉字数不一致时的兜底排版（后端发布校验应保证不出现）
                VStack(alignment: .leading, spacing: 7) {
                    Text(idiom.pinyin)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.ink2)
                    Text(idiom.idiom)
                        .font(.system(size: charSize, weight: .semibold))
                        .foregroundColor(.ink)
                }
            }
        }
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXAMPLE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundColor(.ink3)

            highlightedExample
                .font(.system(size: 15.5))
                .lineSpacing(8)
                .padding(.top, 9)

            Text(idiom.exampleEn ?? "")
                .font(.system(size: 13.5, design: .serif))
                .foregroundColor(.ink2)
                .lineSpacing(5)
                .padding(.top, 7)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg)
        .cornerRadius(16)
    }

    /// 中文例句中成语本体朱红加粗
    private var highlightedExample: Text {
        let example = idiom.exampleZh ?? ""
        guard let range = example.range(of: idiom.idiom) else { return Text(example) }
        let before = String(example[..<range.lowerBound])
        let after = String(example[range.upperBound...])
        return Text(before)
            + Text(idiom.idiom).foregroundColor(.accentRed).fontWeight(.semibold)
            + Text(after)
    }
}

/// 锁定页：成语名 + 拼音可见，锁图标 + 订阅按钮，不露释义与例句。
struct LockedIdiomView: View {
    let idiom: Idiom
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            pinyinUnits
                .padding(.top, 46)
                .padding(.horizontal, 28)

            AccentDivider()
                .padding(.top, 30)
                .padding(.horizontal, 28)

            Spacer()

            Image(systemName: "lock")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.ink3)

            Text(L("Subscribers Only"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.ink2)
                .padding(.top, 16)

            Button {
                state.showPaywall = true
            } label: {
                Text(L("Subscribe to Unlock All Idioms"))
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .background(Color.accentRed)
                    .cornerRadius(999)
            }
            .padding(.top, 22)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// 锁定页字号：与详情页同口径缩放（5 单元 54，之后按内容区 319 宽反推）
    private var charSize: CGFloat {
        let n = idiom.displayUnits.count
        if n <= 5 { return 54 }
        return min(49, (319 - 4 * CGFloat(n - 1)) / CGFloat(n))
    }

    private var pinyinUnits: some View {
        let units = idiom.displayUnits
        return Group {
            if idiom.charPinyins.count == idiom.hanChars.count {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(units.enumerated()), id: \.offset) { item in
                        VStack(spacing: 7) {
                            Text(item.element.pinyin ?? " ")
                                .font(.system(size: 15, design: .serif))
                                .foregroundColor(.ink2)
                            Text(item.element.text)
                                .font(.system(size: charSize, weight: .semibold))
                                .foregroundColor(.ink2)
                        }
                        if item.offset < units.count - 1 {
                            Spacer(minLength: 4)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text(idiom.pinyin)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.ink2)
                    Text(idiom.idiom)
                        .font(.system(size: charSize, weight: .semibold))
                        .foregroundColor(.ink2)
                }
            }
        }
    }
}
