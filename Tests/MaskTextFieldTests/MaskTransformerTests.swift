import XCTest
@testable import MaskTextField

final class MaskTransformerTests: XCTestCase {

    private var mock: MockMaskTextField!
    private var transformer: MaskTransformer!

    override func setUp() {
        super.setUp()
        mock = MockMaskTextField()
        // Широкое окно привязки курсора: тесты не должны зависеть от скорости раннера.
        MaskTransformer.focusSnapWindow = 60
        transformer = MaskTransformer(textField: mock)
    }

    /// Крутит main run loop, пока условие не выполнится или не истечёт `timeout`.
    ///
    /// Вместо `asyncAfter` с проверками внутри замыкания: на нагруженном CI таймеры
    /// опаздывают, а замыкание, сработавшее после `tearDown`, роняет процесс тестов.
    private func waitUntil(timeout: TimeInterval = 15, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return true
    }

    private func spinRunLoop(for interval: TimeInterval) {
        let deadline = Date().addingTimeInterval(interval)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    override func tearDown() {
        MaskTransformer.focusSnapWindow = 0.5
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

    func testInputAtEndFillsFreePositionsOnTheLeftInOrder() {
        transformer.mask = "+375 (dd) ddd"
        transformer.text = "29123" // "+375 (29) 123" заполнена; освободим две позиции слева
        transformer.onDeleteBackward(at: 7)
        transformer.onDeleteBackward(at: 6)
        XCTAssertEqual(transformer.text, "123")

        // Курсор в конце: свободных позиций справа нет — заполняются слева, по порядку.
        _ = transformer.onTextInput("7", at: 13)
        _ = transformer.onTextInput("8", at: 13)

        XCTAssertEqual(mock.text, "+375 (78) 123")
        XCTAssertEqual(transformer.text, "78123")
        XCTAssertTrue(transformer.isComplete)
    }

    func testInputIsStillRejectedWhenMaskIsFull() {
        transformer.mask = "dd"
        transformer.text = "12"

        XCTAssertFalse(transformer.onTextInput("3", at: 0))
        XCTAssertFalse(transformer.onTextInput("3", at: 2))
    }

    func testInvalidCharacterIsRejectedInLeftFallbackToo() {
        transformer.mask = "dd"
        transformer.text = "1"
        _ = transformer.onTextInput("2", at: 0)
        transformer.onDeleteBackward(at: 0)

        XCTAssertFalse(transformer.onTextInput("a", at: 2))
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

    func testAnySymbolMasksValidateAscii() {
        transformer.mask = "xX"

        // `x` — видимый символ, но не цифра; `X` — видимый символ, включая цифру.
        XCTAssertFalse(transformer.onTextInput("5"))
        XCTAssertFalse(transformer.onTextInput(" "))
        XCTAssertTrue(transformer.onTextInput(","))
        XCTAssertTrue(transformer.onTextInput("5"))
        XCTAssertFalse(transformer.onTextInput("я"))

        XCTAssertEqual(transformer.text, ",5")
    }

    func testDigitAndLetterMasksAreAscii() {
        transformer.mask = "da"

        XCTAssertFalse(transformer.onTextInput("٣")) // арабско-индийская цифра
        XCTAssertTrue(transformer.onTextInput("3"))
        XCTAssertFalse(transformer.onTextInput("я"))
        XCTAssertTrue(transformer.onTextInput("q"))
        XCTAssertEqual(transformer.text, "3q")
    }

    // MARK: - Вставка по диапазону

    func testPasteInMiddleShiftsTrailingValue() {
        transformer.mask = "dd-dd"
        transformer.text = "14"

        transformer.onPaste("23", in: 1..<1)

        XCTAssertEqual(transformer.text, "1234")
        XCTAssertEqual(mock.text, "12-34")
        // Курсор — сразу за вставленным "3" (индекс 3), перед сдвинутым "4".
        XCTAssertEqual(mock.cursorPosition, 4)
    }

    func testPasteReplacesRange() {
        transformer.mask = "dd-dd"
        transformer.text = "1234"

        transformer.onPaste("9", in: 0..<2)

        XCTAssertEqual(transformer.text, "934")
        XCTAssertEqual(mock.text, "93-4_")
    }

    func testPasteWithEmptyStringDeletesRange() {
        transformer.mask = "dd-dd"
        transformer.text = "1234"

        transformer.onPaste("", in: 1..<4)

        XCTAssertEqual(transformer.text, "14")
        XCTAssertEqual(mock.cursorPosition, 1)
    }

    func testPasteOverflowDropsTrailingValue() {
        transformer.mask = "dd-dd"
        transformer.text = "1234"

        transformer.onPaste("99", in: 0..<0)

        XCTAssertEqual(transformer.text, "9912")
    }

    // MARK: - Последовательный курсор

    func testSequentialInputIgnoresOffset() {
        transformer.mask = "dddd"
        transformer.cursorBehavior = .sequential
        transformer.text = "12"

        _ = transformer.onTextInput("9", at: 3)

        XCTAssertEqual(transformer.text, "129")
        XCTAssertEqual(mock.text, "129_")
    }

    func testSequentialDeleteAlwaysRemovesLastEntered() {
        transformer.mask = "dddd"
        transformer.cursorBehavior = .sequential
        transformer.text = "123"

        transformer.onDeleteBackward(at: 1)

        XCTAssertEqual(transformer.text, "12")
    }

    func testFreeDeleteRemovesAtOffset() {
        transformer.mask = "dddd"
        transformer.text = "123"

        transformer.onDeleteBackward(at: 1)

        // Удаляется символ с индексом 1 ("2"), а не последний.
        XCTAssertEqual(transformer.text, "13")
    }

    func testSequentialSelectionChangeSnapsCursorToFirstFreePosition() {
        transformer.mask = "+375 (dd) ddd"
        transformer.cursorBehavior = .sequential
        transformer.text = "29"

        mock.setCursorPosition(2)
        transformer.onSelectionChanged()

        // Первая свободная вводимая позиция — индекс 10 (после "+375 (29) ").
        XCTAssertEqual(mock.cursorPosition, 10)
    }

    func testFreeSelectionChangeKeepsCursor() {
        transformer.mask = "+375 (dd) ddd"
        transformer.text = "29"

        mock.setCursorPosition(2)
        transformer.onSelectionChanged()

        XCTAssertEqual(mock.cursorPosition, 2)
    }

    func testSequentialPasteAppendsToEnd() {
        transformer.mask = "dd-dd"
        transformer.cursorBehavior = .sequential
        transformer.text = "12"

        transformer.onPaste("9", in: 0..<0)

        XCTAssertEqual(transformer.text, "129")
    }

    func testSequentialPasteOverSelectionDropsEverythingAfterSelectionStart() {
        transformer.mask = "dd-dd"
        transformer.cursorBehavior = .sequential
        transformer.text = "1234"

        transformer.onPaste("9", in: 1..<2)

        XCTAssertEqual(transformer.text, "19")
    }

    // MARK: - Курсор: привязка при фокусе

    func testSnapOnFocusMovesFirstSelectionToFirstFreePosition() {
        transformer.mask = "+375 (dd) ddd"
        transformer.cursorBehavior = .snapOnFocus
        transformer.text = "29"

        transformer.onGotFocus()
        // UIKit ставит курсор по тапу сразу после получения фокуса.
        mock.setCursorPosition(2)
        transformer.onSelectionChanged()

        XCTAssertEqual(mock.cursorPosition, 10)
    }

    func testSnapOnFocusAllowsMovingCursorAfterwards() {
        transformer.mask = "+375 (dd) ddd"
        transformer.cursorBehavior = .snapOnFocus
        transformer.text = "29"

        transformer.onGotFocus()
        mock.setCursorPosition(2)
        transformer.onSelectionChanged() // привязка к первой свободной позиции

        mock.setCursorPosition(7)
        transformer.onSelectionChanged()

        XCTAssertEqual(mock.cursorPosition, 7)
    }

    func testSnapOnFocusDoesNotInterfereAfterWindowExpires() {
        transformer.mask = "+375 (dd) ddd"
        transformer.cursorBehavior = .snapOnFocus
        transformer.text = "29"

        MaskTransformer.focusSnapWindow = 0

        transformer.onGotFocus()
        Thread.sleep(forTimeInterval: 0.01)
        mock.setCursorPosition(2)
        transformer.onSelectionChanged()

        XCTAssertEqual(mock.cursorPosition, 2)
    }

    func testSnapOnFocusIsRearmedOnEachFocus() {
        transformer.mask = "dddd"
        transformer.cursorBehavior = .snapOnFocus
        transformer.text = "12"

        transformer.onGotFocus()
        mock.setCursorPosition(0)
        transformer.onSelectionChanged()
        XCTAssertEqual(mock.cursorPosition, 2)

        transformer.onLostFocus()
        transformer.onGotFocus()
        mock.setCursorPosition(0)
        transformer.onSelectionChanged()
        XCTAssertEqual(mock.cursorPosition, 2)
    }

    func testSnapOnFocusKeepsInputAtCursorLikeFree() {
        transformer.mask = "dddd"
        transformer.cursorBehavior = .snapOnFocus
        transformer.text = "123"

        transformer.onDeleteBackward(at: 1)

        XCTAssertEqual(transformer.text, "13")
    }

    // MARK: - Заполненность

    func testIsCompleteReflectsAllEnteredPositions() {
        transformer.mask = "dd-dd"
        XCTAssertFalse(transformer.isComplete)

        transformer.text = "123"
        XCTAssertFalse(transformer.isComplete)

        transformer.text = "1234"
        XCTAssertTrue(transformer.isComplete)

        transformer.onDeleteBackward()
        XCTAssertFalse(transformer.isComplete)
    }

    func testMaskWithoutEnteredPositionsIsNeverComplete() {
        transformer.mask = "+375"
        XCTAssertFalse(transformer.isComplete)

        transformer.mask = ""
        XCTAssertFalse(transformer.isComplete)
    }

    func testIsCompleteWithGapsInFreeMode() {
        transformer.mask = "dddd"
        _ = transformer.onTextInput("1", at: 0)
        _ = transformer.onTextInput("9", at: 3) // позиция 2 остаётся пустой

        XCTAssertFalse(transformer.isComplete)
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
        XCTAssertTrue(waitUntil { self.mock.text == "•_" }, "символ не скрылся: \(mock.text ?? "nil")")
    }

    func testHideCharsTimerKeepsCursorPositionInFreeMode() {
        transformer.mask = "dddd"
        transformer.hideChars = true
        _ = transformer.onTextInput("1")

        // Пользователь переставил курсор, пока шёл таймер скрытия.
        mock.setCursorPosition(0)

        XCTAssertTrue(waitUntil { self.mock.text == "•___" }, "таймер не сработал: \(mock.text ?? "nil")")
        XCTAssertEqual(mock.cursorPosition, 0)
    }

    func testHideCharsTimerKeepsCanonicalCursorInSequentialMode() {
        transformer.mask = "dddd"
        transformer.cursorBehavior = .sequential
        transformer.hideChars = true
        _ = transformer.onTextInput("1")

        XCTAssertTrue(waitUntil { self.mock.text == "•___" }, "таймер не сработал: \(mock.text ?? "nil")")
        XCTAssertEqual(mock.cursorPosition, 1)
    }

    func testHideCharsTimerCanceledOnMaskChange() {
        transformer.mask = "dd"
        transformer.hideChars = true
        _ = transformer.onTextInput("1") // "1_", запускает таймер скрытия для "1"

        // Смена маски уничтожает старые позиции и их таймеры.
        transformer.mask = "ddd"

        XCTAssertEqual(mock.text, "___")

        // Спустя больше, чем задержка скрытия, старый таймер не должен
        // ничего «завеить» в новой маске.
        spinRunLoop(for: MaskTransformer.hideCharDelay + 0.5)

        XCTAssertEqual(mock.text, "___")
    }

    func testHideCharsKeepsOnlyLastEnteredVisibleThenVeilsAll() {
        transformer.mask = "ddd"
        transformer.hideChars = true

        _ = transformer.onTextInput("1")
        _ = transformer.onTextInput("2")

        // Предыдущие символы скрываются сразу, последний — виден.
        XCTAssertEqual(mock.text, "•2_")

        XCTAssertTrue(waitUntil { self.mock.text == "••_" }, "символы не скрылись: \(mock.text ?? "nil")")
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
