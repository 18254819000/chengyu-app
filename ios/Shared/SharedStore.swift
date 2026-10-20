import Foundation

/// App Group 共享存储：App 同步后把未来 7 天每日成语写入共享容器，小组件优先从这里读。
/// 同时保存 originalTransactionId，供 APIClient 自动带权益请求头（小组件请求 /daily/week 时也可带上）。
enum SharedStore {
    private static let weekFileName = "daily-week.json"
    private static let txIdKey = "originalTransactionId"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppConfig.appGroupID)
    }

    static var originalTransactionId: String? {
        get { sharedDefaults?.string(forKey: txIdKey) }
        set {
            if let value = newValue {
                sharedDefaults?.set(value, forKey: txIdKey)
            } else {
                sharedDefaults?.removeObject(forKey: txIdKey)
            }
        }
    }

    static func saveWeek(_ days: [DailyIdiom]) {
        guard let dir = containerURL,
              let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: dir.appendingPathComponent(weekFileName), options: .atomic)
    }

    static func loadWeek() -> [DailyIdiom] {
        guard let dir = containerURL,
              let data = try? Data(contentsOf: dir.appendingPathComponent(weekFileName)),
              let days = try? JSONDecoder().decode([DailyIdiom].self, from: data) else { return [] }
        return days
    }

    static func daily(for dateString: String) -> DailyIdiom? {
        loadWeek().first { $0.date == dateString }
    }
}
