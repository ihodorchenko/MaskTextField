import UIKit

extension ICMaskTextField: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        _ = self._delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string)

        defer { self.notification() }

        if string.count > 1 {
            var newString = self.correct(string: string)

            if !newString.isEmpty {
                let onlyEnteredCount: Int = self._transformer.onlyEnteredCount

                newString = newString.count < onlyEnteredCount ? newString :
                newString.substring(start: newString.count - onlyEnteredCount, length: onlyEnteredCount)
            }

            self.textValue = newString

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
        self._delegate?.textFieldDidBeginEditing?(textField)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            self._transformer.onGotFocus()
        })
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        self._delegate?.textFieldDidEndEditing?(textField)

        self._transformer.onLostFocus()
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self._delegate?.textFieldShouldBeginEditing?(textField) ?? true
    }

    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return self._delegate?.textFieldShouldEndEditing?(textField) ?? true
    }

    public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        self._delegate?.textFieldDidEndEditing?(textField, reason: reason)

        self._transformer.onLostFocus()
    }

    public func textFieldDidChangeSelection(_ textField: UITextField) {
        self._delegate?.textFieldDidChangeSelection?(textField)

        self._transformer.onSelectionChanged()
    }

    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return self._delegate?.textFieldShouldClear?(textField) ?? true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self._delegate?.textFieldShouldReturn?(textField) ?? true
    }
}
