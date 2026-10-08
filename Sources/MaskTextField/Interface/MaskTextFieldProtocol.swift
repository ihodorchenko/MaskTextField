import Foundation

/// An abstraction over `UITextField` that the transformers work with.
///
/// The protocol does not depend on UIKit: all cursor positioning is folded into
/// the single method `setCursorPosition(_:)`, which works with an integer offset.
/// This makes it possible to test the mask logic without a `UITextField` and without UIKit.
@MainActor
public protocol MaskTextFieldProtocol: AnyObject {
    var text: String? { get set }

    func check(char: Character) -> Bool
    func check(string: String) -> Bool
    func correct(string: String) -> String

    /// Puts the cursor at position `offset` (in characters).
    func setCursorPosition(_ offset: Int)

    /// The current cursor position (in characters).
    var cursorOffset: Int { get }
}
