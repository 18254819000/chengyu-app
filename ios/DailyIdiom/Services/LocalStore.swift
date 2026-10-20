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
}
