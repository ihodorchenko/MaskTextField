import Foundation

/// The base text transformer. Implements the behavior of an "ordinary" text field
/// without a mask: input appends characters, deletion removes the last one.
@MainActor
class BaseTransformer {
    private(set) weak var control: MaskTextFieldProtocol?

    // MARK: - init

    init(textField: MaskTextFieldProtocol) {
        self.control = textField
    }

    // MARK: - property

    var text: String? {
        get {
            self.control?.text
        }
        set {
            self.control?.text = self.sanitized(newValue)
        }
    }

    /// Applies the `CharValidator` restrictions to programmatically set text.
    /// If the result does not pass `check(string:)`, the current text is left unchanged.
    private func sanitized(_ value: String?) -> String? {
        guard let value, let control = self.control else { return value }

        let filtered = control.correct(string: value.filter { control.check(char: $0) })
        return control.check(string: filtered) ? filtered : control.text
    }

    var capacity: Int {
        return 0
    }

    /// Whether all editable positions are filled. Always `false` for a field without a mask.
    var isComplete: Bool {
        return false
    }

    /// Normalizes a string for pasting. For a field without a mask it returns the string
    /// unchanged; subclasses may override it (for example, to strip a mask).
    func normalizedValue(from value: String) -> String {
        return value
    }

    // MARK: - func

    func onGotFocus() {
        // virtual
    }

    func onLostFocus() {
        // virtual
    }

    func onSelectionChanged() {
        // virtual
    }

    @discardableResult
    func onTextInput(_ text: String, at offset: Int = 0) -> Bool {
        // virtual
        self.text = (self.text ?? "") + text
        return true
    }

    /// Replaces the `range` (in characters of the current text) with the string `text`
    /// and puts the cursor after the inserted fragment. Used for pasting from the
    /// pasteboard and for replacing a selection.
    func onPaste(_ text: String, in range: Range<Int>) {
        var chars = Array(self.text ?? "")
        let lower = min(max(range.lowerBound, 0), chars.count)
        let upper = min(max(range.upperBound, lower), chars.count)

        chars.replaceSubrange(lower..<upper, with: Array(text))
        self.text = String(chars)
        self.control?.setCursorPosition(lower + text.count)
    }

    func onDeleteBackward(at offset: Int = Int.max) {
        // virtual
        guard !(self.text ?? "").isEmpty else { return }
        _ = self.text?.removeLast()
    }
}
