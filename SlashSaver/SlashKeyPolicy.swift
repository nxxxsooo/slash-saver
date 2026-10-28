import Carbon
import CoreGraphics

enum SlashKeyPolicy {
    static let ansiSlashKeyCode = Int64(kVK_ANSI_Slash)
    static let escapeKeyCode = Int64(kVK_Escape)

    private static let ignoredModifiers: CGEventFlags = [
        .maskCommand,
        .maskControl,
        .maskAlternate,
    ]

    /// Slash always switches; Escape switches only when the user opted in, because leaving
    /// text entry in a terminal or modal editor is where single-letter shortcuts follow.
    static func shouldSwitch(
        keyCode: Int64,
        flags: CGEventFlags,
        isRepeat: Bool,
        switchOnEscape: Bool = false
    ) -> Bool {
        let isTrigger = keyCode == ansiSlashKeyCode || (switchOnEscape && keyCode == escapeKeyCode)
        return isTrigger
            && !isRepeat
            && flags.intersection(ignoredModifiers).isEmpty
    }
}
