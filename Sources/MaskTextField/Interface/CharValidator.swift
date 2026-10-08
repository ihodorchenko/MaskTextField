import Foundation

/// Валидатор вводимых символов.
///
/// Ограничивает ввод в `MaskTextField`: и в поле без маски (например, запретить эмодзи),
/// и в поле с маской (дополнительное ограничение поверх типов позиций).
///
/// Все методы имеют реализации по умолчанию — переопределяйте только нужные.
///
/// - Поле без маски: символы вводимой или вставляемой строки проходят `check(char:)`,
///   затем строка — `correct(string:)`; результирующий текст целиком — `check(string:)`.
/// - Поле с маской: используются только `check(char:)` и `correct(string:)`.
public protocol CharValidator: AnyObject {
    /// Допустим ли символ. Недопустимые символы удаляются из вводимой строки.
    func check(char: Character) -> Bool

    /// Допустим ли результирующий текст целиком (например, ограничение длины).
    /// Если нет — изменение отклоняется.
    func check(string: String) -> Bool

    /// Корректирует вводимую строку после посимвольной фильтрации.
    func correct(string: String) -> String

    /// Форматтер чисел для десятичных разделителей.
    var culture: NumberFormatter { get }
}

public extension CharValidator {
    func check(char: Character) -> Bool { true }
    func check(string: String) -> Bool { true }
    func correct(string: String) -> String { string }

    var culture: NumberFormatter {
        NumberFormatter() => {
            $0.locale = .current
            $0.groupingSeparator = Locale.current.groupingSeparator
            $0.decimalSeparator = Locale.current.decimalSeparator
            $0.usesGroupingSeparator = true
            $0.formatterBehavior = .behavior10_4
            $0.numberStyle = .decimal
        }
    }
}
