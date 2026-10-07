import UIKit
import SwiftUI
import MaskTextField

/// SwiftUI-обёртка над `MaskTextField`.
///
/// Позволяет использовать маскированный ввод в SwiftUI без ручного создания
/// `UIViewRepresentable`. Сырое значение (без маски) синхронизируется со
/// SwiftUI-состоянием через привязку `textValue`.
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
    /// Маска, отображаемая во время редактирования, например `+375 (dd) ddd-dd-dd`.
    public var mask: String

    /// Маска, отображаемая при потере фокуса; символ `^` скрывает введённое.
    public var maskLostFocus: String

    /// Режим отображения маски: `.fullMask` — вся маска, `.gradualMask` — по мере ввода.
    public var maskMode: MaskMode

    /// Символ-заглушка для пустых вводимых позиций (`_` по умолчанию).
    public var maskChar: Character

    /// Символ, которым скрываются введённые символы при потере фокуса (`•` по умолчанию).
    public var veiledMaskChar: Character

    /// Режим пароля: введённый символ скрывается спустя короткую задержку.
    public var hideChars: Bool

    /// Скрывать маску, если значение пустое и поле не в фокусе.
    public var hiddenMaskIfEnteredTextEmpty: Bool

    /// Текст-подсказка (placeholder) поля.
    public var placeholder: String?

    /// Тип клавиатуры.
    public var keyboardType: UIKeyboardType

    /// Сырое значение без маски (двусторонняя привязка к SwiftUI-состоянию).
    @Binding public var textValue: String

    /// Создаёт маскированное поле.
    ///
    /// - Parameters:
    ///   - mask: маска во время редактирования.
    ///   - maskLostFocus: маска при потере фокуса (по умолчанию пустая).
    ///   - maskMode: режим отображения маски.
    ///   - maskChar: символ-заглушка.
    ///   - veiledMaskChar: символ скрытия при потере фокуса.
    ///   - hideChars: режим пароля.
    ///   - hiddenMaskIfEnteredTextEmpty: скрывать пустую маску.
    ///   - placeholder: подсказка.
    ///   - keyboardType: тип клавиатуры.
    ///   - textValue: привязка к сырому значению.
    public init(
        mask: String,
        maskLostFocus: String = "",
        maskMode: MaskMode = .fullMask,
        maskChar: Character = "_",
        veiledMaskChar: Character = "•",
        hideChars: Bool = false,
        hiddenMaskIfEnteredTextEmpty: Bool = false,
        placeholder: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textValue: Binding<String>
    ) {
        self.mask = mask
        self.maskLostFocus = maskLostFocus
        self.maskMode = maskMode
        self.maskChar = maskChar
        self.veiledMaskChar = veiledMaskChar
        self.hideChars = hideChars
        self.hiddenMaskIfEnteredTextEmpty = hiddenMaskIfEnteredTextEmpty
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self._textValue = textValue
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MaskTextField {
        let field = MaskTextField()
        apply(to: field)
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return field
    }

    public func updateUIView(_ field: MaskTextField, context: Context) {
        apply(to: field)

        // Синхронизируем значение только при расхождении, чтобы не зациклить обновления.
        if field.textValue != textValue {
            field.textValue = textValue
        }
    }

    /// Применяет конфигурацию к полю только при её изменении — чтобы лишние
    /// перерисовки SwiftUI не сбрасывали курсор и уже введённое значение.
    private func apply(to field: MaskTextField) {
        if field.maskText != mask { field.maskText = mask }
        if field.maskLostFocus != maskLostFocus { field.maskLostFocus = maskLostFocus }
        if field.maskMode != maskMode { field.maskMode = maskMode }
        if field.maskChar != maskChar { field.maskChar = maskChar }
        if field.veiledMaskChar != veiledMaskChar { field.veiledMaskChar = veiledMaskChar }
        if field.hideChars != hideChars { field.hideChars = hideChars }
        if field.hiddenMaskIfEnteredTextEmpty != hiddenMaskIfEnteredTextEmpty { field.hiddenMaskIfEnteredTextEmpty = hiddenMaskIfEnteredTextEmpty }
        if field.placeholder != placeholder { field.placeholder = placeholder }
        if field.keyboardType != keyboardType { field.keyboardType = keyboardType }
    }

    /// Связывает `MaskTextField` со SwiftUI-состоянием и пробрасывает
    /// изменения сырого значения обратно в привязку `textValue`.
    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaskedTextField

        init(_ parent: MaskedTextField) {
            self.parent = parent
        }

        public func textFieldDidChangeSelection(_ textField: UITextField) {
            guard let field = textField as? MaskTextField else { return }
            let value = field.textValue ?? ""
            if parent.textValue != value {
                DispatchQueue.main.async {
                    self.parent.textValue = value
                }
            }
        }
    }
}
