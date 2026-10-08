import XCTest
import UIKit
@testable import MaskTextField

@MainActor
final class EmojiDetectionTests: XCTestCase {

    func testEmojiClustersAreDetectedAsWhole() {
        let emoji: [Character] = [
            "😀",
            "👨‍👩‍👧",   // ZWJ-последовательность
            "🇧🇾",      // флаг
            "👍🏽",      // цвет кожи
            "1️⃣",      // keycap
            "❤️"        // текстовый символ с селектором эмодзи
        ]

        for char in emoji {
            XCTAssertTrue(char.isEmojiCharacter, "\(char) должен считаться эмодзи")
        }
    }

    func testPlainSymbolsAreNotEmoji() {
        let plain: [Character] = ["a", "Я", "1", "#", "*", "©", "™", "❤", " ", "٣"]

        for char in plain {
            XCTAssertFalse(char.isEmojiCharacter, "\(char) не должен считаться эмодзи")
        }
    }
}

@MainActor
final class BuiltInValidatorTests: XCTestCase {

    func testEmojiFreeValidator() {
        let validator = EmojiFreeValidator()

        XCTAssertTrue(validator.check(char: "a"))
        XCTAssertFalse(validator.check(char: "😀"))
    }

    func testAllowedCharactersValidator() {
        let validator = AllowedCharactersValidator(allowed: CharacterSet(charactersIn: "abc"))

        XCTAssertTrue(validator.check(char: "a"))
        XCTAssertFalse(validator.check(char: "z"))
    }

    func testMaxLengthValidator() {
        let validator = MaxLengthValidator(maxLength: 3)

        XCTAssertTrue(validator.check(string: "abc"))
        XCTAssertFalse(validator.check(string: "abcd"))
    }

    func testCompositeValidatorRequiresAll() {
        let validator = CompositeValidator([
            EmojiFreeValidator(),
            AllowedCharactersValidator(allowed: CharacterSet(charactersIn: "ab😀"))
        ])

        XCTAssertTrue(validator.check(char: "a"))
        XCTAssertFalse(validator.check(char: "😀"))
        XCTAssertFalse(validator.check(char: "z"))
    }
}

/// Ограничение ввода через `charValidator` в реальном `MaskTextField`.
@MainActor
final class CharValidatorFieldTests: XCTestCase {

    private var field: MaskTextField!

    override func setUp() {
        super.setUp()
        field = MaskTextField()
    }

    override func tearDown() {
        field = nil
        super.tearDown()
    }

    // MARK: - Владение

    func testValidatorCreatedInlineIsRetained() {
        field.charValidator = EmojiFreeValidator()

        XCTAssertNotNil(field.charValidator)
    }

    // MARK: - Поле без маски

    func testPlainFieldStaysNativeWithoutValidator() {
        XCTAssertTrue(change("😀"))
    }

    func testPlainFieldRejectsEmoji() {
        field.charValidator = EmojiFreeValidator()
        field.text = "ab"

        XCTAssertFalse(change("😀", location: 1))
        XCTAssertEqual(field.text, "ab")
    }

    func testPlainFieldAcceptsValidInputNatively() {
        field.charValidator = EmojiFreeValidator()

        // Строка не изменилась фильтром — UIKit вставляет её сам (курсор, undo, IME).
        XCTAssertTrue(change("a"))
    }

    func testPlainFieldStripsEmojiFromPastedStringIntoMiddle() {
        field.charValidator = EmojiFreeValidator()
        field.text = "ad"

        let result = change("b😀c", location: 1)

        XCTAssertFalse(result)
        XCTAssertEqual(field.text, "abcd")
    }

    func testPlainFieldDeletionStaysNative() {
        field.charValidator = EmojiFreeValidator()
        field.text = "abc"

        XCTAssertTrue(change("", location: 1, length: 1))
    }

    func testPlainFieldRejectsChangeThatBreaksCheckString() {
        field.charValidator = MaxLengthValidator(maxLength: 3)
        field.text = "abc"

        XCTAssertFalse(change("d", location: 3))
        XCTAssertEqual(field.text, "abc")
    }

    func testProgrammaticValueIsSanitized() {
        field.charValidator = EmojiFreeValidator()

        field.textValue = "a😀b"

        XCTAssertEqual(field.text, "ab")
    }

    func testProgrammaticValueFailingCheckStringIsIgnored() {
        field.charValidator = MaxLengthValidator(maxLength: 2)
        field.textValue = "ab"

        field.textValue = "abcd"

        XCTAssertEqual(field.text, "ab")
    }

    // MARK: - Поле с маской

    func testValidatorRestrictsMaskedInputFurther() {
        field.maskText = "dd"
        field.charValidator = AllowedCharactersValidator(allowed: CharacterSet(charactersIn: "12"))

        _ = change("3")
        XCTAssertEqual(field.textValue, "")

        _ = change("2")
        XCTAssertEqual(field.textValue, "2")
    }

    func testValidatorFiltersPastedValueIntoMask() {
        field.maskText = "dd-dd"
        field.charValidator = AllowedCharactersValidator(allowed: CharacterSet(charactersIn: "12"))

        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "13243"
        )

        XCTAssertEqual(field.textValue, "12")
    }

    // MARK: - Helpers

    private func change(_ string: String, location: Int = 0, length: Int = 0) -> Bool {
        field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: location, length: length),
            replacementString: string
        )
    }
}
