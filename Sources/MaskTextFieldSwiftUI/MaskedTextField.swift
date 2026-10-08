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

    /// Поведение курсора: `.free` или `.sequential` (только последовательный ввод).
    public var cursorBehavior: CursorBehavior

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

    /// Принудительно выводить значение слева направо, в том числе в RTL-интерфейсе.
    public var forcesLeftToRight: Bool

    /// Локаль для десятичных разделителей (маска от неё не зависит).
    public var locale: Locale

    /// Озвучивать VoiceOver отклонённые символы и заполнение маски.
    public var announcesInputEvents: Bool

    /// Подпись поля для VoiceOver.
    public var accessibilityLabelText: String?

    /// Подсказка поля для VoiceOver (например, формат ввода).
    public var accessibilityHintText: String?

    /// Сырое значение без маски (двусторонняя привязка к SwiftUI-состоянию).
    @Binding public var textValue: String

    /// Необязательная привязка к состоянию фокуса (`true` — поле в фокусе).
    private var isFocused: Binding<Bool>?

    /// Вызывается по нажатию Return.
    private var onCommit: (() -> Void)?

    /// Необязательная привязка к состоянию «маска заполнена».
    private var isComplete: Binding<Bool>?

    /// Вызывается, когда пользователь своим вводом заполнил маску.
    private var onComplete: (() -> Void)?

    /// Создаёт маскированное поле.
    ///
    /// - Parameters:
    ///   - mask: маска во время редактирования.
    ///   - maskLostFocus: маска при потере фокуса (по умолчанию пустая).
    ///   - maskMode: режим отображения маски.
    ///   - cursorBehavior: поведение курсора.
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
    ///   - forcesLeftToRight: выводить значение слева направо и в RTL.
    ///   - locale: локаль для десятичных разделителей.
    ///   - announcesInputEvents: озвучивать отклонённые символы и заполнение.
    ///   - accessibilityLabelText: подпись для VoiceOver.
    ///   - accessibilityHintText: подсказка для VoiceOver.
    ///   - isFocused: привязка к состоянию фокуса (чтение и управление).
    ///   - onCommit: обработчик нажатия Return.
    ///   - isComplete: привязка к состоянию «маска заполнена».
    ///   - onComplete: обработчик заполнения маски пользователем.
    ///   - textValue: привязка к сырому значению.
    public init(
        mask: String,
        maskLostFocus: String = "",
        maskMode: MaskMode = .fullMask,
        cursorBehavior: CursorBehavior = .free,
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
        forcesLeftToRight: Bool = true,
        locale: Locale = .current,
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
        self.locale = locale
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
        field.delegate = context.coordinator
        field.onComplete = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onComplete?()
        }
        // Уведомление приходит только от действий пользователя (ввод, вставка, удаление,
        // очистка), а не от программной установки значения из SwiftUI, и не зависит от
        // доставки target-action.
        context.coordinator.observeEdits(of: field)
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
        syncCompletion(of: field)
    }

    /// Обновляет привязку `isComplete` после программных изменений значения.
    private func syncCompletion(of field: MaskTextField) {
        guard let binding = isComplete, binding.wrappedValue != field.isComplete else { return }

        // Запись состояния внутри цикла обновления SwiftUI недопустима.
        DispatchQueue.main.async {
            binding.wrappedValue = field.isComplete
        }
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
        if field.locale != locale { field.locale = locale }
        if field.announcesInputEvents != announcesInputEvents { field.announcesInputEvents = announcesInputEvents }
        if field.accessibilityLabel != accessibilityLabelText { field.accessibilityLabel = accessibilityLabelText }
        if field.accessibilityHint != accessibilityHintText { field.accessibilityHint = accessibilityHintText }
    }

    /// Связывает `MaskTextField` со SwiftUI-состоянием и пробрасывает
    /// изменения сырого значения и фокуса обратно в привязки.
    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaskedTextField

        init(_ parent: MaskedTextField) {
            self.parent = parent
        }

        private var observer: NSObjectProtocol?

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        func observeEdits(of field: MaskTextField) {
            // `queue: nil` — обработчик выполняется синхронно в потоке публикации (главном).
            observer = NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: field,
                queue: nil
            ) { [weak self, weak field] _ in
                guard let self, let field else { return }
                self.fieldDidChange(field)
            }
        }

        private func fieldDidChange(_ field: MaskTextField) {
            let value = field.textValue ?? ""
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
