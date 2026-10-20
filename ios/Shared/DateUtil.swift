import Foundation

/// 日期工具：日期字符串统一 yyyy-MM-dd。
/// 每日轮换与后端同一公式：天数差按 UTC 计算（与设备时区无关），保证 App / 小组件 / 后端结果一致。
enum DateUtil {
    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// 设备本地日期字符串（业务口径：按用户本地日期计算当日成语）
    static func string(from date: Date) -> String {
        formatter(timeZone: .current).string(from: date)
    }

    static func todayString() -> String {
        string(from: Date())
    }

    /// 日期字符串 -> 当地 0 点
    static func date(fromString s: String) -> Date? {
        formatter(timeZone: .current).date(from: s)
    }

    /// 目标日期距基准日 2026-01-01 的天数（用 UTC 日历计算，与后端 dateToDays 一致）
    static func daysSinceBase(_ s: String) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let f = formatter(timeZone: TimeZone(secondsFromGMT: 0)!)
        guard let target = f.date(from: s), let base = f.date(from: "2026-01-01") else { return 0 }
        let days = cal.dateComponents([.day], from: base, to: target).day ?? 0
        return days
    }

    /// 离线兜底：与后端相同的轮换公式，从本地缓存列表算某日的每日成语下标
    static func dailyIndex(dateString: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let days = daysSinceBase(dateString)
        return ((days % count) + count) % count
    }

    /// 中文展示日期，如「10月20日 周二」
    static func displayString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f.string(from: date)
    }
}
