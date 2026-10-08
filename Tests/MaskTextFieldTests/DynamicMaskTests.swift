import XCTest
import UIKit
@testable import MaskTextField

/// Динамические маски на уровне трансформера (без UIKit).
@MainActor
final class DynamicMaskTransformerTests: XCTestCase {

    private var mock: MockMaskTextField!
    private var transformer: MaskTransformer!

    private let phoneVariants = [
        MaskVariant("(dd) ddd"),     // 5 цифр
        MaskVariant("(dd) ddd-dd")   // 7 цифр
    ]

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

    private func useCardProvider() {
        transformer.maskProvider = MaskPreset.cardProvider
    }

    private func type(_ string: String) {
        for char in string {
            _ = transformer.onTextInput(String(char), at: mock.cursorPosition)
        }
    }

    // MARK: - Выбор маски

    func testProviderPicksMaskForEmptyValue() {
        useCardProvider()

        XCTAssertEqual(mock.text, "____ ____ ____ ____")
        XCTAssertEqual(transformer.onlyEnteredCount, 16)
    }

    func testMaskSwitchesWhenPrefixIdentifiesAmex() {
        useCardProvider()

        type("3")
        XCTAssertEqual(mock.text, "3___ ____ ____ ____")

        type("4")
        XCTAssertEqual(mock.text, "34__ ______ _____")
        XCTAssertEqual(transformer.onlyEnteredCount, 15)
        XCTAssertEqual(transformer.text, "34")
    }

    func testAmexNumberFillsItsMaskAndIsComplete() {
        useCardProvider()

        type("341234567812345")

        XCTAssertEqual(mock.text, "3412 345678 12345")
        XCTAssertTrue(transformer.isComplete)
    }

    func testCapacityBasedVariantsGrowWhenMaskIsFull() {
        transformer.maskProvider = MaskVariant.provider(byCapacity: phoneVariants)

        type("12345")
        XCTAssertEqual(mock.text, "(12) 345")
        XCTAssertEqual(transformer.onlyEnteredCount, 5)

        // Шестой символ не помещается — маска переключается на большую, значение сохраняется.
        type("6")
        XCTAssertEqual(mock.text, "(12) 345-6_")
        XCTAssertEqual(transformer.text, "123456")
    }

    func testMaskShrinksBackWhenValueGetsShorter() {
        transformer.maskProvider = MaskVariant.provider(byCapacity: phoneVariants)
        type("123456")

        transformer.onDeleteBackward()

        XCTAssertEqual(transformer.text, "12345")
        XCTAssertEqual(transformer.onlyEnteredCount, 5)
        XCTAssertEqual(mock.text, "(12) 345")
    }

    func testInputBeyondLargestMaskIsRejected() {
        transformer.maskProvider = MaskVariant.provider(byCapacity: phoneVariants)
        type("1234567")

        XCTAssertFalse(transformer.onTextInput("8", at: mock.cursorPosition))
        XCTAssertEqual(transformer.text, "1234567")
    }

    func testRejectedCharacterDoesNotChangeMask() {
        useCardProvider()
        type("34")

        // Буква не подходит позиции `d`: состояние откатывается целиком.
        XCTAssertFalse(transformer.onTextInput("a", at: mock.cursorPosition))
        XCTAssertEqual(transformer.text, "34")
        XCTAssertEqual(mock.text, "34__ ______ _____")
    }

    // MARK: - Вставка и значение

    func testSetTextPicksMaskByValue() {
        useCardProvider()

        transformer.text = "371234567890123"

        XCTAssertEqual(mock.text, "3712 345678 90123")
        XCTAssertEqual(transformer.text, "371234567890123")
    }

    func testPasteIntoEmptyFieldSwitchesMask() {
        useCardProvider()

        transformer.onPaste("3412 345678 12345", in: 0..<0)

        XCTAssertEqual(mock.text, "3412 345678 12345")
    }

    func testPasteLongerThanLargestMaskKeepsLastCharacters() {
        transformer.maskProvider = MaskVariant.provider(byCapacity: phoneVariants)

        // 7 цифр — вместимость большой маски; лишние слева отбрасываются, как и без динамики.
        transformer.onPaste("+375 1234567", in: 0..<0)

        XCTAssertEqual(transformer.text, "1234567")
    }

    func testPasteInMiddleShiftsTailAndMayGrowMask() {
        transformer.maskProvider = MaskVariant.provider(byCapacity: phoneVariants)
        transformer.text = "12345"
        XCTAssertEqual(transformer.onlyEnteredCount, 5)

        // Слот 3 — литерал «)» сразу после «12»: вставка идёт между «12» и «345».
        transformer.onPaste("99", in: 3..<3)

        XCTAssertEqual(transformer.text, "1299345")
        XCTAssertEqual(transformer.onlyEnteredCount, 7)
    }

    // MARK: - Удаление и курсор

    func testDeleteInMiddleCompactsValue() {
        transformer.maskProvider = MaskVariant.provider(byCapacity: phoneVariants)
        transformer.text = "12345"

        // Раскладка «(12) 345»: слот 2 — вторая цифра («2»).
        transformer.onDeleteBackward(at: 2)

        XCTAssertEqual(transformer.text, "1345")
    }

