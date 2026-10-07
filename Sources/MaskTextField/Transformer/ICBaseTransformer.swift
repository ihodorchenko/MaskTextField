import Foundation

/// Базовый трансформер текста. Реализует поведение "обычного" текстового поля
/// без маски: ввод добавляет символы, удаление — убирает последний.
open class ICBaseTransformer {
    public private(set) weak var control: ICMaskTextFieldProtocol?

    // MARK: - init

    public init(textField: ICMaskTextFieldProtocol) {
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
    open func onTextInput(_ text: String) -> Bool {
        // virtual
        self.text = (self.text ?? "") + text
        return true
    }

    open func onDeleteBackward() {
        // virtual
        guard !(self.text ?? "").isEmpty else { return }
        _ = self.text?.removeLast()
    }
}
