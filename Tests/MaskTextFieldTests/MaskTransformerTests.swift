import XCTest
@testable import MaskTextField

final class MaskTransformerTests: XCTestCase {

    private var mock: MockMaskTextField!
    private var transformer: MaskTransformer!

    override func setUp() {
        super.setUp()
        mock = MockMaskTextField()
        transformer = MaskTransformer(textField: mock)
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

    // MARK: - Позиция курсора

    func testDeleteBackwardAtCursorRemovesPrecedingCharacter() {
        transformer.mask = "dd-dd"

        _ = transformer.onTextInput("1", at: 0)
        _ = transformer.onTextInput("2", at: 0)
        _ = transformer.onTextInput("3", at: 0)
        _ = transformer.onTextInput("4", at: 0)

        XCTAssertEqual(transformer.text, "1234")
        XCTAssertEqual(mock.text, "12-34")

        // Курсор после "2" (индекс 2 — литерал '-'), удаляем символ перед курсором.
        transformer.onDeleteBackward(at: 2)

        XCTAssertEqual(transformer.text, "134")
        XCTAssertEqual(mock.text, "1_-34")
        XCTAssertEqual(mock.cursorPosition, 1)
    }

    func testInsertAtCursorFillsPositionAtOrAfterCursor() {
        transformer.mask = "dddd"

        _ = transformer.onTextInput("1", at: 0)
        _ = transformer.onTextInput("2", at: 0)

        XCTAssertEqual(mock.text, "12__")

        // Вставка с позиции 3 заполняет позицию 3, а не первую пустую (2).
        _ = transformer.onTextInput("9", at: 3)

        XCTAssertEqual(mock.text, "12_9")
        XCTAssertEqual(transformer.text, "129")
        XCTAssertEqual(mock.cursorPosition, 4)
    }

    // MARK: - Количество вводимых позиций

    func testOnlyEnteredCount() {
        transformer.mask = "+375 (dd) ddd-dd-dd"
        XCTAssertEqual(transformer.onlyEnteredCount, 9)
    }

    func testZMaskAcceptsAnyCharacter() {
        transformer.mask = "zz"

        // `z` — вводимая позиция без проверки: принимает и букву, и цифру.
        XCTAssertEqual(transformer.onlyEnteredCount, 2)

        _ = transformer.onTextInput("a")
        _ = transformer.onTextInput("1")

        XCTAssertEqual(transformer.text, "a1")
        XCTAssertEqual(mock.text, "a1")
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

    func testHideCharsVeilsEnteredCharacterAfterDelay() {
        transformer.mask = "dd"
        transformer.hideChars = true

        _ = transformer.onTextInput("1")

        // Сразу после ввода символ виден.
        XCTAssertEqual(mock.text, "1_")

        // Через 1.5 секунды символ скрывается.
        let expectation = expectation(description: "char hidden")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            XCTAssertEqual(self.mock.text, "•_")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.5)
    }

    // MARK: - Установка значения без маски

    func testSetTextValuePopulatesMask() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        transformer.text = "123456789"

        XCTAssertEqual(transformer.text, "123456789")
        XCTAssertEqual(mock.text, "+375 (12) 345-67-89")
    }

    // MARK: - Нормализация вставки

    func testNormalizedValueStripsMaskLiterals() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        XCTAssertEqual(transformer.normalizedValue(from: "+375 (29) 123-45-67"), "291234567")
    }

    func testNormalizedValueKeepsRawValue() {
        transformer.mask = "+375 (dd) ddd-dd-dd"

        XCTAssertEqual(transformer.normalizedValue(from: "291234567"), "291234567")
    }

    func testNormalizedValueKeepsLastEnteredCharacters() {
        transformer.mask = "dd-dd"

        XCTAssertEqual(transformer.normalizedValue(from: "123456"), "3456")
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

    func testCharacterIndexFromUTF16Offset() {
        // "😀" — 1 символ, но 2 UTF-16 единицы (суррогатная пара).
        let s = "😀_"

        XCTAssertEqual(s.characterIndex(utf16Offset: 0), 0)
        XCTAssertEqual(s.characterIndex(utf16Offset: 2), 1)
        XCTAssertEqual(s.characterIndex(utf16Offset: 3), 2)
    }

    func testUTF16OffsetFromCharacterIndex() {
        let s = "😀_"

        XCTAssertEqual(s.utf16Offset(characterIndex: 0), 0)
        XCTAssertEqual(s.utf16Offset(characterIndex: 1), 2)
        XCTAssertEqual(s.utf16Offset(characterIndex: 2), 3)
    }
}
