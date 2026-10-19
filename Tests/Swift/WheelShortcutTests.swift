import XCTest

@testable import Tangerine

final class WheelShortcutTests: XCTestCase {
  func testCommandAloneStillAllowsToolsWheel() {
    var gate = WheelShortcutGate()
    XCTAssertFalse(gate.update(mouseDown: true, commandDown: true, tabDown: false))
  }
  func testCommandTabStaysSuppressedUntilCommandRelease() {
    var gate = WheelShortcutGate()
    XCTAssertTrue(gate.update(mouseDown: true, commandDown: true, tabDown: true))
    XCTAssertTrue(gate.update(mouseDown: true, commandDown: true, tabDown: false))
    XCTAssertTrue(gate.update(mouseDown: true, commandDown: true, tabDown: true))
    XCTAssertFalse(gate.update(mouseDown: true, commandDown: false, tabDown: false))
    XCTAssertFalse(gate.update(mouseDown: true, commandDown: true, tabDown: false))
  }
  func testEndingDragResetsSuppression() {
    var gate = WheelShortcutGate()
    gate.suppress()
    XCTAssertFalse(gate.update(mouseDown: false, commandDown: true, tabDown: false))
    XCTAssertFalse(gate.update(mouseDown: true, commandDown: true, tabDown: false))
  }
  func testAppSwitchNotificationSuppressesEvenWhenTabWasConsumed() {
    var gate = WheelShortcutGate()
    gate.suppress()
    XCTAssertTrue(gate.update(mouseDown: true, commandDown: true, tabDown: false))
    XCTAssertFalse(gate.update(mouseDown: true, commandDown: false, tabDown: false))
  }
}
