import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore()
    private var managementWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "kimi-quota" }) else { return }
        showManagementWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showManagementWindow()
        return false
    }

    private func showManagementWindow() {
        if managementWindow == nil {
            let controller = NSHostingController(rootView: MenuContentView(store: store))
            let window = NSWindow(contentViewController: controller)
            window.title = "Kimi 额度"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 342, height: 460))
            managementWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        managementWindow?.makeKeyAndOrderFront(nil)
    }
}

@main
struct KimiQuotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            MenuContentView(store: appDelegate.store)
        }
    }
}
