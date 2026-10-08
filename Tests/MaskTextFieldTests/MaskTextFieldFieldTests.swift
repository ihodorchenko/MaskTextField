import XCTest
import UIKit
@testable import MaskTextField

/// Тесты реального `MaskTextField` (`UITextField`), покрывающие интеграцию
/// UIKit-слоя: ввод/удаление через делегат, вставку, курсор, скрытие символов
/// и проброс событий внешнему делегату.
///
/// Запускаются как обычные тесты пакета на симуляторе iOS (host-приложение не нужно).
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

    func testPasteStripsInvalidCharacters() {
        field.maskText = "dd-dd"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "1a2b3c4d"
        )

        XCTAssertEqual(field.textValue, "1234")
        XCTAssertEqual(field.text, "12-34")
    }

    func testPasteInMiddleKeepsSurroundingValue() {
        field.maskText = "dd-dd"
        field.textValue = "14" // "14-__"

        // Вставляем "23" между "1" и "4": остаток сдвигается вправо.
        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 1, length: 0),
            replacementString: "23"
        )

        XCTAssertEqual(field.textValue, "1234")
        XCTAssertEqual(field.text, "12-34")
    }

    func testPasteReplacesSelection() {
        field.maskText = "dd-dd"
        field.textValue = "1234" // "12-34"

        // Выделено "2-3" (индексы 1..<4), вставляем "99".
        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 1, length: 3),
            replacementString: "99"
        )

        XCTAssertEqual(field.textValue, "1994")
        XCTAssertEqual(field.text, "19-94")
    }

    func testTypingOverSelectionReplacesIt() {
        field.maskText = "dd-dd"
        field.textValue = "1234" // "12-34"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 2),
            replacementString: "9"
        )

        XCTAssertEqual(field.textValue, "934")
        XCTAssertEqual(field.text, "93-4_")
    }

    // MARK: - Удаление

    func testDeletingSelectionRemovesAllSelectedCharacters() {
        field.maskText = "dd-dd"
        field.textValue = "1234" // "12-34"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 1, length: 3),
            replacementString: ""
        )

        XCTAssertEqual(field.textValue, "14")
        XCTAssertEqual(field.text, "14-__")
    }

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

        field.textFieldDidEndEditing(field, reason: .committed)

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

    // MARK: - Accessibility

    func testAccessibilityValueIsEmptyDescriptionForEmptyField() {
        field.maskText = "+375 (dd) ddd-dd-dd"

        // Вместо «подчёркивание ×9» — осмысленное «Пусто».
        XCTAssertEqual(field.accessibilityValue, L10n.string("a11y.empty"))
    }

    func testAccessibilityValueReadsEnteredCharactersWithoutMask() {
        field.maskText = "+375 (dd) ddd-dd-dd"
        field.textValue = "29123"

        XCTAssertEqual(field.accessibilityValue, "2 9 1 2 3")
    }

    func testAccessibilityValueHidesVeiledCharacters() {
        field.maskText = "+3 (^d^d)"
        field.textValue = "12"

        field.textFieldDidBeginEditing(field)
        XCTAssertEqual(field.accessibilityValue, "1 2")

        field.textFieldDidEndEditing(field, reason: .committed)
        XCTAssertEqual(field.accessibilityValue, L10n.enteredCount(2, of: 2))
    }

    func testAccessibilityValueHidesCharactersInPasswordMode() {
        field.maskText = "dddd"
        field.hideChars = true
        field.textValue = "123"

        XCTAssertEqual(field.accessibilityValue, L10n.enteredCount(3, of: 4))
    }

    func testExplicitAccessibilityValueWins() {
        field.maskText = "dd"
        field.accessibilityValue = "custom"

        XCTAssertEqual(field.accessibilityValue, "custom")
    }

    func testClearButtonHasAccessibilityLabel() {
        field.clearButtonMode = .always

        XCTAssertEqual(field.rightView?.accessibilityLabel, L10n.string("a11y.clear"))
    }

    // MARK: - RTL

    func testForcesLeftToRightByDefault() {
        XCTAssertTrue(field.forcesLeftToRight)
        XCTAssertEqual(field.semanticContentAttribute, .forceLeftToRight)

        field.forcesLeftToRight = false
        XCTAssertEqual(field.semanticContentAttribute, .unspecified)
    }

    func testTextAlignmentIsPreservedWhenSet() {
        field.textAlignment = .center
        XCTAssertEqual(field.textAlignment, .center)

        // Принудительное LTR не подменяет заданное пользователем значение при чтении.
        field.textAlignment = .natural
        XCTAssertEqual(field.textAlignment, .natural)
    }

    func testClearButtonMovesToLeadingSideInRTL() {
        field.forcesLeftToRight = false
        field.semanticContentAttribute = .forceRightToLeft
        field.clearButtonMode = .always

        XCTAssertNotNil(field.leftView)
        XCTAssertNil(field.rightView)

        field.semanticContentAttribute = .forceLeftToRight
        XCTAssertNil(field.leftView)
        XCTAssertNotNil(field.rightView)
    }

    // MARK: - Locale and Dynamic Type

    func testLocaleControlsDefaultDecimalSeparator() {
        field.locale = Locale(identifier: "de_DE")
        XCTAssertEqual(field.culture.decimalSeparator, ",")

        field.locale = Locale(identifier: "en_US")
        XCTAssertEqual(field.culture.decimalSeparator, ".")
    }

    func testAdjustsFontForContentSizeCategory() {
        XCTAssertTrue(field.adjustsFontForContentSizeCategory)
    }

    // MARK: - Edit actions

    func testResetEditActionsClearsFilter() {
        // Обеспечиваем, что системный paste разрешён (в буфере есть текст).
        UIPasteboard.general.string = "test"
        let pasteSelector = ResponderStandardEditActions.paste.selector
        let fresh = MaskTextField()

        // Запрещаем paste через фильтр.
        field.filterEditActions(notAllowed: [.paste])
        XCTAssertFalse(field.canPerformAction(pasteSelector, withSender: nil))

        field.resetEditActions()

        // После сброса поле ведёт себя как «чистое» (фильтр снят).
        XCTAssertEqual(
            field.canPerformAction(pasteSelector, withSender: nil),
            fresh.canPerformAction(pasteSelector, withSender: nil)
        )
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
