import UIKit

extension MaskTextField: MaskTextFieldProtocol {
    public var culture: NumberFormatter {
        return self.charValidator?.culture ?? (NumberFormatter() => {
            $0.groupingSeparator = Locale.current.groupingSeparator
            $0.decimalSeparator = Locale.current.decimalSeparator
            $0.usesGroupingSeparator = true
            $0.formatterBehavior = .behavior10_4
            $0.numberStyle = .decimal
        })
    }

    public func check(char: Character) -> Bool {
        return self.charValidator?.check(char: char) ?? true
    }

    public func check(string: String) -> Bool {
        return self.charValidator?.check(string: string) ?? true
    }

    public func correct(string: String) -> String {
        return self.charValidator?.correct(string: string) ?? string
    }

    public func setCursorPosition(_ offset: Int) {
        let utf16Offset = (self.text ?? "").utf16Offset(characterIndex: offset)
        let position = self.position(from: self.beginningOfDocument, offset: utf16Offset) ?? self.endOfDocument
        self.selectedTextRange = self.textRange(from: position, to: position)
    }
}
