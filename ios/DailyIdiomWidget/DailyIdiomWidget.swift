import WidgetKit
import SwiftUI

/// 小组件条目：一天一个，日期为当地 0 点。
struct DailyEntry: TimelineEntry {
    let date: Date
    let daily: DailyIdiom
}

/// 时间线：一次生成未来 7 天条目（每天 0 点一个），policy 为 .atEnd，第 7 天后系统再来要新时间线。
/// 数据优先级：App Group 共享缓存 -> 组件内直连后端 /daily/week -> 内置兜底一条，永不空白。
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: Date(), daily: .fallback(date: DateUtil.todayString()))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        Task {
            let days = await loadWeek()
            completion(DailyEntry(date: Date(), daily: todayItem(in: days)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        Task {
            let days = await loadWeek()
            let entries = days
                .compactMap { day -> DailyEntry? in
                    guard let date = DateUtil.date(fromString: day.date) else { return nil }
                    return DailyEntry(date: date, daily: day)
                }
                .sorted { $0.date < $1.date }
            let fallback = DailyEntry(date: Date(), daily: .fallback(date: DateUtil.todayString()))
            let timeline = Timeline(entries: entries.isEmpty ? [fallback] : entries, policy: .atEnd)
            completion(timeline)
        }
    }

    private func loadWeek() async -> [DailyIdiom] {
        let today = DateUtil.todayString()
        let shared = SharedStore.loadWeek()
        if shared.contains(where: { $0.date == today }) {
            return shared
        }
        if let fetched = try? await APIClient().fetchDailyWeek(from: today), !fetched.isEmpty {
            SharedStore.saveWeek(fetched)
            return fetched
        }
        return shared
    }

    private func todayItem(in days: [DailyIdiom]) -> DailyIdiom {
        let today = DateUtil.todayString()
        return days.first { $0.date == today } ?? days.first ?? .fallback(date: today)
    }
}

/// 组件视图，严格按 UI 定稿极简版：成语大字、细线（左侧朱红短段）、解释；无标题、无拼音、无底部文字、无按钮；
/// 点击整体经 widgetURL 直达 App 内该成语详情页。
/// 中号：成语大字 + 英文解释（3 行，行距收紧后中号高度内放得下 3 行英文）。
/// 大号 / 超大号：成语大字 + 中文解释 + 英文解释，中英文行数都放开（中文 6 行、英文 8 行），
/// 正常长度的释义都能完整显示，不再只截取英文。
struct DailyIdiomWidgetView: View {
    var entry: DailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemLarge || family == .systemExtraLarge {
                largeView
            } else {
                mediumView
            }
        }
        .modifier(WidgetBackgroundModifier())
        .widgetURL(URL(string: "\(AppConfig.urlScheme)://idiom/\(entry.daily.id)"))
    }

    /// 成语大字行：逐字排布、字间留空，字数多时自动缩小不换行。
    private func idiomRow(size: CGFloat) -> some View {
        HStack(spacing: 0) {
            let chars = Array(entry.daily.idiom)
            ForEach(Array(chars.enumerated()), id: \.offset) { item in
                Text(String(item.element))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if item.offset < chars.count - 1 {
                    Spacer(minLength: 4)
                }
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 0) {
            idiomRow(size: 34)

            AccentDivider()
                .padding(.top, 8)

            Text(entry.daily.definitionEn ?? "")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.ink2)
                .lineSpacing(3)
                .lineLimit(3)
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            idiomRow(size: 40)

            AccentDivider()
                .padding(.top, 12)

            Text(entry.daily.definitionZh ?? "")
                .font(.system(size: 14))
                .foregroundColor(.ink)
                .lineSpacing(3)
                .lineLimit(6)
                .padding(.top, 10)

            Text(entry.daily.definitionEn ?? "")
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.ink2)
                .lineSpacing(3)
                .lineLimit(8)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 组件背景：iOS 17+ 用 containerBackground API 上报背景（消除系统
/// 「Please adopt the containerBackground API」提示），iOS 15/16 用普通
/// background 兜底；两条路径视觉一致，都是纸面色 #FAF8F4。
struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(Color.paperBg, for: .widget)
        } else {
            content.background(Color.paperBg)
        }
    }
}

struct DailyIdiomWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyIdiomWidget", provider: Provider()) { entry in
            DailyIdiomWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Chengyu")
        .description(L("A new Chinese idiom every day"))
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct DailyIdiomWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyIdiomWidget()
    }
}
