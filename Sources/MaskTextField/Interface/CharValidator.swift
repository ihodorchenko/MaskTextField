import Foundation

/// Валидатор вводимых символов.
///
/// Позволяет задать дополнительные ограничения на вводимые символы
/// (например, только цифры для десятичного ввода) и нормализовать строку.
public protocol CharValidator: AnyObject {
    func check(char: Character) -> Bool
    func check(string: String) -> Bool
    func correct(string: String) -> String
    var culture: NumberFormatter { get }
}
