import UIKit
import SwiftUI
import Combine
import MaskTextField

/// A SwiftUI wrapper around `MaskTextField`.
///
/// Lets you use masked input in SwiftUI without writing a `UIViewRepresentable` by hand.
/// The raw value (without the mask) is synchronized with SwiftUI state through
/// the `textValue` binding.
///
/// ```swift
/// @State private var phone = ""
///
/// MaskedTextField(
///     mask: "+375 (dd) ddd-dd-dd",
///     maskLostFocus: "+375 (^d^d) ^d^d^d-^d^d-^d^d",
///     keyboardType: .numberPad,
///     textValue: $phone
/// )
/// ```
public struct MaskedTextField: UIViewRepresentable {
    /// The mask shown while editing, e.g. `+375 (dd) ddd-dd-dd`.
    public var mask: String

    /// The mask shown when the field loses focus; the `^` character veils entered characters.
    public var maskLostFocus: String

    /// Dynamic masks by capacity (ascending): the first one the value fits into is chosen.
    /// If set, `mask` and `maskLostFocus` are not used.
    public var maskVariants: [MaskVariant]

    /// Dynamic masks by an arbitrary rule (for example `MaskPreset.cardProvider`).
    /// Applied once when the field is created; to change it, recreate the view (`.id(...)`).
    public var maskProvider: ((String) -> MaskVariant)?

    /// The mask display mode: `.fullMask` shows the whole mask, `.gradualMask` shows it as you type.
    public var maskMode: MaskMode

    /// The cursor behavior: `.free`, `.snapOnFocus` or `.sequential` (sequential input only).
    public var cursorBehavior: CursorBehavior

    /// The placeholder character for empty editable positions (`_` by default).
    public var maskChar: Character

    /// The character that veils entered characters when the field loses focus (`•` by default).
    public var veiledMaskChar: Character

    /// Password mode: an entered character is veiled after a short delay.
    public var hideChars: Bool

    /// Hide the mask when the value is empty and the field is not focused.
    public var hiddenMaskIfEnteredTextEmpty: Bool

    /// The field's placeholder text.
    public var placeholder: String?

    /// The keyboard type.
    public var keyboardType: UIKeyboardType

    /// The text font; `nil` means do not override.
    public var font: UIFont?

    /// The text color; `nil` means do not override.
    public var textColor: UIColor?

    /// The text alignment.
    public var textAlignment: NSTextAlignment

    /// The Return key type.
    public var returnKeyType: UIReturnKeyType

    /// The clear button mode.
    public var clearButtonMode: UITextField.ViewMode

    /// Forces the value to be laid out left to right, including in an RTL interface.
    public var forcesLeftToRight: Bool

    /// Disables keyboard autocorrection and smart substitutions (`true` by default).
    public var disablesAutocorrection: Bool

    /// Makes VoiceOver announce rejected characters and a filled mask.
    public var announcesInputEvents: Bool

    /// The field's VoiceOver label.
    public var accessibilityLabelText: String?

    /// The field's VoiceOver hint (for example the input format).
    public var accessibilityHintText: String?

    /// The raw value without the mask (a two-way binding to SwiftUI state).
    @Binding public var textValue: String

    /// An optional binding to the focus state (`true` means the field is focused).
    private var isFocused: Binding<Bool>?

    /// Called when the Return key is pressed.
    private var onCommit: (() -> Void)?

    /// An optional binding to the "mask is filled" state.
    private var isComplete: Binding<Bool>?

    /// Called when the user fills the mask with their input.
    private var onComplete: (() -> Void)?

