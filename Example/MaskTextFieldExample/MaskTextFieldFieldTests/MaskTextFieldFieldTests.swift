//
//  MaskTextFieldFieldTests.swift
//  MaskTextFieldFieldTests
//

import XCTest
import UIKit
import MaskTextField

/// Тесты реального `MaskTextField` (`UITextField`), покрывающие интеграцию
/// UIKit-слоя: ввод/удаление через делегат, вставку, курсор, скрытие символов
/// и проброс событий внешнему делегату.
///
/// Запускаются внутри host-приложения (`MaskTextFieldExample`), поэтому здесь
/// доступен `UIApplication` и контрольные события (`sendActions`) работают без
/// assert-шума, в отличие от UIKit-free тестов пакета.
final class MaskTextFieldFieldTests: XCTestCase {

    private var field: MaskTextField!

    override func setUp() {
        super.setUp()
        field = MaskTextField()
    }

    override func tearDown() {
        field = nil
        super.tearDown()
    }

    // MARK: - Маска

    func testRendersMaskPlaceholder() {
        field.maskText = "+375 (dd) ddd-dd-dd"

        XCTAssertEqual(field.text, "+375 (__) ___-__-__")
        XCTAssertEqual(field.textValue, "")
    }

    func testMaskIsHiddenWhenEmptyAndNotFocused() {
        field.maskText = "+375 (dd) ddd-dd-dd"
        field.hiddenMaskIfEnteredTextEmpty = true

        // Поле не в фокусе, значение пустое — маска скрыта.
        XCTAssertEqual(field.text, "")
    }

    func testMaskConfigurationSurvivesMaskToggle() {
        field.maskChar = "#"
        field.maskText = "dd"

        // Выключаем маску, затем включаем снова — настройки должны сохраниться.
        field.maskText = ""
        field.maskText = "dd"

        XCTAssertEqual(field.visibleTextMask, "##")
    }

    // MARK: - textValue

    func testTextValueRoundTrip() {
        field.maskText = "+375 (dd) ddd-dd-dd"

        field.textValue = "291234567"

        XCTAssertEqual(field.text, "+375 (29) 123-45-67")
        XCTAssertEqual(field.textValue, "291234567")
    }

    // MARK: - Ввод

    func testTypingBuildsMaskedText() {
        field.maskText = "+375 (dd) ddd-dd-dd"

        type("2")
        type("9")

        XCTAssertEqual(field.text, "+375 (29) ___-__-__")
        XCTAssertEqual(field.textValue, "29")
    }

    func testInvalidCharacterIsRejected() {
        field.maskText = "dd"

        _ = typeReturningResult("a")

        XCTAssertEqual(field.text, "__")
        XCTAssertEqual(field.textValue, "")
    }

    // MARK: - Вставка

    func testPasteNormalizesFormattedText() {
        field.maskText = "+375 (dd) ddd-dd-dd"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "+375 (29) 123-45-67"
        )

        XCTAssertEqual(field.textValue, "291234567")
        XCTAssertEqual(field.text, "+375 (29) 123-45-67")
    }

    // MARK: - Удаление

    func testBackspaceAtCursorRemovesPrecedingCharacter() {
        field.maskText = "dd-dd"
        field.textValue = "1234"

        XCTAssertEqual(field.text, "12-34")

        // Курсор после "2" (индекс 2), backspace удаляет "2" (индекс 1).
        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 1, length: 1),
            replacementString: ""
        )

        XCTAssertEqual(field.textValue, "134")
        XCTAssertEqual(field.text, "1_-34")
    }

    func testDeleteBackwardKeepsMaskStateInSync() {
        field.maskText = "dd-dd"
        field.textValue = "1234" // "12-34"

        // Прямой вызов (аппаратная клавиатура/меню) не должен разсинхронизировать
        // состояние маски: удаление обязано идти через трансформер.
        field.deleteBackward()

        XCTAssertEqual(field.textValue, "123")
        XCTAssertEqual(field.text, "12-3_")
    }

    // MARK: - Курсор

    func testCursorAdvancesAfterTyping() {
        field.maskText = "+375 (dd) ddd-dd-dd"

        type("2")
        XCTAssertEqual(cursorOffset(), 7)

        // После "9" курсор перескакивает литералы (")", " ") на следующую позицию.
        type("9")
        XCTAssertEqual(cursorOffset(), 10)
    }

    func testCursorPreservedOnSelectionChange() {
        field.maskText = "dd-dd"
        field.textValue = "1234" // "12-34", курсор в конце

        // Перемещаем курсор в позицию 2 (между "2" и "-").
        field.setCursorPosition(2)
        // Эмуляция UIKit: изменение выделения не должно отбрасывать курсор в конец.
        field.textFieldDidChangeSelection(field)

        XCTAssertEqual(cursorOffset(), 2)
    }

    // MARK: - Скрытие при потере фокуса

    func testVeilsEnteredCharactersOnLostFocus() {
        field.maskText = "+3 (^d^d)"

        field.textFieldDidBeginEditing(field)
        type("1")
        type("2")

        XCTAssertEqual(field.text, "+3 (12)")

        field.textFieldDidEndEditing(field)

        XCTAssertEqual(field.text, "+3 (••)")
    }

    // MARK: - Делегат

    func testForwardsCallbacksToExternalDelegate() {
        let delegate = RecordingDelegate()
        field.delegate = delegate
        field.maskText = "dd"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "1"
        )
        field.textFieldDidBeginEditing(field)

        XCTAssertEqual(delegate.shouldChangeCharactersCalls, 1)
        XCTAssertTrue(delegate.didBeginEditing)
    }

    func testExternalDelegateCanVetoInput() {
        let delegate = VetoingDelegate()
        field.delegate = delegate
        field.maskText = "dd"

        let result = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "1"
        )

        XCTAssertFalse(result)
        XCTAssertEqual(delegate.shouldChangeCharactersCalls, 1)
        XCTAssertEqual(field.text, "__")
        XCTAssertEqual(field.textValue, "")
    }

    // MARK: - Helpers

    /// Симулирует ввод одного символа в позицию текущего курсора.
    private func type(_ string: String) {
        _ = typeReturningResult(string)
    }

    private func typeReturningResult(_ string: String) -> Bool {
        let location = cursorOffset()
        return field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: location, length: 0),
            replacementString: string
        )
    }

    /// Текущая позиция курсора (UTF-16 offset в тексте поля).
    private func cursorOffset() -> Int {
        guard let range = field.selectedTextRange else { return 0 }
        return field.offset(from: field.beginningOfDocument, to: range.start)
    }
}

/// Минимальный делегат, фиксирующий факт вызова методов.
private final class RecordingDelegate: NSObject, UITextFieldDelegate {
    var shouldChangeCharactersCalls = 0
    var didBeginEditing = false

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        shouldChangeCharactersCalls += 1
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        didBeginEditing = true
    }
}

/// Делегат, всегда отклоняющий ввод.
private final class VetoingDelegate: NSObject, UITextFieldDelegate {
    var shouldChangeCharactersCalls = 0

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        shouldChangeCharactersCalls += 1
        return false
    }
}
