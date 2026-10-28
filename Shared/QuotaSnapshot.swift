import Foundation

struct QuotaWindow: Codable, Equatable, Identifiable {
    let id: String
    let usedRatio: Double
    let resetAt: Date

    var remainingRatio: Double {
        min(max(1 - usedRatio, 0), 1)
    }

    var displayName: String {
        switch id {
        case "limit5h": "5 小时额度"
        case "limit7d": "每周额度"
        case "limit30d", "monthly", "limitMonthly": "每月额度"
        default: id
        }
    }
}

struct QuotaSnapshot: Codable, Equatable {
    static let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? ""

    let windows: [QuotaWindow]
    let updatedAt: Date
    let errorMessage: String?

    func isStale(at date: Date = Date()) -> Bool {
        errorMessage != nil || date.timeIntervalSince(updatedAt) > 15 * 60
    }

    func save() throws {
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "无法访问 App Group 共享目录，请检查签名与 entitlements。"
            ])
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: directory.appendingPathComponent("quota-snapshot.json"), options: .atomic)
    }

    static func load() -> QuotaSnapshot? {
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }
        let url = directory.appendingPathComponent("quota-snapshot.json")
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(QuotaSnapshot.self, from: data)
    }

    static let preview = QuotaSnapshot(
        windows: [
            QuotaWindow(id: "limit5h", usedRatio: 0.32, resetAt: Date().addingTimeInterval(3600)),
            QuotaWindow(id: "limit7d", usedRatio: 0.18, resetAt: Date().addingTimeInterval(86400 * 3))
        ],
        updatedAt: Date(),
        errorMessage: nil
    )
}
