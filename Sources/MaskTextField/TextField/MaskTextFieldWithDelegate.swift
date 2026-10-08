import UIKit

extension MaskTextField: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Пользовательский делегат может отклонить ввод; в этом случае маска не трогается.
        if let externalResult = self.externalDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string),
           !externalResult {
            return false
        }

        defer { self.notification() }

        if range.location == 0 && range.length == 0 && string.isEmpty {
            self.textValue = ""
            return true
        }

        // Вставка, замена выделения и удаление выделенного фрагмента: трансформер
        // получает диапазон и сохраняет остальное значение.
        let isSingleBackspace = range.length == 1 && string.isEmpty
        if string.count > 1 || (range.length > 0 && !isSingleBackspace) {
            let current = self.text ?? ""
            let lower = current.characterIndex(utf16Offset: range.location)
            let upper = current.characterIndex(utf16Offset: range.location + range.length)

            self._transformer.onPaste(self.correct(string: string), in: lower..<max(lower, upper))
            return false
        }

        if range.length == 1 && string.isEmpty {
            self._transformer.onDeleteBackward(at: (self.text ?? "").characterIndex(utf16Offset: range.location))
            return false
        }

        self._transformer.onTextInput(string, at: (self.text ?? "").characterIndex(utf16Offset: range.location))
        return false
    }

    func notification() {
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: self, userInfo: nil)

        self.sendActions(for: .valueChanged)
        self.sendActions(for: .editingChanged)
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.externalDelegate?.textFieldDidBeginEditing?(textField)

        self._transformer.onGotFocus()
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.externalDelegate?.textFieldShouldBeginEditing?(textField) ?? true
    }

    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return self.externalDelegate?.textFieldShouldEndEditing?(textField) ?? true
    }

    public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        self.externalDelegate?.textFieldDidEndEditing?(textField, reason: reason)

        self._transformer.onLostFocus()
    }

    public func textFieldDidChangeSelection(_ textField: UITextField) {
        self.externalDelegate?.textFieldDidChangeSelection?(textField)

        self._transformer.onSelectionChanged()
    }

    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return self.externalDelegate?.textFieldShouldClear?(textField) ?? true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.externalDelegate?.textFieldShouldReturn?(textField) ?? true
    }
}
