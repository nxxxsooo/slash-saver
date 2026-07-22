import CoreGraphics
import Foundation
import os

final class SlashKeyMonitor {
    enum State: Equatable {
        case stopped
        case permissionRequired
        case running
        case failed
    }

    private let inputSources: InputSourceSelecting
    private let targetInputSourceID: () -> String?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SlashSaver", category: "Keyboard")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var preparedTargetInputSourceID: String?

    private(set) var state = State.stopped {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }

    var onStateChange: ((State) -> Void)?

    init(
        inputSources: InputSourceSelecting,
        targetInputSourceID: @escaping () -> String?
    ) {
        self.inputSources = inputSources
        self.targetInputSourceID = targetInputSourceID
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        if eventTap != nil {
            state = .running
            return true
        }

        guard CGPreflightListenEventAccess() else {
            state = .permissionRequired
            return false
        }

        guard prepareTargetInputSource() else {
            state = .failed
            return false
        }

        let callbackInfo = Unmanaged.passUnretained(self).toOpaque()
        let eventMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<SlashKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: callbackInfo
        )

        guard let eventTap else {
            preparedTargetInputSourceID = nil
            inputSources.clearPreparedInputSource()
            logger.error("Unable to create passive event tap")
            state = .failed
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        state = .running
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        preparedTargetInputSourceID = nil
        inputSources.clearPreparedInputSource()
        state = .stopped
    }

    @discardableResult
    func prepareTargetInputSource() -> Bool {
        guard let targetID = targetInputSourceID(), inputSources.prepareInputSource(id: targetID) else {
            preparedTargetInputSourceID = nil
            return false
        }

        preparedTargetInputSourceID = targetID
        return true
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        guard SlashKeyPolicy.shouldSwitch(
            keyCode: keyCode,
            flags: event.flags,
            isRepeat: isRepeat
        ) else {
            return Unmanaged.passUnretained(event)
        }

        if let targetID = preparedTargetInputSourceID {
            inputSources.selectPreparedInputSource(id: targetID)
        }
        return Unmanaged.passUnretained(event)
    }
}
