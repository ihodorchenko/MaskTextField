import Foundation
import UIKit

/// Абстракция над `UITextField`, с которой работают трансформеры.
///
/// Вынесена в протокол, чтобы логику маски можно было тестировать
/// без реального `UITextField`, подставляя mock-объект.
public protocol ICMaskTextFieldProtocol: AnyObject {
    var text: String? { get set }
    var culture: NumberFormatter { get }

    func check(char: Character) -> Bool
    func check(string: String) -> Bool
    func correct(string: String) -> String

    var selectedTextRange: UITextRange? { get set }
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange?
    func position(from position: UITextPosition, offset: Int) -> UITextPosition?
    var beginningOfDocument: UITextPosition { get }
    var endOfDocument: UITextPosition { get }
}
