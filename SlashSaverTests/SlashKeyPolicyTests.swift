import CoreGraphics
import XCTest
@testable import SlashSaver

final class SlashKeyPolicyTests: XCTestCase {
    func testPlainSlashTriggersSwitch() {
        XCTAssertTrue(SlashKeyPolicy.shouldSwitch(
            keyCode: SlashKeyPolicy.ansiSlashKeyCode,
            flags: [],
            isRepeat: false
        ))
    }

    func testShiftSlashStillTriggersSwitch() {
        XCTAssertTrue(SlashKeyPolicy.shouldSwitch(
            keyCode: SlashKeyPolicy.ansiSlashKeyCode,
            flags: .maskShift,
            isRepeat: false
        ))
    }

    func testCommandControlAndOptionSuppressSwitch() {
        for modifier: CGEventFlags in [.maskCommand, .maskControl, .maskAlternate] {
            XCTAssertFalse(SlashKeyPolicy.shouldSwitch(
                keyCode: SlashKeyPolicy.ansiSlashKeyCode,
                flags: modifier,
                isRepeat: false
            ))
        }
    }

    func testCapsLockAndFunctionDoNotSuppressSwitch() {
        XCTAssertTrue(SlashKeyPolicy.shouldSwitch(keyCode: SlashKeyPolicy.ansiSlashKeyCode, flags: .maskAlphaShift, isRepeat: false))
        XCTAssertTrue(SlashKeyPolicy.shouldSwitch(keyCode: SlashKeyPolicy.ansiSlashKeyCode, flags: .maskSecondaryFn, isRepeat: false))
    }

    func testAutorepeatDoesNotTriggerSwitch() {
        XCTAssertFalse(SlashKeyPolicy.shouldSwitch(
            keyCode: SlashKeyPolicy.ansiSlashKeyCode,
            flags: [],
            isRepeat: true
        ))
    }

    func testDifferentPhysicalKeyDoesNotTriggerSwitch() {
        XCTAssertFalse(SlashKeyPolicy.shouldSwitch(keyCode: 43, flags: [], isRepeat: false))
    }

    func testMonitorSelectsPreparedSourceBeforeReturningSlashEvent() throws {
        let inputSources = InputSourceSelectingStub()
        let monitor = SlashKeyMonitor(
            inputSources: inputSources,
            targetInputSourceID: { "com.apple.keylayout.US" }
        )
        XCTAssertTrue(monitor.prepareTargetInputSource())

        let event = try XCTUnwrap(CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(SlashKeyPolicy.ansiSlashKeyCode),
            keyDown: true
        ))
        let returnedEvent = monitor.handle(type: .keyDown, event: event)?.takeUnretainedValue()

        XCTAssertEqual(inputSources.selectedIDs, ["com.apple.keylayout.US"])
        XCTAssertEqual(
            returnedEvent?.getIntegerValueField(CGEventField.keyboardEventKeycode),
            Int64(SlashKeyPolicy.ansiSlashKeyCode)
        )
    }

    func testMonitorDoesNotSelectForAnotherPhysicalKey() throws {
        let inputSources = InputSourceSelectingStub()
        let monitor = SlashKeyMonitor(
            inputSources: inputSources,
            targetInputSourceID: { "com.apple.keylayout.US" }
        )
        XCTAssertTrue(monitor.prepareTargetInputSource())

        let event = try XCTUnwrap(CGEvent(
            keyboardEventSource: nil,
            virtualKey: 43,
            keyDown: true
        ))
        _ = monitor.handle(type: .keyDown, event: event)

        XCTAssertTrue(inputSources.selectedIDs.isEmpty)
    }

    func testLaunchShowsSettingsWhenTargetIsMissingOrMonitorCannotStart() {
        XCTAssertTrue(LaunchPolicy.shouldShowSettings(hasValidTarget: false, monitorStarted: false))
        XCTAssertTrue(LaunchPolicy.shouldShowSettings(hasValidTarget: true, monitorStarted: false))
        XCTAssertFalse(LaunchPolicy.shouldShowSettings(hasValidTarget: true, monitorStarted: true))
    }
}

private final class InputSourceSelectingStub: InputSourceSelecting {
    private(set) var preparedID: String?
    private(set) var selectedIDs: [String] = []

    func prepareInputSource(id: String) -> Bool {
        preparedID = id
        return true
    }

    func selectPreparedInputSource(id: String) -> Bool {
        guard preparedID == id else { return false }
        selectedIDs.append(id)
        return true
    }

    func clearPreparedInputSource() {
        preparedID = nil
    }
}
