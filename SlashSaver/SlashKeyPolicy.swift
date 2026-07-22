import Carbon
import CoreGraphics

enum SlashKeyPolicy {
    static let ansiSlashKeyCode = Int64(kVK_ANSI_Slash)

    private static let ignoredModifiers: CGEventFlags = [
        .maskCommand,
        .maskControl,
        .maskAlternate,
    ]

    static func shouldSwitch(
        keyCode: Int64,
        flags: CGEventFlags,
        isRepeat: Bool
    ) -> Bool {
        keyCode == ansiSlashKeyCode
            && !isRepeat
            && flags.intersection(ignoredModifiers).isEmpty
    }
}
