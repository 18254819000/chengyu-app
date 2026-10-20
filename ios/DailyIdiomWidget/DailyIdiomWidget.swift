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

/// 组件视图，严格按 UI 定稿极简版：只有成语大字、细线（左侧朱红短段）、中文解释、英文解释。
/// 无标题、无拼音、无底部文字、无按钮；点击整体经 widgetURL 直达 App 内该成语详情页。
struct DailyIdiomWidgetView: View {
    var entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                let chars = Array(entry.daily.idiom)
                ForEach(Array(chars.enumerated()), id: \.offset) { item in
                    Text(String(item.element))
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundColor(.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if item.offset < chars.count - 1 {
                        Spacer(minLength: 4)
                    }
                }
            }

            AccentDivider()
                .padding(.top, 18)

            Text(entry.daily.definitionZh ?? "")
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(6)
                .padding(.top, 14)

            Text(entry.daily.definitionEn ?? "")
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.ink2)
                .lineSpacing(5)
                .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paperBg)
        .widgetURL(URL(string: "\(AppConfig.urlScheme)://idiom/\(entry.daily.id)"))
    }
}

struct DailyIdiomWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyIdiomWidget", provider: Provider()) { entry in
            DailyIdiomWidgetView(entry: entry)
        }
        .configurationDisplayName("每日成语")
        .description("每天认识一个新成语")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct DailyIdiomWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyIdiomWidget()
    }
}
