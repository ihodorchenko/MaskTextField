import UIKit

extension MaskTextField: MaskTextFieldProtocol {
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

    public var cursorOffset: Int {
        guard let range = self.selectedTextRange else { return 0 }
        let utf16Offset = self.offset(from: self.beginningOfDocument, to: range.start)
        return (self.text ?? "").characterIndex(utf16Offset: utf16Offset)
    }
}
