import Foundation

/// A validator of entered characters.
///
/// Restricts input in `MaskTextField`, both in a field without a mask (for example, forbidding emoji)
/// and in a masked field (an extra restriction on top of the position types).
///
/// All methods have default implementations — override only the ones you need.
///
/// - A field without a mask: the characters of a typed or pasted string go through `check(char:)`,
///   then the string through `correct(string:)`; the resulting text as a whole through `check(string:)`.
/// - A masked field: only `check(char:)` and `correct(string:)` are used.
public protocol CharValidator: AnyObject {
    /// Whether a character is acceptable. Unacceptable characters are removed from the entered string.
    func check(char: Character) -> Bool

    /// Whether the resulting text as a whole is acceptable (for example a length limit).
    /// If not, the change is rejected.
    func check(string: String) -> Bool

    /// Corrects the entered string after per-character filtering.
    func correct(string: String) -> String

    /// The number formatter for decimal separators.
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
