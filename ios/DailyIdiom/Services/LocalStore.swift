import Foundation

/// App 本地持久化：成语全量 JSON 落盘 Documents；小状态（版本、位置、新角标、权益缓存）走 UserDefaults。
enum LocalStore {
    private static let defaults = UserDefaults.standard

    // MARK: 成语全量缓存（Documents/idioms-cache.json）

    private static var cacheFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("idioms-cache.json")
    }

    static func loadCachedIdioms() -> [Idiom] {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let items = try? JSONDecoder().decode([Idiom].self, from: data) else { return [] }
        return items
    }

    static func saveIdioms(_ items: [Idiom]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
    }

    // MARK: 同步与提醒状态

    /// 本地已见过的 content_version（nil = 从未同步成功）
    static var lastSeenContentVersion: Int? {
        get {
            defaults.object(forKey: "lastSeenContentVersion") == nil
                ? nil
                : defaults.integer(forKey: "lastSeenContentVersion")
        }
        set { defaults.set(newValue, forKey: "lastSeenContentVersion") }
    }

    /// 是否已完成过一次全量同步（首次安装的第一批内容不算「新增」，不弹提醒）
    static var hasCompletedFirstSync: Bool {
        get { defaults.bool(forKey: "hasCompletedFirstSync") }
        set { defaults.set(newValue, forKey: "hasCompletedFirstSync") }
    }

    // MARK: 学习位置（落点规则用）

    static var lastVisitDate: String? {
        get { defaults.string(forKey: "lastVisitDate") }
        set { defaults.set(newValue, forKey: "lastVisitDate") }
    }

    static var lastIdiomId: Int? {
        get {
            defaults.object(forKey: "lastIdiomId") == nil
                ? nil
                : defaults.integer(forKey: "lastIdiomId")
        }
        set { defaults.set(newValue, forKey: "lastIdiomId") }
    }

    // MARK: 「新」角标集合

    static var newIdiomIds: [Int] {
        get { defaults.array(forKey: "newIdiomIds") as? [Int] ?? [] }
        set { defaults.set(newValue, forKey: "newIdiomIds") }
    }

    // MARK: 权益缓存（离线时先展示，权威状态以后端为准）

    static func loadCachedEntitlement() -> EntitlementStatus? {
        guard let data = defaults.data(forKey: "cachedEntitlement"),
              let status = try? JSONDecoder().decode(EntitlementStatus.self, from: data) else { return nil }
        return status
    }

    static func saveEntitlement(_ status: EntitlementStatus) {
        guard let data = try? JSONEncoder().encode(status) else { return }
        defaults.set(data, forKey: "cachedEntitlement")
    }

    // MARK: 测试成绩（本地记录）
    // 本期成绩只存本地：每档最佳用于成绩页对比与难度页展示，累计字段为将来排行榜预留。
    // 本期不上传服务器、不做账号（排行榜留待后续版本再定身份方案）。

    /// 某档难度的历史最佳分数（difficultyKey 取 quiz_best_easy / quiz_best_medium / quiz_best_hard 的后缀）
    static func quizBestScore(difficultyKey: String) -> Int {
        defaults.integer(forKey: "quiz_best_\(difficultyKey)")
    }

    /// 记录一轮成绩并累计轮次 / 总答对数，返回本轮是否打破该档最佳
    @discardableResult
    static func recordQuizScore(difficultyKey: String, score: Int, correct: Int) -> Bool {
        let isRecord = score > quizBestScore(difficultyKey: difficultyKey)
        if isRecord {
            defaults.set(score, forKey: "quiz_best_\(difficultyKey)")
        }
        defaults.set(defaults.integer(forKey: "quiz_rounds_total") + 1, forKey: "quiz_rounds_total")
        defaults.set(defaults.integer(forKey: "quiz_correct_total") + correct, forKey: "quiz_correct_total")
        return isRecord
    }

    /// 累计测试轮次（为将来排行榜预留）
    static var quizRoundsTotal: Int {
        defaults.integer(forKey: "quiz_rounds_total")
    }

    /// 累计答对题数（为将来排行榜预留）
    static var quizCorrectTotal: Int {
        defaults.integer(forKey: "quiz_correct_total")
    }

    /// 测验单局最高分（百分制，三档取最高；Game Center 测验榜用）
    static var quizBestOverall: Int {
        max(quizBestScore(difficultyKey: "easy"),
            quizBestScore(difficultyKey: "medium"),
            quizBestScore(difficultyKey: "hard"))
    }

    // MARK: 打卡（F13）——日期集合按 yyyy-MM-dd 存；连续天数由集合按自然日推导

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

    static var checkInDates: [String] {
        get { defaults.array(forKey: "checkin_dates") as? [String] ?? [] }
        set { defaults.set(newValue, forKey: "checkin_dates") }
    }

    /// 是否曾经出现过断签（连续天数归零后又重新开始）：卷土重来成就用
    static var hasHadStreakBreak: Bool {
        get { defaults.bool(forKey: "has_had_streak_break") }
        set { defaults.set(newValue, forKey: "has_had_streak_break") }
    }

    /// 记当日打卡：返回 true = 今天新记（此前未打卡），false = 今天已打过。
    /// 断签检测：此前最后打卡日早于昨天时，标记曾经断签。
    @discardableResult
    static func recordCheckIn(date: Date = Date()) -> Bool {
        let day = dayString(date)
        var dates = checkInDates
        guard !dates.contains(day) else { return false }
        if let last = dates.max(), last < dayString(Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date) {
            hasHadStreakBreak = true
        }
        dates.append(day)
        dates.sort()
        checkInDates = dates
        return true
    }

    /// 连续天数：从今天（今日已打卡）或昨天（今日未打卡但昨日已打卡，streak 尚存活）往回数连续日；否则 0
    static var currentStreak: Int {
        let dates = Set(checkInDates)
        guard !dates.isEmpty else { return 0 }
        let cal = Calendar.current
        var cursor = Date()
        if !dates.contains(dayString(cursor)) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  dates.contains(dayString(yesterday)) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while dates.contains(dayString(cursor)) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    static var totalCheckInDays: Int { Set(checkInDates).count }

    static var hasCheckedInToday: Bool { Set(checkInDates).contains(dayString()) }

    // MARK: 已学与已读（成就计数用，去重集合）

    static var learnedIdiomIds: [Int] {
        get { defaults.array(forKey: "learned_idiom_ids") as? [Int] ?? [] }
        set { defaults.set(newValue, forKey: "learned_idiom_ids") }
    }

    static func recordLearned(id: Int) {
        var ids = learnedIdiomIds
        guard !ids.contains(id) else { return }
        ids.append(id)
        learnedIdiomIds = ids
    }

    static var storyReadIds: [Int] {
        get { defaults.array(forKey: "story_read_ids") as? [Int] ?? [] }
        set { defaults.set(newValue, forKey: "story_read_ids") }
    }

    static func recordStoryRead(id: Int) {
        var ids = storyReadIds
        guard !ids.contains(id) else { return }
        ids.append(id)
        storyReadIds = ids
    }

    // MARK: 错题本与复习（F14）

    struct MistakeInfo: Codable {
        var wrongCount: Int
        var lastWrong: String
    }

    /// 复习阶段：0 = 新错题/待复习，1 = 掌握 1 次，2 = 掌握 2 次；第 3 次掌握即清除（删除记录与错题）
    struct ReviewInfo: Codable {
        var stage: Int
        var nextDue: String
    }

    private static func loadDict<T: Codable>(_ key: String) -> [Int: T] {
        guard let data = defaults.data(forKey: key),
              let raw = try? JSONDecoder().decode([String: T].self, from: data) else { return [:] }
        var out: [Int: T] = [:]
        for (k, v) in raw { if let id = Int(k) { out[id] = v } }
        return out
    }

    private static func saveDict<T: Codable>(_ dict: [Int: T], key: String) {
        let raw = Dictionary(uniqueKeysWithValues: dict.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        defaults.set(data, forKey: key)
    }

    static func mistakeBook() -> [Int: MistakeInfo] { loadDict("mistake_book") }

    /// 记一次答错：错次 +1、最近错日更新；复习阶段归 0、次日到期
    static func recordMistake(id: Int, date: Date = Date()) {
        var dict: [Int: MistakeInfo] = loadDict("mistake_book")
        var info = dict[id] ?? MistakeInfo(wrongCount: 0, lastWrong: dayString(date))
        info.wrongCount += 1
        info.lastWrong = dayString(date)
        dict[id] = info
        saveDict(dict, key: "mistake_book")
        var reviews: [Int: ReviewInfo] = loadDict("review_state")
        let due = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        reviews[id] = ReviewInfo(stage: 0, nextDue: dayString(due))
        saveDict(reviews, key: "review_state")
    }

    static func clearMistake(id: Int) {
        var dict: [Int: MistakeInfo] = loadDict("mistake_book")
        dict.removeValue(forKey: id)
        saveDict(dict, key: "mistake_book")
    }

    /// 当日待复习 id：未清除错题中已到期的在前（错次多者靠前，同错次按最近错日倒序），
    /// 其余已到期的进阶复习按到期日升序在后；同一 id 只出现一次
    static func dueReviewIds(today: String) -> [Int] {
        let mistakes = mistakeBook()
        let reviews: [Int: ReviewInfo] = loadDict("review_state")
        let mistakeIds = mistakes.keys.filter { id in
            guard let r = reviews[id] else { return true }
            return r.nextDue <= today
        }.sorted { a, b in
            let ma = mistakes[a]!, mb = mistakes[b]!
            if ma.wrongCount != mb.wrongCount { return ma.wrongCount > mb.wrongCount }
            return ma.lastWrong > mb.lastWrong
        }
        let stagedIds = reviews.keys.filter { id in
            guard let r = reviews[id], r.stage > 0, r.nextDue <= today else { return false }
            return mistakes[id] == nil
        }.sorted { (reviews[$0]?.nextDue ?? "") < (reviews[$1]?.nextDue ?? "") }
        return mistakeIds + stagedIds
    }

    /// 复习判定：掌握了推进间隔（1 次 → 3 天后，2 次 → 7 天后，3 次 → 清除）；没掌握错次 +1、阶段归 0、次日再出现
    static func applyReviewResult(id: Int, gotIt: Bool, date: Date = Date()) {
        reviewActionsTotal += 1
        var reviews: [Int: ReviewInfo] = loadDict("review_state")
        if gotIt {
            let stage = (reviews[id]?.stage ?? 0) + 1
            if stage >= 3 {
                reviews.removeValue(forKey: id)
                saveDict(reviews, key: "review_state")
                clearMistake(id: id)
            } else {
                let days = stage == 1 ? 3 : 7
                let due = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
                reviews[id] = ReviewInfo(stage: stage, nextDue: dayString(due))
                saveDict(reviews, key: "review_state")
            }
        } else {
            recordMistake(id: id, date: date)
        }
    }

    /// 累计复习判定次数（温故知新成就用）
    static var reviewActionsTotal: Int {
        get { defaults.integer(forKey: "review_actions_total") }
        set { defaults.set(newValue, forKey: "review_actions_total") }
    }

    // MARK: 看图猜成绩（F12）与 Game Center 待上报缓存（F15）

    /// 看图常规最佳（答对数，满分 10）
    static var pictureRegularBest: Int {
        get { defaults.integer(forKey: "picture_regular_best") }
        set { defaults.set(newValue, forKey: "picture_regular_best") }
    }

    /// 看图连答最佳（单局最高连续答对数）
    static var pictureEndlessBest: Int {
        get { defaults.integer(forKey: "picture_endless_best") }
        set { defaults.set(newValue, forKey: "picture_endless_best") }
    }

    /// 看图单局内最高连对（火眼金睛成就用，不分模式）
    static var pictureBestStreak: Int {
        get { defaults.integer(forKey: "picture_best_streak") }
        set { defaults.set(newValue, forKey: "picture_best_streak") }
    }

    /// 累计看图局数（初试身手成就与测验轮次相加判断）
    static var pictureRoundsTotal: Int {
        get { defaults.integer(forKey: "picture_rounds_total") }
        set { defaults.set(newValue, forKey: "picture_rounds_total") }
    }

    /// 未登录 Game Center 时的待上报最高分（榜 ID → 分数，取最大；登录后重试，因分数只增不减，乐观清除安全）
    static var pendingScores: [String: Int] {
        get { defaults.dictionary(forKey: "gc_pending_scores") as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: "gc_pending_scores") }
    }

    static func cacheScore(board: String, value: Int) {
        var pending = pendingScores
        pending[board] = max(pending[board] ?? 0, value)
        pendingScores = pending
    }

    /// 未登录时的待上报成就进度（成就 ID → 百分比，取最大）
    static var pendingAchievements: [String: Double] {
        get { defaults.dictionary(forKey: "gc_pending_achievements") as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: "gc_pending_achievements") }
    }

    static func cacheAchievement(id: String, percent: Double) {
        var pending = pendingAchievements
        pending[id] = max(pending[id] ?? 0, percent)
        pendingAchievements = pending
    }

    /// 已上报过的成就进度（只上报增长，避免重复上报）
    static var reportedAchievements: [String: Double] {
        get { defaults.dictionary(forKey: "gc_reported_achievements") as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: "gc_reported_achievements") }
    }
}
