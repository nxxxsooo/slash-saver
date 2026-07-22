import AppKit
import CoreGraphics

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let preferences: AppPreferences
    private let inputSources: InputSourceManager
    private let loginItem: LoginItemController
    private let monitor: SlashKeyMonitor

    private let sourcePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let permissionImage = NSImageView()
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "授予权限", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "登录时启动", target: nil, action: nil)
    private let loginStatusLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private var permissionTimer: Timer?
    private var sources: [InputSourceInfo] = []

    init(
        preferences: AppPreferences,
        inputSources: InputSourceManager,
        loginItem: LoginItemController,
        monitor: SlashKeyMonitor
    ) {
        self.preferences = preferences
        self.inputSources = inputSources
        self.loginItem = loginItem
        self.monitor = monitor

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 326),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Slash Saver 设置"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        permissionTimer?.invalidate()
    }

    override func showWindow(_ sender: Any?) {
        reload()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        startPermissionRefresh()
    }

    func windowWillClose(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Slash Saver")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let sourceLabel = NSTextField(labelWithString: "目标输入源")
        sourceLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        sourcePopup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let sourceRow = NSStackView(views: [sourceLabel, sourcePopup])
        sourceRow.orientation = .horizontal
        sourceRow.alignment = .centerY
        sourceRow.spacing = 16

        permissionImage.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        permissionImage.setContentHuggingPriority(.required, for: .horizontal)
        permissionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        permissionButton.target = self
        permissionButton.action = #selector(requestPermission)

        let permissionRow = NSStackView(views: [permissionImage, permissionLabel, permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 8

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginCheckboxChanged)

        loginStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        loginStatusLabel.textColor = .secondaryLabelColor

        let loginRow = NSStackView(views: [loginCheckbox, loginStatusLabel])
        loginRow.orientation = .horizontal
        loginRow.alignment = .centerY
        loginRow.spacing = 8

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.isHidden = true

        let quitButton = NSButton(title: "退出", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [quitButton, spacer, saveButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        let stack = NSStackView(views: [title, sourceRow, permissionRow, loginRow, errorLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        sourceRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        permissionRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sourcePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
        ])
    }

    private func reload() {
        sources = inputSources.selectableASCIISources()
        sourcePopup.removeAllItems()
        sourcePopup.addItems(withTitles: sources.map(\.name))

        let selectedID = preferences.targetInputSourceID ?? inputSources.currentInputSourceID()
        if let selectedID, let index = sources.firstIndex(where: { $0.id == selectedID }) {
            sourcePopup.selectItem(at: index)
        } else if !sources.isEmpty {
            sourcePopup.selectItem(at: 0)
        }
        sourcePopup.isEnabled = !sources.isEmpty

        loginCheckbox.state = loginItem.isRegistered || preferences.targetInputSourceID == nil ? .on : .off
        showError(nil)
        refreshLoginStatus()
        refreshPermissionStatus()
    }

    private func startPermissionRefresh() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
            self?.refreshLoginStatus()
        }
    }

    private func refreshPermissionStatus() {
        let granted = CGPreflightListenEventAccess()
        permissionImage.image = NSImage(
            systemSymbolName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            accessibilityDescription: nil
        )
        permissionImage.contentTintColor = granted ? .systemGreen : .systemOrange
        permissionLabel.stringValue = granted ? "输入监控已授权" : "需要输入监控权限"
        permissionButton.title = granted ? "已授权" : "授予权限"
        permissionButton.isEnabled = !granted
        if granted {
            if !monitor.start(), monitor.state == .failed {
                showError("无法启动按键监控。请退出 Slash Saver 后重试。")
            }
        }
    }

    private func refreshLoginStatus() {
        switch loginItem.state {
        case .disabled:
            loginStatusLabel.stringValue = ""
        case .enabled:
            loginStatusLabel.stringValue = "已启用"
        case .requiresApproval:
            loginStatusLabel.stringValue = "等待系统批准"
        case .unavailable:
            loginStatusLabel.stringValue = "尚未注册"
        }
    }

    @objc private func requestPermission() {
        _ = CGRequestListenEventAccess()
        refreshPermissionStatus()
    }

    @objc private func loginCheckboxChanged() {
        do {
            try loginItem.setEnabled(loginCheckbox.state == .on)
            refreshLoginStatus()
            showError(nil)
            if loginItem.state == .requiresApproval {
                loginItem.openSystemSettings()
            }
        } catch {
            loginCheckbox.state = loginItem.isRegistered ? .on : .off
            showError("无法更新登录启动：\(error.localizedDescription)")
        }
    }

    @objc private func saveAndClose() {
        let selectedIndex = sourcePopup.indexOfSelectedItem
        guard sources.indices.contains(selectedIndex) else {
            showError("没有可选的 ASCII 输入源。请先在系统设置中启用一个输入源。")
            return
        }

        do {
            try loginItem.setEnabled(loginCheckbox.state == .on)
            refreshLoginStatus()
        } catch {
            showError("无法更新登录启动：\(error.localizedDescription)")
            return
        }

        preferences.targetInputSourceID = sources[selectedIndex].id
        monitor.stop()
        guard monitor.start() else {
            switch monitor.state {
            case .permissionRequired:
                showError("输入监控尚未授权。请先授予权限，再保存设置。")
            case .failed:
                showError("无法启动按键监控。请退出 Slash Saver 后重试。")
            case .stopped, .running:
                showError("无法启动按键监控。")
            }
            return
        }
        showError(nil)
        close()
    }

    private func showError(_ message: String?) {
        errorLabel.stringValue = message ?? ""
        errorLabel.isHidden = message == nil
    }
}
