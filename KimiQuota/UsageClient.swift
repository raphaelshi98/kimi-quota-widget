import Foundation

struct ServerConnection {
    let baseURL: URL
    let token: String
}

enum KimiQuotaError: LocalizedError {
    case cliMissing
    case serverUnavailable
    case tokenUnavailable
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .cliMissing:
            "找不到 Kimi Code CLI，请先安装并登录 Kimi Code。"
        case .serverUnavailable:
            "无法启动本机 Kimi Code 服务。"
        case .tokenUnavailable:
            "无法读取本机服务令牌，请确认已登录 Kimi Code。"
        case .invalidResponse:
            "额度接口返回了无法识别的数据，请升级 Kimi Code 后重试。"
        case .unauthorized:
            "本机服务认证失败，请重新登录 Kimi Code。"
        case .server(let message):
            message
        }
    }
}

struct UsageClient {
    private struct Response: Decodable {
        let code: Int
        let msg: String?
        let data: Payload?
    }

    private struct Payload: Decodable {
        let kind: String
        let quota: Quota?
    }

    private struct Quota: Decodable {
        let usages: [String: Usage]
    }

    private struct Usage: Decodable {
        let usedRatio: Double
        let resetAt: Date
    }

    func fetchUsage(connection: ServerConnection) async throws -> [QuotaWindow] {
        guard connection.baseURL.scheme == "http",
              connection.baseURL.host == "127.0.0.1" else {
            throw KimiQuotaError.serverUnavailable
        }
        let url = connection.baseURL.appendingPathComponent("api/v1/oauth/usage")
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Bearer \(connection.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw KimiQuotaError.serverUnavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw KimiQuotaError.invalidResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw KimiQuotaError.unauthorized
        }
        guard http.statusCode == 200 else {
            throw KimiQuotaError.server("额度服务返回 HTTP \(http.statusCode)。")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let result = try? decoder.decode(Response.self, from: data) else {
            throw KimiQuotaError.invalidResponse
        }
        guard result.code == 0 else {
            throw KimiQuotaError.server(result.msg ?? "额度服务暂时不可用。")
        }
        guard result.data?.kind == "ok", let usages = result.data?.quota?.usages else {
            throw KimiQuotaError.invalidResponse
        }

        return usages.compactMap { id, usage in
            guard usage.usedRatio.isFinite else { return nil }
            return QuotaWindow(id: id, usedRatio: max(usage.usedRatio, 0), resetAt: usage.resetAt)
        }
        .sorted { lhs, rhs in
            let order = ["limit5h", "limit7d", "limit30d", "monthly", "limitMonthly"]
            let left = order.firstIndex(of: lhs.id) ?? order.count
            let right = order.firstIndex(of: rhs.id) ?? order.count
            return left == right ? lhs.id < rhs.id : left < right
        }
    }
}
