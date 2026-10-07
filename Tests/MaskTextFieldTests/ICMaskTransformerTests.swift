import XCTest
@testable import MaskTextField

final class ICMaskTransformerTests: XCTestCase {

    private var mock: MockMaskTextField!
    private var transformer: ICMaskTransformer!

    override func setUp() {
        super.setUp()
        mock = MockMaskTextField()
        transformer = ICMaskTransformer(textField: mock)
    }

    override func tearDown() {
        transformer = nil
        mock = nil
        super.tearDown()
    }

    // MARK: - Отображение маски

    func testVisibleMaskRendersPlaceholders() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        XCTAssertEqual(transformer.visibleTextMask, "+375 (__) ___-__-__")
        XCTAssertEqual(mock.text, "+375 (__) ___-__-__")
        XCTAssertEqual(transformer.text, "")
    }

    func testCustomMaskChar() {
        transformer.mask = "dd/dd"
        transformer.maskChar = "#"

        XCTAssertEqual(mock.text, "##/##")
    }

    func testEscapedMaskCharIsLiteral() {
        transformer.mask = "\\ddd"
        // \d — литеральная 'd', остальные два — вводимые цифры
        XCTAssertEqual(transformer.visibleTextMask, "d__")
        XCTAssertEqual(transformer.onlyEnteredCount, 2)
    }

    // MARK: - Ввод

    func testEnterDigitsBuildsMaskedText() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        "123456789".forEach { _ = transformer.onTextInput("\($0)") }

        XCTAssertEqual(mock.text, "+375 (12) 345-67-89")
        XCTAssertEqual(transformer.text, "123456789")
    }

    func testInvalidCharacterIsRejected() {
        transformer.mask = "dd"

        XCTAssertFalse(transformer.onTextInput("a"))
        XCTAssertEqual(transformer.text, "")

        XCTAssertTrue(transformer.onTextInput("7"))
        XCTAssertEqual(transformer.text, "7")
        XCTAssertEqual(mock.text, "7_")
    }

    func testMaskIsFullWhenAllCharactersEntered() {
        transformer.mask = "dd"

        _ = transformer.onTextInput("1")
        _ = transformer.onTextInput("2")

        // Маска заполнена — больше вводить некуда.
        XCTAssertFalse(transformer.onTextInput("3"))
        XCTAssertEqual(transformer.text, "12")
    }

    // MARK: - Удаление

    func testDeleteBackwardRemovesLastEnteredCharacter() {
        transformer.mask = "dd-dd"

        _ = transformer.onTextInput("1")
        _ = transformer.onTextInput("2")
        _ = transformer.onTextInput("3")

        XCTAssertEqual(transformer.text, "123")
        XCTAssertEqual(mock.text, "12-3_")

        transformer.onDeleteBackward()

        XCTAssertEqual(transformer.text, "12")
        XCTAssertEqual(mock.text, "12-__")
    }

    func testDeleteBackwardOnEmptyMaskIsNoop() {
        transformer.mask = "dd"

        transformer.onDeleteBackward()

        XCTAssertEqual(transformer.text, "")
        XCTAssertEqual(mock.text, "__")
    }

    // MARK: - Количество вводимых позиций

    func testOnlyEnteredCount() {
        transformer.mask = "+375 (dd) ddd-dd-dd"
        XCTAssertEqual(transformer.onlyEnteredCount, 9)
    }

    // MARK: - Режимы отображения

    func testGradualMaskShowsOnlyEnteredPrefix() {
        transformer.mask = "+375 (dd) ddd-dd-dd"
        transformer.maskMode = .gradualMask

        _ = transformer.onTextInput("1")

        XCTAssertEqual(mock.text, "+375 (1")
    }

    func testFullMaskAlwaysShowsWholeMask() {
        transformer.mask = "+375 (dd) ddd-dd-dd"
        transformer.maskMode = .fullMask

        _ = transformer.onTextInput("1")

        XCTAssertEqual(mock.text, "+375 (1_) ___-__-__")
    }

    func testCursorPositionMovesToFirstEmptyPosition() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        _ = transformer.onTextInput("2")

        // Первая вводимая позиция (индекс 6) занята, курсор — на следующей (индекс 7).
        XCTAssertEqual(mock.cursorPosition, 7)
    }

    // MARK: - Скрытие символов при потере фокуса

    func testVeiledCharactersAreHiddenOnLostFocus() {
        transformer.mask = "+3 (^d^d)"

        transformer.onGotFocus()
        _ = transformer.onTextInput("1")
        _ = transformer.onTextInput("2")

        XCTAssertEqual(mock.text, "+3 (12)")

        transformer.onLostFocus()

        XCTAssertEqual(mock.text, "+3 (••)")
    }

    // MARK: - Установка значения без маски

    func testSetTextValuePopulatesMask() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        transformer.text = "123456789"

        // Установка значения перерисовывает маску асинхронно.
        let expectation = expectation(description: "mask redrawn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.transformer.text, "123456789")
            XCTAssertEqual(self.mock.text, "+375 (12) 345-67-89")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}

final class SupportUtilitiesTests: XCTestCase {

    func testForwardApplicationOperator() {
        let formatter = NumberFormatter() => {
            $0.numberStyle = .decimal
            $0.decimalSeparator = "."
        }

        XCTAssertEqual(formatter.decimalSeparator, ".")
        XCTAssertEqual(formatter.numberStyle, .decimal)
    }

    func testSubstringIsBoundsSafe() {
        XCTAssertEqual("12345".substring(start: 1, length: 2), "23")
        XCTAssertEqual("12345".substring(start: 0, length: 5), "12345")
        XCTAssertEqual("12345".substring(start: 0, length: 99), "12345")
        XCTAssertEqual("12345".substring(start: 99, length: 5), "")
        XCTAssertEqual("12345".substring(start: -1, length: 2), "")
    }
}
