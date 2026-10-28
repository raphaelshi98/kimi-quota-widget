import SwiftUI
import WidgetKit

struct KimiQuotaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KimiQuotaEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, !snapshot.windows.isEmpty {
                switch family {
                case .systemSmall:
                    SmallQuotaView(snapshot: snapshot)
                default:
                    MediumQuotaView(snapshot: snapshot)
                }
            } else {
                QuotaErrorView(message: entry.snapshot?.errorMessage)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.075, green: 0.09, blue: 0.14), Color(red: 0.12, green: 0.15, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(URL(string: "kimi-quota://manage"))
    }
}

private struct SmallQuotaView: View {
    let snapshot: QuotaSnapshot

    private var window: QuotaWindow? {
        snapshot.windows.max(by: { $0.usedRatio < $1.usedRatio })
    }

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Kimi 额度")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    if snapshot.isStale() {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(window.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: window.remainingRatio)
                        .stroke(color(for: window), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(percent(window.remainingRatio))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("剩余")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .padding(.top, 8)

                HStack(spacing: 3) {
                    Text("重置 ·")
                    Text(window.resetAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Text("更新于 \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 3)

                Spacer(minLength: 0)
            }
        }
    }
}

private struct MediumQuotaView: View {
    let snapshot: QuotaSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Kimi 额度")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if snapshot.isStale() {
                    Label("可能过期", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 18) {
                ForEach(snapshot.windows) { window in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(window.displayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                        Text(percent(window.remainingRatio))
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        ProgressView(value: window.remainingRatio)
                            .tint(color(for: window))
                        HStack(spacing: 3) {
                            Text("重置 ·")
                            Text(window.resetAt, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)

            Text("更新于 \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

private struct QuotaErrorView: View {
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("暂时无法读取 Kimi 额度")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(message ?? "请打开菜单栏中的 Kimi 额度，并确认已登录 Kimi Code。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

private func color(for window: QuotaWindow) -> Color {
    switch window.usedRatio {
    case 0.9...: .red
    case 0.75...: .orange
    default: Color(red: 0.25, green: 0.85, blue: 0.65)
    }
}
