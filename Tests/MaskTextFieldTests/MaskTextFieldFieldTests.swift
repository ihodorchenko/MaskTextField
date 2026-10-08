import XCTest
import UIKit
import Combine
@testable import MaskTextField

/// Тесты реального `MaskTextField` (`UITextField`), покрывающие интеграцию
/// UIKit-слоя: ввод/удаление через делегат, вставку, курсор, скрытие символов
/// и проброс событий внешнему делегату.
///
/// Запускаются как обычные тесты пакета на симуляторе iOS (host-приложение не нужно).
@MainActor
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

    func testDeleteBackwardWithSelectionRemovesSelectedFragment() {
        // Маска сама схлопывает выделение через `textFieldDidChangeSelection`,
        // поэтому непустое выделение подставляем напрямую.
        let field = SelectionStubField()
        field.maskText = "dd-dd"
        field.textValue = "1234" // "12-34"

        // Выделено "2-3" (utf16 1..<4).
        let from = field.position(from: field.beginningOfDocument, offset: 1)!
        let to = field.position(from: field.beginningOfDocument, offset: 4)!
        field.stubbedSelection = field.textRange(from: from, to: to)

        field.deleteBackward()

        XCTAssertEqual(field.textValue, "14")
    }

    func testMaskSettingsAssignedBeforeMaskTextDoNotBlockInput() {
        field.maskChar = "#"
        field.hideChars = false
        field.maskLostFocus = ""
        field.cursorBehavior = .sequential
        field.maskText = "dd-dd"

        XCTAssertEqual(field.text, "##-##")
        type("1")
        XCTAssertEqual(field.textValue, "1")
    }

    func testMaskSettingWithoutMaskKeepsPlainFieldEditable() {
        field.maskChar = "#"

        XCTAssertTrue(field.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
    }

    func testClearingMaskLostFocusReachesTransformer() {
        field.maskText = "dd-dd"
        field.maskLostFocus = "^d^d-^d^d"
        field.textValue = "1234"
        field.maskLostFocus = ""

        XCTAssertEqual(field.configuration.maskLostFocus, "")
        _ = field.resignFirstResponder()
        XCTAssertEqual(field.text, "12-34")
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

    // MARK: - Последовательный курсор

    func testSequentialTypingAppendsEvenIfCursorIsElsewhere() {
        field.maskText = "dd-dd"
        field.cursorBehavior = .sequential
        field.textValue = "12"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "3"
        )

        XCTAssertEqual(field.textValue, "123")
        XCTAssertEqual(field.text, "12-3_")
    }

    func testSequentialBackspaceRemovesFromTheEnd() {
        field.maskText = "dd-dd"
        field.cursorBehavior = .sequential
        field.textValue = "1234"

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 1, length: 1),
            replacementString: ""
        )

        XCTAssertEqual(field.textValue, "123")
    }

    func testSequentialCursorCannotBeMoved() {
        field.maskText = "dd-dd"
        field.cursorBehavior = .sequential
        field.textValue = "12" // курсор — на индексе 3 (первая свободная позиция)

        field.setCursorPosition(0)
        field.textFieldDidChangeSelection(field)

        XCTAssertEqual(field.cursorOffset, 3)
    }

    func testSnapOnFocusSnapsFirstSelectionAfterBeginEditing() {
        field.maskText = "dd-dd"
        field.cursorBehavior = .snapOnFocus
        field.textValue = "12" // первая свободная позиция — индекс 3
        // Широкое окно привязки: тест не должен зависеть от скорости раннера.
        (field._transformer as? MaskTransformer)?.focusSnapWindow = 60

        field.textFieldDidBeginEditing(field)
        field.setCursorPosition(0)
        field.textFieldDidChangeSelection(field)
        XCTAssertEqual(field.cursorOffset, 3)

        // Дальше курсор свободен.
        field.setCursorPosition(1)
        field.textFieldDidChangeSelection(field)
        XCTAssertEqual(field.cursorOffset, 1)
    }

    func testCursorBehaviorSurvivesMaskToggle() {
        field.cursorBehavior = .sequential
        field.maskText = "dd"
        field.maskText = ""
        field.maskText = "dd"
        field.textValue = "12"

        field.setCursorPosition(0)
        field.textFieldDidChangeSelection(field)

        XCTAssertEqual(field.cursorOffset, 2)
    }

    // MARK: - Заполненность

    func testPlainFieldIsNeverComplete() {
        field.text = "abc"
        XCTAssertFalse(field.isComplete)
    }

    func testOnCompleteFiresOnceWhenUserFillsMask() {
        field.maskText = "dd"
        var completions = 0
        field.onComplete = { completions += 1 }

        type("1")
        XCTAssertEqual(completions, 0)

        type("2")
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(field.isComplete)

        // Маска заполнена: отклонённый ввод не повторяет событие.
        type("3")
        XCTAssertEqual(completions, 1)
    }

    func testOnCompleteFiresAgainAfterEditingAndRefilling() {
        field.maskText = "dd"
        var completions = 0
        field.onComplete = { completions += 1 }

        type("1")
        type("2")
        field.deleteBackward()
        XCTAssertFalse(field.isComplete)

        type("3")
        XCTAssertEqual(completions, 2)
    }

    func testOnCompleteDoesNotFireOnProgrammaticValue() {
        field.maskText = "dd"
        var completions = 0
        field.onComplete = { completions += 1 }

        field.textValue = "12"

        XCTAssertTrue(field.isComplete)
        XCTAssertEqual(completions, 0)
    }

    func testIsCompletePublisherEmitsCurrentValueThenChanges() {
        field.maskText = "dd"
        var values: [Bool] = []
        let cancellable = field.isCompletePublisher.sink { values.append($0) }

        field.textValue = "12"
        field.textValue = "12" // повтор — без дубля
        field.textValue = "1"
        field.maskText = "d"   // смена маски сбрасывает значение — не заполнена
        field.textValue = "1"

        XCTAssertEqual(values, [false, true, false, true])
        cancellable.cancel()
    }

    // MARK: - События

    func testEventPublishersDoNotFireOnSubscription() {
        var deleteCount = 0
        var clearCount = 0
        let cancellables = [
            field.deleteBackwardEvents.sink { deleteCount += 1 },
            field.clearButtonEvents.sink { clearCount += 1 }
        ]

        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(clearCount, 0)

        field.maskText = "dd"
        field.textValue = "12"
        field.deleteBackward()
        XCTAssertEqual(deleteCount, 1)

        field.clearButtonMode = .always
        // `sendActions` у кнопки вне окна не доставляет действие, поэтому вызываем
        // обработчик кнопки напрямую.
        field.perform(NSSelectorFromString("clearButtonHandler"))
        XCTAssertEqual(clearCount, 1)

        cancellables.forEach { $0.cancel() }
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

    // MARK: - Подсказки клавиатуры

    func testMaskedFieldDisablesSuggestionsByDefault() {
        field.maskText = "dddd dddd dddd dddd"

        XCTAssertEqual(field.autocorrectionType, .no)
        XCTAssertEqual(field.spellCheckingType, .no)
        XCTAssertEqual(field.smartQuotesType, .no)
        XCTAssertEqual(field.smartDashesType, .no)
        XCTAssertEqual(field.smartInsertDeleteType, .no)
    }

    func testPlainFieldKeepsSystemSuggestions() {
        XCTAssertEqual(field.autocorrectionType, .default)
        XCTAssertEqual(field.spellCheckingType, .default)
    }

    func testSuggestionsCanBeEnabledBack() {
        field.maskText = "dd"
        field.disablesAutocorrection = false

        XCTAssertEqual(field.autocorrectionType, .default)
    }

    func testExplicitTraitWinsOverSuppression() {
        field.maskText = "dd"
        field.autocorrectionType = .yes

        XCTAssertEqual(field.autocorrectionType, .yes)
        // Остальные признаки по-прежнему подавлены.
        XCTAssertEqual(field.spellCheckingType, .no)
    }

    func testSuggestionsReturnWhenMaskIsRemoved() {
        field.maskText = "dd"
        field.maskText = ""

        XCTAssertEqual(field.autocorrectionType, .default)
    }

    // MARK: - OTP

    func testOneTimeCodeAutofillIsAcceptedAsWholeReplacement() {
        field.maskText = "dddddd"
        field.textContentType = .oneTimeCode
        field.textValue = "12"

        // Автозаполнение приходит одной строкой с диапазоном всего текущего значения.
        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: field.text?.count ?? 0),
            replacementString: "493817"
        )

        XCTAssertEqual(field.textValue, "493817")
        XCTAssertTrue(field.isComplete)
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

    // MARK: - Dynamic Type

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

/// Поле с подменяемым выделением (реальное выделение маска схлопывает сама).
private final class SelectionStubField: MaskTextField {
    var stubbedSelection: UITextRange?

    override var selectedTextRange: UITextRange? {
        get { self.stubbedSelection ?? super.selectedTextRange }
        set { super.selectedTextRange = newValue }
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
