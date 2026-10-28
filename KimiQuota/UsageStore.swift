import Foundation
import OSLog
import WidgetKit

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var isRefreshing = false

    private let server = KimiLocalServer()
    private let client = UsageClient()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "KimiQuota", category: "UsageStore")
    private var refreshLoop: Task<Void, Never>?

    func start() {
        if snapshot == nil {
            snapshot = QuotaSnapshot.load()
        }
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 300_000_000_000)
                } catch {
                    break
                }
                await self.refresh()
            }
        }
    }

    func stop() {
        refreshLoop?.cancel()
        refreshLoop = nil
        server.stop()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let connection = try await server.connection()
            let windows = try await client.fetchUsage(connection: connection)
            let updated = QuotaSnapshot(windows: windows, updatedAt: Date(), errorMessage: nil)
            snapshot = updated
            try updated.save()
            logger.info("额度刷新成功，窗口数量：\(windows.count)")
        } catch {
            logger.error("额度刷新失败：\(error.localizedDescription, privacy: .public)")
            let previous = snapshot ?? QuotaSnapshot.load()
            let updated = QuotaSnapshot(
                windows: previous?.windows ?? [],
                updatedAt: previous?.updatedAt ?? .distantPast,
                errorMessage: error.localizedDescription
            )
            snapshot = updated
            try? updated.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
