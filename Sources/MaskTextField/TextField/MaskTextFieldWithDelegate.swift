import UIKit

extension MaskTextField: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        _ = self.externalDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string)

        defer { self.notification() }

        if string.count > 1 {
            self.textValue = self._transformer.normalizedValue(from: self.correct(string: string))

            return false
        }

        if range.location == 0 && range.length == 0 && string.isEmpty {
            self.textValue = ""
            return true
        }

        if range.length == 1 && string.isEmpty {
            self._transformer.onDeleteBackward()
            return false
        }

        self._transformer.onTextInput(string)
        return false
    }

    private func notification() {
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: self, userInfo: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.sendActions(for: .valueChanged)
            self.sendActions(for: .editingChanged)
        }
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.externalDelegate?.textFieldDidBeginEditing?(textField)

        self._transformer.onGotFocus()
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.externalDelegate?.textFieldDidEndEditing?(textField)

        self._transformer.onLostFocus()
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
