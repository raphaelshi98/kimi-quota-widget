import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct KimiQuotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Kimi 额度", systemImage: "chart.bar.fill") {
            MenuContentView(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}
