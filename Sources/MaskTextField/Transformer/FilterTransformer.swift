import Foundation

/// Трансформер, фильтрующий вводимые символы через `CharValidator`
/// и нормализующий десятичные разделители под текущую культуру.
open class FilterTransformer: BaseTransformer {
    private let delimiters: [String] = [".", ","]

    open override var text: String? {
        get {
            super.text
        }
        set {
            guard let control = self.control else {
                super.text = newValue
                return
            }

            var value: String = newValue ?? ""

            for delimiter in self.delimiters {
                value = value.replacingOccurrences(
                    of: delimiter,
                    with: control.culture.decimalSeparator,
                    options: NSString.CompareOptions.literal,
                    range: nil
                )
            }

            if super.text == newValue
                && value.allSatisfy({ control.check(char: $0) })
                && control.check(string: value) {
                return
            }

            var s = value.filter { control.check(char: $0) }
            s = control.correct(string: s)
            super.text = s
            control.setCursorPosition(s.count)
        }
    }

    open override func onTextInput(_ text: String) -> Bool {
        if text.count != 1 {
            return true
        }

        return self.control?.check(char: text[0]) ?? false
    }
}
