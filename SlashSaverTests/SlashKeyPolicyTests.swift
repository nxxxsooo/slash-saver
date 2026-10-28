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

    func testEscapeSwitchesOnlyWhenEnabled() {
        let escape = SlashKeyPolicy.escapeKeyCode
        XCTAssertFalse(SlashKeyPolicy.shouldSwitch(keyCode: escape, flags: [], isRepeat: false))
        XCTAssertTrue(SlashKeyPolicy.shouldSwitch(keyCode: escape, flags: [], isRepeat: false, switchOnEscape: true))
        XCTAssertFalse(SlashKeyPolicy.shouldSwitch(keyCode: escape, flags: .maskCommand, isRepeat: false, switchOnEscape: true))
        XCTAssertFalse(SlashKeyPolicy.shouldSwitch(keyCode: escape, flags: [], isRepeat: true, switchOnEscape: true))
    }

    func testMonitorSelectsOnEscapeWhenEnabled() throws {
        let inputSources = InputSourceSelectingStub()
        let monitor = SlashKeyMonitor(
            inputSources: inputSources,
            targetInputSourceID: { "com.apple.keylayout.US" },
            switchOnEscape: { true }
        )
        XCTAssertTrue(monitor.prepareTargetInputSource())

        let event = try XCTUnwrap(CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(SlashKeyPolicy.escapeKeyCode),
            keyDown: true
        ))
        _ = monitor.handle(type: .keyDown, event: event)

        XCTAssertEqual(inputSources.selectedIDs, ["com.apple.keylayout.US"])
    }

    func testInputSourceCommandParsesOnlyItsOwnArguments() {
        XCTAssertNil(InputSourceCommand.parse([]))
        XCTAssertNil(InputSourceCommand.parse(["-NSDocumentRevisionsDebugMode", "YES"]))
        XCTAssertEqual(InputSourceCommand.parse(["input-source", "current"]), .success(.current))
        XCTAssertEqual(InputSourceCommand.parse(["input-source", "ascii"]), .success(.ascii))
        XCTAssertEqual(
            InputSourceCommand.parse(["input-source", "select", "com.apple.keylayout.US"]),
            .success(.select("com.apple.keylayout.US"))
        )
        for bad in [["input-source"], ["input-source", "select"], ["input-source", "select", ""], ["input-source", "nope"]] {
            XCTAssertEqual(InputSourceCommand.parse(bad), .failure(InputSourceCommand.UsageError()), "\(bad)")
        }
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
