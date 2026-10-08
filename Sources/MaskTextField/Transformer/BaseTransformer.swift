import Foundation

/// Базовый трансформер текста. Реализует поведение "обычного" текстового поля
/// без маски: ввод добавляет символы, удаление — убирает последний.
open class BaseTransformer {
    public private(set) weak var control: MaskTextFieldProtocol?

    // MARK: - init

    public init(textField: MaskTextFieldProtocol) {
        self.control = textField
    }

    // MARK: - property

    open var text: String? {
        get {
            self.control?.text
        }
        set {
            self.control?.text = newValue
        }
    }

    open var onlyEnteredCount: Int {
        return 0
    }

    /// Нормализует строку для вставки. Для поля без маски возвращает строку
    /// без изменений; подклассы могут переопределить (например, снять маску).
    open func normalizedValue(from value: String) -> String {
        return value
    }

    // MARK: - func

    open func onGotFocus() {
        // virtual
    }

    open func onLostFocus() {
        // virtual
    }

    open func onSelectionChanged() {
        // virtual
    }

    @discardableResult
    open func onTextInput(_ text: String, at offset: Int = 0) -> Bool {
        // virtual
        self.text = (self.text ?? "") + text
        return true
    }

    /// Заменяет диапазон `range` (в символах текущего текста) строкой `text`
    /// и ставит курсор за вставленным фрагментом. Используется для вставки из
    /// буфера обмена и замены выделения.
    open func onPaste(_ text: String, in range: Range<Int>) {
        var chars = Array(self.text ?? "")
        let lower = min(max(range.lowerBound, 0), chars.count)
        let upper = min(max(range.upperBound, lower), chars.count)

        chars.replaceSubrange(lower..<upper, with: Array(text))
        self.text = String(chars)
        self.control?.setCursorPosition(lower + text.count)
    }

    open func onDeleteBackward(at offset: Int = Int.max) {
        // virtual
        guard !(self.text ?? "").isEmpty else { return }
        _ = self.text?.removeLast()
    }
}
