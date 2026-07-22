import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let preferences = AppPreferences()
    private let inputSources = InputSourceManager()
    private let loginItem = LoginItemController()
    private lazy var monitor = SlashKeyMonitor(
        inputSources: inputSources,
        targetInputSourceID: { [weak preferences] in preferences?.targetInputSourceID }
    )
    private lazy var settingsWindow = SettingsWindowController(
        preferences: preferences,
        inputSources: inputSources,
        loginItem: loginItem,
        monitor: monitor
    )
    private var finishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard !isRunningTests else { return }

        installMainMenu()
        finishedLaunching = true

        let hasValidTarget = preferences.targetInputSourceID.map(
            inputSources.containsSelectableASCIISource(id:)
        ) ?? false
        let monitorStarted = hasValidTarget && monitor.start()
        if LaunchPolicy.shouldShowSettings(
            hasValidTarget: hasValidTarget,
            monitorStarted: monitorStarted
        ) {
            settingsWindow.showWindow(nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard finishedLaunching,
              settingsWindow.window?.isVisible != true else { return }
        settingsWindow.showWindow(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.showWindow(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    @objc private func showSettings(_ sender: Any?) {
        settingsWindow.showWindow(sender)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "设置…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Slash Saver", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}

enum LaunchPolicy {
    static func shouldShowSettings(hasValidTarget: Bool, monitorStarted: Bool) -> Bool {
        !hasValidTarget || !monitorStarted
    }
}
