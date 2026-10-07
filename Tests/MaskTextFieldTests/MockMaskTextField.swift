import UIKit
@testable import MaskTextField

/// Минимальная реализация `ICMaskTextFieldProtocol` для юнит-тестов трансформеров.
/// Не использует реальный `UITextField`, поэтому тесты выполняются быстро и детерминированно.
final class MockMaskTextField: ICMaskTextFieldProtocol {
    var text: String?
    var culture: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.decimalSeparator = "."
        f.groupingSeparator = ","
        return f
    }()

    var selectedTextRange: UITextRange?

    private let begin = UITextPosition()
    private let end = UITextPosition()

    func check(char: Character) -> Bool { true }
    func check(string: String) -> Bool { true }
    func correct(string: String) -> String { string }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        UITextRange()
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        UITextPosition()
    }

    var beginningOfDocument: UITextPosition { begin }
    var endOfDocument: UITextPosition { end }
}
