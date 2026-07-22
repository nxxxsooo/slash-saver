import Carbon
import Foundation
import os

struct InputSourceInfo: Equatable {
    let id: String
    let name: String
}

protocol InputSourceSelecting: AnyObject {
    @discardableResult
    func prepareInputSource(id: String) -> Bool

    @discardableResult
    func selectPreparedInputSource(id: String) -> Bool

    func clearPreparedInputSource()
}

final class InputSourceManager: InputSourceSelecting {
    private var preparedInputSourceID: String?
    private var preparedInputSource: TISInputSource?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SlashSaver", category: "InputSource")

    func selectableASCIISources() -> [InputSourceInfo] {
        allKeyboardSources()
            .filter { source in
                booleanProperty(kTISPropertyInputSourceIsEnabled, of: source)
                    && booleanProperty(kTISPropertyInputSourceIsSelectCapable, of: source)
                    && booleanProperty(kTISPropertyInputSourceIsASCIICapable, of: source)
            }
            .compactMap(info(for:))
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    func currentInputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return stringProperty(kTISPropertyInputSourceID, of: source)
    }

    func containsSelectableASCIISource(id: String) -> Bool {
        selectableASCIISources().contains { $0.id == id }
    }

    @discardableResult
    func prepareInputSource(id targetID: String) -> Bool {
        guard let source = selectableInputSource(id: targetID) else {
            clearPreparedInputSource()
            logger.error("Configured input source is no longer selectable")
            return false
        }

        preparedInputSourceID = targetID
        preparedInputSource = source
        return true
    }

    @discardableResult
    func selectPreparedInputSource(id targetID: String) -> Bool {
        guard currentInputSourceID() != targetID else {
            return true
        }

        guard preparedInputSourceID == targetID, let preparedInputSource else {
            logger.error("Configured input source was not prepared before event monitoring")
            return false
        }

        let status = TISSelectInputSource(preparedInputSource)
        if status != noErr {
            logger.error("TISSelectInputSource failed with status \(status, privacy: .public)")
            return false
        }
        return true
    }

    func clearPreparedInputSource() {
        preparedInputSourceID = nil
        preparedInputSource = nil
    }

    private func allKeyboardSources() -> [TISInputSource] {
        let conditions = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
        ] as CFDictionary

        return TISCreateInputSourceList(conditions, false)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    private func selectableInputSource(id targetID: String) -> TISInputSource? {
        allKeyboardSources().first(where: {
            stringProperty(kTISPropertyInputSourceID, of: $0) == targetID
                && booleanProperty(kTISPropertyInputSourceIsEnabled, of: $0)
                && booleanProperty(kTISPropertyInputSourceIsSelectCapable, of: $0)
                && booleanProperty(kTISPropertyInputSourceIsASCIICapable, of: $0)
        })
    }

    private func info(for source: TISInputSource) -> InputSourceInfo? {
        guard let id = stringProperty(kTISPropertyInputSourceID, of: source),
              let name = stringProperty(kTISPropertyLocalizedName, of: source) else {
            return nil
        }
        return InputSourceInfo(id: id, name: name)
    }

    private func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func booleanProperty(_ key: CFString, of source: TISInputSource) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue() == kCFBooleanTrue
    }
}
