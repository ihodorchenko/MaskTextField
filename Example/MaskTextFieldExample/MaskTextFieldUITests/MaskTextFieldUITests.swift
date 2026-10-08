import XCTest

/// UI tests of the example app: they drive the real keyboard, taps and the UIKit editing cycle,
/// which the package unit tests (that call the delegate directly) cannot cover.
///
/// What is observable from outside: the raw value shown next to each field, the "mask is filled"
/// label, and the field's accessibility value (entered characters separated by spaces, without
/// the mask placeholders). The mask layout itself is not observable, so mask switching is checked
/// through its capacity (how many characters the field accepts).
final class MaskTextFieldUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Free (phone)

    func testTypingFillsTheMaskAndReportsCompletion() {
        let phone = field("phone")

        tap(phone, atStart: true)
        app.typeText("291234567")

        XCTAssertEqual(enteredCharacters(in: phone), "291234567")
        XCTAssertEqual(rawValue("phoneValue"), "291234567")
        XCTAssertEqual(rawValue("phoneComplete"), "да")
    }

    func testBackspaceRemovesTheLastCharacter() {
        let phone = field("phone")
        tap(phone, atStart: true)
        app.typeText("291234567")

        app.typeText(XCUIKeyboardKey.delete.rawValue)

        XCTAssertEqual(enteredCharacters(in: phone), "29123456")
        XCTAssertEqual(rawValue("phoneValue"), "29123456")
        XCTAssertEqual(rawValue("phoneComplete"), "нет")
    }

    func testMoreInputThanTheMaskHoldsIsRejected() {
        let phone = field("phone")
        tap(phone, atStart: true)

        app.typeText("2912345678")   // ten digits, the mask holds nine

        XCTAssertEqual(rawValue("phoneValue"), "291234567")
    }

    // MARK: - Cursor behaviors

    func testFreeFieldBackspaceAtTheStartDeletesNothing() {
        let card = field("freeCard")
        tap(card, atStart: true)
        app.typeText("1234")

        tap(card, atStart: true)
        app.typeText(XCUIKeyboardKey.delete.rawValue)

        XCTAssertEqual(rawValue("freeCardValue"), "1234")
    }

    func testSequentialFieldBackspaceAlwaysErasesFromTheEnd() {
        let card = field("sequentialCard")
        tap(card, atStart: true)
        app.typeText("1234")

        // Tapping at the start cannot move the cursor: erasing still happens from the end.
        tap(card, atStart: true)
        app.typeText(XCUIKeyboardKey.delete.rawValue)

        XCTAssertEqual(rawValue("sequentialCardValue"), "123")
    }

    func testSnapOnFocusPutsTheFirstTapOnTheFirstFreePositionThenMovesFreely() {
        let card = field("snapCard")
        tap(card, atStart: true)
        app.typeText("1234")

        // Move focus to another field, then tap the start of this one: the first tap snaps to
        // the end of the value, so backspace removes the last character.
        tap(field("sequentialCard"), atStart: true)
        tap(card, atStart: true)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(rawValue("snapCardValue"), "123")

        // A second tap in the same focus session moves the cursor freely: at the start there is
        // nothing to erase.
        tap(card, atStart: true)
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(rawValue("snapCardValue"), "123")
    }

    // MARK: - Dynamic mask

    func testAmexCardMaskAcceptsFifteenDigits() {
        let card = field("dynamicCard")
        tap(card, atStart: true)

        app.typeText("371234567812345")   // 15 digits starting with 37: the Amex mask
        app.typeText("9")                 // the Amex mask is full, a sixteenth digit is rejected

        XCTAssertEqual(rawValue("dynamicCardValue"), "371234567812345")
    }

    func testOtherCardsAcceptSixteenDigits() {
        let card = field("dynamicCard")
        tap(card, atStart: true)

        app.typeText("4111111111111111")  // 16 digits
        app.typeText("9")                 // the 16-digit mask is full

        XCTAssertEqual(rawValue("dynamicCardValue"), "4111111111111111")
    }

    // MARK: - Helpers

    /// Finds a text field, scrolling the form until it exists (rows below the fold are not created).
    private func field(_ identifier: String) -> XCUIElement {
        let element = app.textFields[identifier]
        for _ in 0..<8 where !element.exists || !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "text field \(identifier) not found")
        return element
    }

    /// The text after the label in a combined "label, value" accessibility element.
    private func rawValue(_ identifier: String) -> String {
        let element = app.staticTexts[identifier]
        for _ in 0..<8 where !element.exists {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "label \(identifier) not found")
        return element.label.components(separatedBy: ", ").last ?? element.label
    }

    /// The field's accessibility value without separators: the entered characters.
    private func enteredCharacters(in field: XCUIElement) -> String {
        ((field.value as? String) ?? "").replacingOccurrences(of: " ", with: "")
    }

    /// Taps near the left edge of the field's text, where a native tap would put the cursor first.
    private func tap(_ element: XCUIElement, atStart: Bool) {
        element.coordinate(withNormalizedOffset: CGVector(dx: atStart ? 0.02 : 0.5, dy: 0.5)).tap()
    }
}
