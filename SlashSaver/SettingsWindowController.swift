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
    private let permissionButton = NSButton(title: "授权", target: nil, action: nil)
    private let loginSwitch = NSSwitch()
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
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Slash Saver"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
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

        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
        ])

        let title = NSTextField(labelWithString: "Slash Saver")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "斜杠键触发的英文输入源")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let headerText = NSStackView(views: [title, subtitle])
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 3

        let header = NSStackView(views: [iconView, headerText])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14

        sourcePopup.controlSize = .large
        sourcePopup.setAccessibilityLabel("目标输入源")
        sourcePopup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sourcePopup.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let sourceRow = makeRow(
            title: "目标输入源",
            detail: "物理 / 键触发后使用",
            control: sourcePopup
        )

        permissionImage.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        permissionImage.setContentHuggingPriority(.required, for: .horizontal)
        permissionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        permissionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        permissionButton.target = self
        permissionButton.action = #selector(requestPermission)
        permissionButton.setAccessibilityLabel("授予输入监控权限")
        permissionButton.bezelStyle = .rounded
        permissionButton.widthAnchor.constraint(equalToConstant: 86).isActive = true

        let permissionControl = NSStackView(views: [permissionImage, permissionLabel, permissionButton])
        permissionControl.orientation = .horizontal
        permissionControl.alignment = .centerY
        permissionControl.spacing = 8
        permissionControl.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let permissionRow = makeRow(
            title: "输入监控",
            detail: "系统只读监听权限",
            control: permissionControl
        )

        loginSwitch.target = self
        loginSwitch.action = #selector(loginSwitchChanged)
        loginSwitch.setAccessibilityLabel("登录时启动")
        loginStatusLabel.font = .systemFont(ofSize: 13)
        loginStatusLabel.textColor = .secondaryLabelColor

        let loginSpacer = NSView()
        loginSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let loginControl = NSStackView(views: [loginStatusLabel, loginSpacer, loginSwitch])
        loginControl.orientation = .horizontal
        loginControl.alignment = .centerY
        loginControl.spacing = 8
        loginControl.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let loginRow = makeRow(
            title: "登录时启动",
            detail: "后台静默保持可用",
            control: loginControl
        )

        let settingsStack = NSStackView(views: [
            sourceRow,
            makeSeparator(),
            permissionRow,
            makeSeparator(),
            loginRow,
        ])
        settingsStack.orientation = .vertical
        settingsStack.alignment = .leading
        settingsStack.spacing = 0

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.maximumNumberOfLines = 1
        errorLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        errorLabel.isHidden = true

        let quitButton = NSButton(title: "退出应用", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.bezelStyle = .rounded
        let saveButton = NSButton(title: "保存设置", target: self, action: #selector(saveAndClose))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded

        let buttonSpacer = NSView()
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [quitButton, buttonSpacer, saveButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        let root = NSStackView(views: [header, makeSeparator(), settingsStack, errorLabel, buttons])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.setCustomSpacing(18, after: header)
        root.setCustomSpacing(10, after: root.arrangedSubviews[1])
        root.setCustomSpacing(8, after: settingsStack)
        root.setCustomSpacing(8, after: errorLabel)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        for view in [header, root.arrangedSubviews[1], settingsStack, errorLabel, buttons] {
            view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            root.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18),
        ])
    }

    private func makeRow(title: String, detail: String, control: NSView) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .tertiaryLabelColor

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.widthAnchor.constraint(equalToConstant: 176).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [labels, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 20
        row.heightAnchor.constraint(equalToConstant: 58).isActive = true
        return row
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
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

        loginSwitch.state = loginItem.isRegistered || preferences.targetInputSourceID == nil ? .on : .off
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
        permissionLabel.stringValue = granted ? "已授权" : "需要授权"
        permissionButton.title = granted ? "已授权" : "授权"
        permissionButton.isEnabled = !granted
        permissionButton.isHidden = granted
        if granted, !monitor.start(), monitor.state == .failed {
            showError("无法启动按键监控。请退出 Slash Saver 后重试。")
        }
    }

    private func refreshLoginStatus() {
        switch loginItem.state {
        case .disabled:
            loginStatusLabel.stringValue = "关闭"
        case .enabled:
            loginStatusLabel.stringValue = "已启用"
        case .requiresApproval:
            loginStatusLabel.stringValue = "等待系统批准"
        case .unavailable:
            loginStatusLabel.stringValue = "不可用"
        }
    }

    @objc private func requestPermission() {
        _ = CGRequestListenEventAccess()
        refreshPermissionStatus()
    }

    @objc private func loginSwitchChanged() {
        do {
            try loginItem.setEnabled(loginSwitch.state == .on)
            refreshLoginStatus()
            showError(nil)
            if loginItem.state == .requiresApproval {
                loginItem.openSystemSettings()
            }
        } catch {
            loginSwitch.state = loginItem.isRegistered ? .on : .off
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
            try loginItem.setEnabled(loginSwitch.state == .on)
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
