import Foundation

enum APIError: Error {
    case badStatus(Int)
    /// 详情接口 403：该成语为订阅内容且当前无权益
    case forbidden
    case transport(Error)
    case decoding(Error)
}

/// 后端接口客户端。所有请求自动带 x-original-transaction-id 头（存在时）。
struct APIClient {
    var baseURL: URL = AppConfig.apiBaseURL
    var session: URLSession = .shared

    private func makeRequest(path: String, method: String,
                             query: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        let urlString = baseURL.absoluteString + AppConfig.apiPrefix + path
        guard var comps = URLComponents(string: urlString) else { throw APIError.badStatus(-1) }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw APIError.badStatus(-1) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        if let txId = SharedStore.originalTransactionId, !txId.isEmpty {
            req.setValue(txId, forHTTPHeaderField: "x-original-transaction-id")
        }
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.badStatus(-1) }
        if http.statusCode == 403 { throw APIError.forbidden }
        guard (200..<300).contains(http.statusCode) else { throw APIError.badStatus(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await send(makeRequest(path: path, method: "GET", query: query))
    }

    // MARK: - 业务接口

    func fetchConfig() async throws -> AppConfigResponse {
        try await get("/config")
    }

    func fetchIdiomsPage(page: Int, pageSize: Int, query: String?) async throws -> IdiomListResponse {
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            // 新免费模型：锁定以后端算出的当日成语为准，App 传本地当日日期，避免时区不一致
            URLQueryItem(name: "today", value: DateUtil.todayString()),
        ]
        if let q = query, !q.isEmpty {
            items.append(URLQueryItem(name: "q", value: q))
        }
        return try await get("/idioms", query: items)
    }

    /// 拉全部已发布成语（后端 pageSize 上限 200，循环翻页取完）
    func fetchAllIdioms(query: String? = nil) async throws -> [Idiom] {
        var all: [Idiom] = []
        var page = 1
        while true {
            let resp = try await fetchIdiomsPage(page: page, pageSize: 200, query: query)
            all.append(contentsOf: resp.items)
            if all.count >= resp.total || resp.items.isEmpty { break }
            page += 1
        }
        return all
    }

    func fetchIdiom(id: Int) async throws -> Idiom {
        try await get("/idioms/\(id)", query: [URLQueryItem(name: "today", value: DateUtil.todayString())])
    }

    func fetchDaily(date: String) async throws -> DailyIdiom {
        try await get("/daily", query: [
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "today", value: DateUtil.todayString()),
        ])
    }

    func fetchDailyWeek(from: String) async throws -> [DailyIdiom] {
        let resp: DailyWeekResponse = try await get("/daily/week",
                                                     query: [
                                                        URLQueryItem(name: "from", value: from),
                                                        URLQueryItem(name: "today", value: DateUtil.todayString()),
                                                     ])
        return resp.days
    }

    /// 提交 StoreKit 2 签名交易（JWS），后端校验后返回最新权益
    func verifyTransaction(jws: String) async throws -> EntitlementStatus {
        let body = try JSONSerialization.data(withJSONObject: ["jws": jws])
        return try await send(makeRequest(path: "/subscription/verify", method: "POST", body: body))
    }

    func fetchEntitlementStatus(originalTransactionId: String) async throws -> EntitlementStatus {
        try await get("/subscription/status",
                      query: [URLQueryItem(name: "originalTransactionId", value: originalTransactionId)])
    }
}
