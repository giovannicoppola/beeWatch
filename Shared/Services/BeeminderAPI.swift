import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API key not configured. Please add your Beeminder API key in Settings."
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor BeeminderAPI {
    static let shared = BeeminderAPI()

    private let baseURL = "https://www.beeminder.com/api/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // Disable caching to always get fresh data
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    private var settings: UserSettings {
        UserSettings.shared
    }

    #if DEBUG
    /// Answers every call below instead of Beeminder when launched with `-sample YES`.
    private var sample = SampleGoals()
    #endif

    // MARK: - Account

    /// Asks Beeminder who owns `apiKey` and returns that username.
    /// Throws if Beeminder rejects the key or can't be reached.
    func verify(apiKey: String) async throws -> String {
        var components = URLComponents(string: "\(baseURL)/users/me.json")
        components?.queryItems = [URLQueryItem(name: "auth_token", value: apiKey)]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let data = try await performRequest(URLRequest(url: url))
        do {
            return try JSONDecoder().decode(UserResponse.self, from: data).username
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Goals

    func fetchGoals() async throws -> [GoalResponse] {
        #if DEBUG
        if SampleGoals.isOn { return sample.goals }
        #endif
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let endpoint = "/users/\(settings.username)/goals.json"
        let data = try await get(endpoint: endpoint)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode([GoalResponse].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchGoal(slug: String) async throws -> GoalResponse {
        #if DEBUG
        if SampleGoals.isOn, let goal = sample.goal(slug: slug) { return goal }
        #endif
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let endpoint = "/users/\(settings.username)/goals/\(slug).json"
        let data = try await get(endpoint: endpoint)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(GoalResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Datapoints

    func fetchDatapoints(goalSlug: String, count: Int = 20) async throws -> [DatapointResponse] {
        #if DEBUG
        if SampleGoals.isOn { return Array(sample.datapoints(slug: goalSlug).suffix(count)) }
        #endif
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let endpoint = "/users/\(settings.username)/goals/\(goalSlug)/datapoints.json?count=\(count)&sort=timestamp"
        let data = try await get(endpoint: endpoint)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode([DatapointResponse].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Polls the goal endpoint until Beeminder has finished recomputing its stats
    /// after a datapoint change, or until `timeout` seconds elapse.
    ///
    /// Beeminder recomputes `baremin`, `safebuf`, `losedate`, etc. asynchronously
    /// after a POST to /datapoints.json. Until that job runs, the values returned
    /// by /goals.json are stale. We consider stats fresh when `queued == false`
    /// and `updated_at` has advanced past the value we had before the mutation.
    ///
    /// Returns the latest goal response if we got one (fresh or stale on timeout),
    /// or throws if the underlying request fails.
    func waitForRecompute(
        slug: String,
        previousUpdatedAt: Double,
        timeout: TimeInterval = 8.0,
        pollInterval: TimeInterval = 0.5
    ) async throws -> GoalResponse {
        let deadline = Date().addingTimeInterval(timeout)
        var latest: GoalResponse?

        while Date() < deadline {
            let response = try await fetchGoal(slug: slug)
            latest = response
            let queued = response.queued ?? false
            let updatedAt = response.updatedAt ?? 0
            if !queued && updatedAt > previousUpdatedAt {
                return response
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        // Timed out — return whatever we last saw (may still be stale). Callers
        // can fall back to optimistic local state if needed.
        if let latest {
            return latest
        }
        return try await fetchGoal(slug: slug)
    }

    func createDatapoint(goalSlug: String, value: Double, comment: String = "", timestamp: Date? = nil) async throws -> DatapointResponse {
        #if DEBUG
        if SampleGoals.isOn { return sample.log(value, slug: goalSlug, comment: comment) }
        #endif
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let endpoint = "/users/\(settings.username)/goals/\(goalSlug)/datapoints.json"

        var params: [String: Any] = [
            "value": value,
            "comment": comment,
            "requestid": UUID().uuidString
        ]

        if let timestamp = timestamp {
            params["timestamp"] = Int(timestamp.timeIntervalSince1970)
        }

        let data = try await post(endpoint: endpoint, params: params)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(DatapointResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - HTTP Methods

    private func get(endpoint: String) async throws -> Data {
        let separator = endpoint.contains("?") ? "&" : "?"
        let urlString = "\(baseURL)\(endpoint)\(separator)auth_token=\(settings.apiKey)"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        return try await performRequest(request)
    }

    private func post(endpoint: String, params: [String: Any]) async throws -> Data {
        let urlString = "\(baseURL)\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        var queryItems = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        queryItems.append(URLQueryItem(name: "auth_token", value: settings.apiKey))
        components.queryItems = queryItems
        request.httpBody = components.query?.data(using: .utf8)

        return try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                throw APIError.httpError(httpResponse.statusCode, message)
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - API Response Models

struct UserResponse: Codable {
    let username: String
}

/// The page at beeminder.com/api/v1/auth_token.json, which users can paste whole
/// instead of copying the key out of it.
struct AuthTokenPage: Codable {
    let username: String
    let authToken: String

    enum CodingKeys: String, CodingKey {
        case username
        case authToken = "auth_token"
    }

    init?(pasted text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let page = try? JSONDecoder().decode(AuthTokenPage.self, from: data),
              !page.authToken.isEmpty else {
            return nil
        }
        self = page
    }
}

struct GoalResponse: Codable {
    let slug: String
    let title: String
    let goalType: String?
    let goaldate: Double?
    let goalval: Double?
    let rate: Double?
    let runits: String?
    let pledge: Double?
    let safebuf: Int?
    let losedate: Double?
    let thumbUrl: String?
    let graphUrl: String?
    let yaw: Int?
    let limsum: String?
    let baremin: String?
    // Stats freshness: when true, Beeminder is still recomputing this goal
    // and baremin/safebuf/losedate/limsum/etc. are stale. Wait for false.
    let queued: Bool?
    let updatedAt: Double?
    // Absolute y-axis value the goal needs to reach for one more safe day.
    // NOTE: For cumulative (kyoom) goals this is the running total to reach,
    // not the delta to enter as a single datapoint. The amount the user
    // should enter today is `safebump - curval`.
    let safebump: Double?
    // Value of the most recent datapoint (for kyoom goals: the cumulative
    // total so far; for non-kyoom goals: the latest reading).
    let curval: Double?
    // Cumulative / auto-summing goal (Do More, Do Less). When true, datapoints
    // are added to a running total; when false, each datapoint is an absolute
    // reading (e.g. weight).
    let kyoom: Bool?
    // Human-readable "need" text, e.g. "+1 within 2 days". Deprecated by
    // Beeminder but still returned; we fall back to it after `limsum`.
    let deltaText: String?

    enum CodingKeys: String, CodingKey {
        case slug, title
        case goalType = "goal_type"
        case goaldate, goalval, rate, runits, pledge, safebuf, losedate
        case thumbUrl = "thumb_url"
        case graphUrl = "graph_url"
        case yaw, limsum, baremin, queued, safebump, curval, kyoom
        case updatedAt = "updated_at"
        case deltaText = "delta_text"
    }

    func toGoal() -> Goal {
        let goal = Goal(
            slug: slug,
            title: title,
            goalType: goalType ?? "",
            rate: rate ?? 0,
            runits: runits ?? "d",
            pledge: pledge ?? 0,
            safebuf: safebuf ?? 0,
            losedate: Date(timeIntervalSince1970: losedate ?? 0),
            yaw: yaw ?? 1
        )
        goal.goaldate = goaldate.map { Date(timeIntervalSince1970: $0) }
        goal.goalval = goalval
        goal.thumbUrl = thumbUrl
        goal.graphUrl = graphUrl
        goal.limsum = limsum
        goal.baremin = baremin
        goal.queued = queued ?? false
        goal.updatedAt = updatedAt ?? 0
        goal.safebump = safebump
        goal.curval = curval
        goal.kyoom = kyoom ?? false
        goal.deltaText = deltaText
        return goal
    }
}

struct DatapointResponse: Codable {
    let id: String
    let timestamp: Double
    let daystamp: String
    let value: Double
    let comment: String?
    let updatedAt: Double?
    let requestid: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, daystamp, value, comment
        case updatedAt = "updated_at"
        case requestid
    }

    func toDatapoint(goalSlug: String) -> Datapoint {
        Datapoint(
            datapointId: id,
            goalSlug: goalSlug,
            timestamp: Date(timeIntervalSince1970: timestamp),
            daystamp: daystamp,
            value: value,
            comment: comment ?? "",
            requestId: requestid
        )
    }
}
