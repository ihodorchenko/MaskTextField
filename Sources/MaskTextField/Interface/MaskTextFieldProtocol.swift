import Foundation

/// Абстракция над `UITextField`, с которой работают трансформеры.
///
/// Протокол не зависит от UIKit: всё позиционирование курсора свёрнуто в
/// один метод `setCursorPosition(_:)`, работающий с целочисленным смещением.
/// Благодаря этому логику маски можно тестировать без `UITextField` и без UIKit.
public protocol MaskTextFieldProtocol: AnyObject {
    var text: String? { get set }
    var culture: NumberFormatter { get }

    func check(char: Character) -> Bool
    func check(string: String) -> Bool
    func correct(string: String) -> String

    /// Устанавливает курсор на позицию `offset` (в символах).
    func setCursorPosition(_ offset: Int)

    /// Текущая позиция курсора (в символах).
    var cursorOffset: Int { get }
}
