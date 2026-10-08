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

    /// Шрифт текста; `nil` — не переопределять.
    public var font: UIFont?

    /// Цвет текста; `nil` — не переопределять.
    public var textColor: UIColor?

    /// Выравнивание текста.
    public var textAlignment: NSTextAlignment

    /// Вид клавиши Return.
    public var returnKeyType: UIReturnKeyType

    /// Режим кнопки очистки.
    public var clearButtonMode: UITextField.ViewMode

    /// Сырое значение без маски (двусторонняя привязка к SwiftUI-состоянию).
    @Binding public var textValue: String

    /// Необязательная привязка к состоянию фокуса (`true` — поле в фокусе).
    private var isFocused: Binding<Bool>?

    /// Вызывается по нажатию Return.
    private var onCommit: (() -> Void)?

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
    ///   - font: шрифт текста.
    ///   - textColor: цвет текста.
    ///   - textAlignment: выравнивание текста.
    ///   - returnKeyType: вид клавиши Return.
    ///   - clearButtonMode: режим кнопки очистки.
    ///   - isFocused: привязка к состоянию фокуса (чтение и управление).
    ///   - onCommit: обработчик нажатия Return.
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
        font: UIFont? = nil,
        textColor: UIColor? = nil,
        textAlignment: NSTextAlignment = .natural,
        returnKeyType: UIReturnKeyType = .default,
        clearButtonMode: UITextField.ViewMode = .never,
        isFocused: Binding<Bool>? = nil,
        onCommit: (() -> Void)? = nil,
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
        self.font = font
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.returnKeyType = returnKeyType
        self.clearButtonMode = clearButtonMode
        self.isFocused = isFocused
        self.onCommit = onCommit
        self._textValue = textValue
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MaskTextField {
        let field = MaskTextField()
        apply(to: field)
        field.delegate = context.coordinator
        // `.editingChanged` приходит только от действий пользователя (ввод, вставка,
        // удаление, очистка), а не от программной установки значения из SwiftUI.
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return field
    }

    public func updateUIView(_ field: MaskTextField, context: Context) {
        context.coordinator.parent = self
        apply(to: field)

        // Синхронизируем значение только при расхождении, чтобы не зациклить обновления.
        if field.textValue != textValue {
            field.textValue = textValue
        }

        syncFocus(of: field)
    }

    /// Приводит фокус поля в соответствие с привязкой `isFocused`.
    private func syncFocus(of field: MaskTextField) {
        guard let wantsFocus = isFocused?.wrappedValue else { return }

        // Смена первого ответчика внутри цикла обновления SwiftUI нестабильна.
        DispatchQueue.main.async {
            if wantsFocus, !field.isFirstResponder {
                field.becomeFirstResponder()
            } else if !wantsFocus, field.isFirstResponder {
                field.resignFirstResponder()
            }
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
        if let font, field.font != font { field.font = font }
        if let textColor, field.textColor != textColor { field.textColor = textColor }
        if field.textAlignment != textAlignment { field.textAlignment = textAlignment }
        if field.returnKeyType != returnKeyType { field.returnKeyType = returnKeyType }
        if field.clearButtonMode != clearButtonMode { field.clearButtonMode = clearButtonMode }
    }

    /// Связывает `MaskTextField` со SwiftUI-состоянием и пробрасывает
    /// изменения сырого значения и фокуса обратно в привязки.
    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaskedTextField

        init(_ parent: MaskedTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ sender: MaskTextField) {
            let value = sender.textValue ?? ""
            if parent.textValue != value {
                parent.textValue = value
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
