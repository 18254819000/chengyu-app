import Foundation

/// 成语条目，对齐后端 fullView / lockedView。
/// 锁定条目后端只下发 id、idiom、pinyin、locked=true，其余字段一律 Optional，缺失即为 nil。
struct Idiom: Codable, Identifiable, Equatable {
    let id: Int
    let idiom: String
    let pinyin: String
    let pinyinChars: [String]?
    let definitionZh: String?
    let definitionEn: String?
    let exampleZh: String?
    let exampleEn: String?
    let sortOrder: Int?
    let status: String?
    let locked: Bool

    enum CodingKeys: String, CodingKey {
        case id, idiom, pinyin, status, locked
        case pinyinChars = "pinyin_chars"
        case definitionZh = "definition_zh"
        case definitionEn = "definition_en"
        case exampleZh = "example_zh"
        case exampleEn = "example_en"
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        idiom = try c.decode(String.self, forKey: .idiom)
        pinyin = try c.decode(String.self, forKey: .pinyin)
        pinyinChars = try c.decodeIfPresent([String].self, forKey: .pinyinChars)
        definitionZh = try c.decodeIfPresent(String.self, forKey: .definitionZh)
        definitionEn = try c.decodeIfPresent(String.self, forKey: .definitionEn)
        exampleZh = try c.decodeIfPresent(String.self, forKey: .exampleZh)
        exampleEn = try c.decodeIfPresent(String.self, forKey: .exampleEn)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }

    init(id: Int, idiom: String, pinyin: String, pinyinChars: [String]?,
         definitionZh: String?, definitionEn: String?,
         exampleZh: String?, exampleEn: String?,
         sortOrder: Int?, status: String?, locked: Bool) {
        self.id = id
        self.idiom = idiom
        self.pinyin = pinyin
        self.pinyinChars = pinyinChars
        self.definitionZh = definitionZh
        self.definitionEn = definitionEn
        self.exampleZh = exampleZh
        self.exampleEn = exampleEn
        self.sortOrder = sortOrder
        self.status = status
        self.locked = locked
    }

    /// 逐字拼音：优先用后端 pinyin_chars，缺失时按完整拼音空格拆分兜底
    var charPinyins: [String] {
        if let chars = pinyinChars, !chars.isEmpty { return chars }
        return pinyin.split(separator: " ").map(String.init)
    }
}

/// GET /idioms 分页响应
struct IdiomListResponse: Codable {
    let total: Int
    let page: Int
    let pageSize: Int
    let items: [Idiom]
}

/// 每日成语，对齐后端 dailyView（不含例句；付费条目也下发释义，与后端实现一致）
struct DailyIdiom: Codable, Equatable {
    let date: String
    let id: Int
    let idiom: String
    let pinyin: String
    let pinyinChars: [String]?
    let definitionZh: String?
    let definitionEn: String?
    let sortOrder: Int?
    let locked: Bool

    enum CodingKeys: String, CodingKey {
        case date, id, idiom, pinyin, locked
        case pinyinChars = "pinyin_chars"
        case definitionZh = "definition_zh"
        case definitionEn = "definition_en"
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        id = try c.decode(Int.self, forKey: .id)
        idiom = try c.decode(String.self, forKey: .idiom)
        pinyin = try c.decode(String.self, forKey: .pinyin)
        pinyinChars = try c.decodeIfPresent([String].self, forKey: .pinyinChars)
        definitionZh = try c.decodeIfPresent(String.self, forKey: .definitionZh)
        definitionEn = try c.decodeIfPresent(String.self, forKey: .definitionEn)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }

    init(date: String, id: Int, idiom: String, pinyin: String, pinyinChars: [String]?,
         definitionZh: String?, definitionEn: String?, sortOrder: Int?, locked: Bool) {
        self.date = date
        self.id = id
        self.idiom = idiom
        self.pinyin = pinyin
        self.pinyinChars = pinyinChars
        self.definitionZh = definitionZh
        self.definitionEn = definitionEn
        self.sortOrder = sortOrder
        self.locked = locked
    }

    /// 内置兜底条目：共享缓存与接口都不可用时保证小组件永不空白
    static func fallback(date: String) -> DailyIdiom {
        DailyIdiom(
            date: date,
            id: 1,
            idiom: "画蛇添足",
            pinyin: "huà shé tiān zú",
            pinyinChars: ["huà", "shé", "tiān", "zú"],
            definitionZh: "比喻做了多余的事，反而把事情弄糟。",
            definitionEn: "To ruin something by adding what is superfluous; to gild the lily.",
            sortOrder: 1,
            locked: false
        )
    }
}

/// GET /daily/week 响应
struct DailyWeekResponse: Codable {
    let from: String
    let days: [DailyIdiom]
}

/// GET /config 响应。商品 ID 后台未配置时为空字符串，客户端回退到 AppConfig 的默认商品 ID。
struct AppConfigResponse: Codable, Equatable {
    let freeCount: Int
    let monthlyProductId: String
    let yearlyProductId: String
    let contentVersion: Int

    enum CodingKeys: String, CodingKey {
        case freeCount = "free_count"
        case monthlyProductId = "monthly_product_id"
        case yearlyProductId = "yearly_product_id"
        case contentVersion = "content_version"
    }
}

/// 订阅权益，对齐后端 POST /subscription/verify 与 GET /subscription/status 的返回。
/// status 取值：active / grace / expired / refunded / revoked / none
struct EntitlementStatus: Codable, Equatable {
    var entitled: Bool
    var status: String
    var originalTransactionId: String?
    var productId: String?
    var expiresAt: String?
    var environment: String?

    enum CodingKeys: String, CodingKey {
        case entitled, status, originalTransactionId, environment
        case productId = "product_id"
        case expiresAt = "expires_at"
    }

    /// 到期时间（后端返回 ISO8601 字符串，兼容带毫秒与不带毫秒两种格式）
    var expiresDate: Date? {
        guard let s = expiresAt else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }

    static let none = EntitlementStatus(entitled: false, status: "none",
                                        originalTransactionId: nil, productId: nil,
                                        expiresAt: nil, environment: nil)
}
