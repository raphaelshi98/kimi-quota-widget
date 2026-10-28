import AppKit
import ServiceManagement
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Kimi 账号额度")
                    .font(.headline)
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let snapshot = store.snapshot, !snapshot.windows.isEmpty {
                ForEach(snapshot.windows) { window in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(window.displayName)
                            Spacer()
                            Text("剩余 \(percent(window.remainingRatio))")
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: window.remainingRatio)
                        Text("重置：\(window.resetAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Label("暂无额度数据", systemImage: "gauge.with.dots.needle.0percent")
                    .foregroundStyle(.secondary)
            }

            if let error = store.snapshot?.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let updatedAt = store.snapshot?.updatedAt {
                Text("更新于 \(updatedAt.formatted(date: .omitted, time: .shortened)) · 每 5 分钟刷新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("立即刷新") {
                Task { await store.refresh() }
            }
            .disabled(store.isRefreshing)

            Toggle("登录时启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    Task { await updateLaunchAtLogin(enabled) }
                }

            if let launchError {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("退出 Kimi 额度") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 310)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    @MainActor
    private func updateLaunchAtLogin(_ enabled: Bool) async {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = error.localizedDescription
        }
    }
}
