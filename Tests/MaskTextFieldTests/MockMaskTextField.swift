import Foundation
@testable import MaskTextField

/// Минимальная реализация `MaskTextFieldProtocol` для юнит-тестов трансформеров.
/// Не зависит от UIKit и не использует реальный `UITextField`, поэтому тесты
/// выполняются быстро и детерминированно.
@MainActor
final class MockMaskTextField: MaskTextFieldProtocol {
    var text: String?

    /// Последняя позиция курсора, запрошенная трансформером.
    private(set) var cursorPosition: Int = 0

    func check(char: Character) -> Bool { true }
    func check(string: String) -> Bool { true }
    func correct(string: String) -> String { string }

    func setCursorPosition(_ offset: Int) {
        cursorPosition = offset
    }

    var cursorOffset: Int { cursorPosition }
}