    func testCursorFollowsInsertedCharacterAcrossMaskSwitch() {
        useCardProvider()

        type("3")
        type("4")

        // «34__ ______ _____»: курсор на первой свободной позиции после «34».
        XCTAssertEqual(mock.cursorPosition, 2)
    }

    func testSequentialDynamicIgnoresOffset() {
        useCardProvider()
        transformer.cursorBehavior = .sequential
        transformer.text = "34"

        _ = transformer.onTextInput("1", at: 0)

        XCTAssertEqual(transformer.text, "341")
    }

    // MARK: - Возврат к статической маске

    func testRemovingProviderRestoresStaticMask() {
        useCardProvider()
        transformer.mask = "dd-dd"

        // Пока задан провайдер, `mask` не используется.
        XCTAssertEqual(mock.text, "____ ____ ____ ____")

        transformer.maskProvider = nil

        XCTAssertEqual(mock.text, "__-__")
    }
}

/// Динамические маски, конфигурация и пресеты в реальном `MaskTextField`.
@MainActor
final class DynamicMaskFieldTests: XCTestCase {

    private var field: MaskTextField!

    override func setUp() {
        super.setUp()
        field = MaskTextField()
    }

    override func tearDown() {
        field = nil
        super.tearDown()
    }

    func testMaskVariantsOnField() {
        field.maskVariants = [MaskVariant("dd"), MaskVariant("dd-dd")]

        XCTAssertEqual(field.text, "__")

        field.textValue = "123"
        XCTAssertEqual(field.text, "12-3_")
        XCTAssertEqual(field.textValue, "123")
    }

    func testMaskProviderWorksWithoutMaskText() {
        field.maskProvider = MaskPreset.cardProvider

        field.textValue = "341234567812345"

        XCTAssertEqual(field.text, "3412 345678 12345")
        XCTAssertTrue(field.isComplete)
    }

    func testTypingThroughDelegateSwitchesMask() {
        field.maskProvider = MaskPreset.cardProvider

        for char in "37" {
            let location = (field.text ?? "").characterIndex(utf16Offset:
                field.offset(from: field.beginningOfDocument, to: field.selectedTextRange?.start ?? field.endOfDocument))
            _ = field.textField(
                field,
                shouldChangeCharactersIn: NSRange(location: location, length: 0),
                replacementString: String(char)
            )
        }

        XCTAssertEqual(field.text, "37__ ______ _____")
        XCTAssertEqual(field.onlyEnteredCount, 15)
    }

    func testClearingProviderRestoresPlainField() {
        field.maskProvider = MaskPreset.cardProvider
        field.maskProvider = nil

        XCTAssertEqual(field.onlyEnteredCount, 0)
    }

    func testSettingStaticMaskWhileProviderIsActiveKeepsProvider() {
        field.maskProvider = MaskPreset.cardProvider
        field.maskText = "dd"

        XCTAssertEqual(field.text, "____ ____ ____ ____")
    }

    // MARK: - Конфигурация

    func testApplyConfigurationIsOrderIndependentAndKeepsEverything() {
        var configuration = MaskConfiguration(mask: "dd/dd")
        configuration.maskChar = "#"
        configuration.cursorBehavior = .sequential
        configuration.maskMode = .gradualMask

        field.apply(configuration)

        XCTAssertEqual(field.visibleTextMask, "##/##")
        XCTAssertEqual(field.cursorBehavior, .sequential)
        XCTAssertEqual(field.maskMode, .gradualMask)
    }

    func testConfigureClosureChangesOnlyRequestedSettings() {
        field.maskText = "dd"
        field.maskChar = "#"

        field.configure { $0.hideChars = true }

        XCTAssertTrue(field.hideChars)
        XCTAssertEqual(field.maskText, "dd")
        XCTAssertEqual(field.maskChar, "#")
        XCTAssertEqual(field.visibleTextMask, "##")
    }

    func testConfigureWithEmptyMaskRestoresPlainField() {
        field.maskText = "dd"

        field.configure { $0.mask = "" }

        XCTAssertEqual(field.onlyEnteredCount, 0)
    }

    func testConfigurationRoundTripKeepsCustomProvider() {
        field.maskProvider = MaskPreset.cardProvider

        field.configure { $0.maskChar = "#" }

        field.textValue = "34"
        XCTAssertEqual(field.text, "34## ###### #####")
    }

    func testConfigurationWithVariants() {
        field.configure { $0.maskVariants = [MaskVariant("d"), MaskVariant("dd")] }

        field.textValue = "12"

        XCTAssertEqual(field.text, "12")
        XCTAssertEqual(field.configuration.maskVariants.count, 2)
    }

    // MARK: - Пресеты

    func testPresets() {
        XCTAssertEqual(MaskPreset.card16, "dddd dddd dddd dddd")
        XCTAssertEqual(MaskPreset.otp(length: 6), "dddddd")
        XCTAssertEqual(MaskPreset.otp(length: -1), "")
        XCTAssertEqual(MaskSlot.parse(MaskPreset.cardAmex).filter { $0.canEntered }.count, 15)
        XCTAssertEqual(MaskSlot.parse(MaskPreset.card16).filter { $0.canEntered }.count, 16)
    }
}
