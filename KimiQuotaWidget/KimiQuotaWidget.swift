import Foundation
import SwiftUI
import WidgetKit

struct KimiQuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: QuotaSnapshot?
}

struct KimiQuotaProvider: TimelineProvider {
    func placeholder(in context: Context) -> KimiQuotaEntry {
        KimiQuotaEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (KimiQuotaEntry) -> Void) {
        completion(KimiQuotaEntry(date: Date(), snapshot: context.isPreview ? .preview : .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KimiQuotaEntry>) -> Void) {
        let entry = KimiQuotaEntry(date: Date(), snapshot: .load())
        let nextRefresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

@main
struct KimiQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Bundle.main.bundleIdentifier ?? "KimiQuota", provider: KimiQuotaProvider()) { entry in
            KimiQuotaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Kimi 额度")
        .description("查看 Kimi 账号的剩余额度与重置时间。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