    /// Creates a masked field.
    ///
    /// - Parameters:
    ///   - mask: the mask while editing.
    ///   - maskLostFocus: the mask when the field loses focus (empty by default).
    ///   - maskVariants: dynamic masks by capacity (instead of `mask`).
    ///   - maskProvider: dynamic masks by an arbitrary rule (applied when the field is created).
    ///   - maskMode: the mask display mode.
    ///   - cursorBehavior: the cursor behavior.
    ///   - maskChar: the placeholder character.
    ///   - veiledMaskChar: the veiling character used when focus is lost.
    ///   - hideChars: password mode.
    ///   - hiddenMaskIfEnteredTextEmpty: hide an empty mask.
    ///   - placeholder: the placeholder text.
    ///   - keyboardType: the keyboard type.
    ///   - font: the text font.
    ///   - textColor: the text color.
    ///   - textAlignment: the text alignment.
    ///   - returnKeyType: the Return key type.
    ///   - clearButtonMode: the clear button mode.
    ///   - forcesLeftToRight: lay the value out left to right in RTL too.
    ///   - disablesAutocorrection: disable keyboard autocorrection and substitutions.
    ///   - announcesInputEvents: announce rejected characters and a filled mask.
    ///   - accessibilityLabelText: the VoiceOver label.
    ///   - accessibilityHintText: the VoiceOver hint.
    ///   - isFocused: a binding to the focus state (read and drive).
    ///   - onCommit: the Return key handler.
    ///   - isComplete: a binding to the "mask is filled" state.
    ///   - onComplete: the handler for the user filling the mask.
    ///   - textValue: a binding to the raw value.
    public init(
        mask: String = "",
        maskLostFocus: String = "",
        maskVariants: [MaskVariant] = [],
        maskProvider: ((String) -> MaskVariant)? = nil,
        maskMode: MaskMode = .fullMask,
        cursorBehavior: CursorBehavior = .free,
        maskChar: Character = MaskConfiguration.defaultMaskChar,
        veiledMaskChar: Character = MaskConfiguration.defaultVeiledMaskChar,
        hideChars: Bool = false,
        hiddenMaskIfEnteredTextEmpty: Bool = false,
        placeholder: String? = nil,
        keyboardType: UIKeyboardType = .default,
        font: UIFont? = nil,
        textColor: UIColor? = nil,
        textAlignment: NSTextAlignment = .natural,
        returnKeyType: UIReturnKeyType = .default,
        clearButtonMode: UITextField.ViewMode = .never,
        forcesLeftToRight: Bool = true,
        disablesAutocorrection: Bool = true,
        announcesInputEvents: Bool = false,
        accessibilityLabelText: String? = nil,
        accessibilityHintText: String? = nil,
        isFocused: Binding<Bool>? = nil,
        onCommit: (() -> Void)? = nil,
        isComplete: Binding<Bool>? = nil,
        onComplete: (() -> Void)? = nil,
        textValue: Binding<String>
    ) {
        self.mask = mask
        self.maskLostFocus = maskLostFocus
        self.maskVariants = maskVariants
        self.maskProvider = maskProvider
        self.maskMode = maskMode
        self.cursorBehavior = cursorBehavior
        self.maskChar = maskChar
        self.veiledMaskChar = veiledMaskChar
        self.hideChars = hideChars
        self.hiddenMaskIfEnteredTextEmpty = hiddenMaskIfEnteredTextEmpty
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.font = font
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.returnKeyType = returnKeyType
        self.clearButtonMode = clearButtonMode
        self.forcesLeftToRight = forcesLeftToRight
        self.disablesAutocorrection = disablesAutocorrection
        self.announcesInputEvents = announcesInputEvents
        self.accessibilityLabelText = accessibilityLabelText
        self.accessibilityHintText = accessibilityHintText
        self.isFocused = isFocused
        self.onCommit = onCommit
        self.isComplete = isComplete
        self.onComplete = onComplete
        self._textValue = textValue
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MaskTextField {
        let field = MaskTextField()
        apply(to: field)
        if let maskProvider { field.maskProvider = maskProvider }
        field.delegate = context.coordinator
        field.onComplete = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onComplete?()
        }
        // The notification comes only from user actions (typing, pasting, deleting,
        // clearing), not from SwiftUI setting the value programmatically, and does not depend
        // on target-action delivery.
        context.coordinator.observeEdits(of: field)
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return field
    }

    public func updateUIView(_ field: MaskTextField, context: Context) {
        context.coordinator.parent = self
        apply(to: field)

        // Sync the value only when it differs, to avoid an update loop.
        if field.textValue != textValue {
            field.textValue = textValue
        }

        syncFocus(of: field)
        syncCompletion(of: field)
    }

    /// Updates the `isComplete` binding after programmatic changes of the value.
    private func syncCompletion(of field: MaskTextField) {
        guard let binding = isComplete, binding.wrappedValue != field.isComplete else { return }

        // Writing state inside a SwiftUI update cycle is not allowed.
        DispatchQueue.main.async {
            binding.wrappedValue = field.isComplete
        }
    }

    /// Brings the field's focus in line with the `isFocused` binding.
    private func syncFocus(of field: MaskTextField) {
        guard let wantsFocus = isFocused?.wrappedValue else { return }

        // Changing the first responder inside a SwiftUI update cycle is unstable.
        DispatchQueue.main.async {
            if wantsFocus, !field.isFirstResponder {
                field.becomeFirstResponder()
            } else if !wantsFocus, field.isFirstResponder {
                field.resignFirstResponder()
            }
        }
    }

    /// Applies the configuration to the field only when it changes, so that extra SwiftUI
    /// redraws do not reset the cursor and the already entered value.
    private func apply(to field: MaskTextField) {
        if field.maskVariants != maskVariants { field.maskVariants = maskVariants }
        if field.maskText != mask { field.maskText = mask }
        if field.maskLostFocus != maskLostFocus { field.maskLostFocus = maskLostFocus }
        if field.maskMode != maskMode { field.maskMode = maskMode }
        if field.cursorBehavior != cursorBehavior { field.cursorBehavior = cursorBehavior }
        if field.maskChar != maskChar { field.maskChar = maskChar }
        if field.veiledMaskChar != veiledMaskChar { field.veiledMaskChar = veiledMaskChar }
        if field.hideChars != hideChars { field.hideChars = hideChars }
        if field.hiddenMaskIfEnteredTextEmpty != hiddenMaskIfEnteredTextEmpty { field.hiddenMaskIfEnteredTextEmpty = hiddenMaskIfEnteredTextEmpty }
        if field.placeholder != placeholder { field.placeholder = placeholder }
        if field.keyboardType != keyboardType { field.keyboardType = keyboardType }
        if let font, field.font != font { field.font = font }
        if let textColor, field.textColor != textColor { field.textColor = textColor }
        if field.textAlignment != textAlignment { field.textAlignment = textAlignment }
        if field.returnKeyType != returnKeyType { field.returnKeyType = returnKeyType }
        if field.clearButtonMode != clearButtonMode { field.clearButtonMode = clearButtonMode }
        if field.forcesLeftToRight != forcesLeftToRight { field.forcesLeftToRight = forcesLeftToRight }
        if field.disablesAutocorrection != disablesAutocorrection { field.disablesAutocorrection = disablesAutocorrection }
        if field.announcesInputEvents != announcesInputEvents { field.announcesInputEvents = announcesInputEvents }
        if field.accessibilityLabel != accessibilityLabelText { field.accessibilityLabel = accessibilityLabelText }
        if field.accessibilityHint != accessibilityHintText { field.accessibilityHint = accessibilityHintText }
    }

    /// Connects `MaskTextField` with SwiftUI state and passes changes of the raw value
    /// and of focus back into the bindings.
    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaskedTextField

        init(_ parent: MaskedTextField) {
            self.parent = parent
        }

        // The subscription cancels itself when the coordinator is released.
        private var editsSubscription: AnyCancellable?

        func observeEdits(of field: MaskTextField) {
            // Without `receive(on:)` the handler runs synchronously on the posting (main) thread.
            editsSubscription = NotificationCenter.default
                .publisher(for: UITextField.textDidChangeNotification, object: field)
                .sink { [weak self, weak field] _ in
                    guard let self, let field else { return }
                    self.fieldDidChange(field)
                }
        }

        private func fieldDidChange(_ field: MaskTextField) {
            let value = field.textValue
            if parent.textValue != value {
                parent.textValue = value
            }
            if let binding = parent.isComplete, binding.wrappedValue != field.isComplete {
                binding.wrappedValue = field.isComplete
            }
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            if parent.isFocused?.wrappedValue == false {
                parent.isFocused?.wrappedValue = true
            }
        }

        public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
            if parent.isFocused?.wrappedValue == true {
                parent.isFocused?.wrappedValue = false
            }
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            return true
        }
    }
}
