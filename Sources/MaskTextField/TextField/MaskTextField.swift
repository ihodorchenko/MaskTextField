import Foundation
import UIKit
import Combine

public class MaskTextField: UITextField {

    // MARK: - property

    public var clearButtonColor: UIColor = UIColor.systemGray {
        didSet {
            self.customClearButton.tintColor = self.clearButtonColor
        }
    }

    private var requestedClearButtonMode: UITextField.ViewMode = .never

    /// Переопределяем системную clear-кнопку собственной (через `rightView`),
    /// чтобы не обращаться к приватному `_clearButton` и свободно красить её.
    public override var clearButtonMode: UITextField.ViewMode {
        get { self.requestedClearButtonMode }
        set {
            self.requestedClearButtonMode = newValue
            // Системную кнопку не показываем — используем свою (rightView).
            super.clearButtonMode = .never
            self.updateCustomClearButton()
        }
    }

    private lazy var customClearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = self.clearButtonColor
        button.accessibilityLabel = L10n.string("a11y.clear")
        button.addTarget(self, action: #selector(self.clearButtonHandler), for: .touchUpInside)
        return button
    }()

    /// Кнопка очистки стоит на конце строки: справа в LTR и слева в RTL.
    private func updateCustomClearButton() {
        self.leftView = nil
        self.rightView = nil

        guard self.requestedClearButtonMode != .never else { return }

        if self.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            self.leftView = self.customClearButton
            self.leftViewMode = self.requestedClearButtonMode
        } else {
            self.rightView = self.customClearButton
            self.rightViewMode = self.requestedClearButtonMode
        }
    }

    @objc private func clearButtonHandler() {
        // Даём внешнему делегату возможность отклонить очистку (как `textFieldShouldClear`).
        let shouldClear = self.externalDelegate?.textFieldShouldClear?(self) ?? true
        guard shouldClear else { return }

        self.textValue = ""
        self.clearButtonPublisher = ()
        self.notification()
    }

    @Published
    public internal(set) var deleteBackwardPublisher: Void = ()

    @Published
    public internal(set) var clearButtonPublisher: Void = ()

    /// Локаль для десятичных разделителей по умолчанию (когда `charValidator` не задан).
    /// Сама маска от локали не зависит: она всегда задаёт формат буквально.
    public var locale: Locale = .current {
        didSet {
            self.cachedDefaultCulture = nil
        }
    }

    private var cachedDefaultCulture: NumberFormatter?

    /// `NumberFormatter` по умолчанию (используется, когда `charValidator` не задан).
    var defaultCulture: NumberFormatter {
        if let cached = self.cachedDefaultCulture { return cached }

        let formatter = NumberFormatter() => {
            $0.locale = self.locale
            $0.groupingSeparator = self.locale.groupingSeparator
            $0.decimalSeparator = self.locale.decimalSeparator
            $0.usesGroupingSeparator = true
            $0.formatterBehavior = .behavior10_4
            $0.numberStyle = .decimal
        }
        self.cachedDefaultCulture = formatter
        return formatter
    }

    public private(set) lazy var textPublisher: AnyPublisher<String, Never> = NotificationCenter.default
        .publisher(for: UITextField.textDidChangeNotification, object: self)
        .map {
            ($0.object as? UITextField)?.text ?? ""
        }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()

    /// Пользовательский делегат, задаваемый через `delegate`.
    ///
    /// `MaskTextField` сам является делегатом самого себя (`super.delegate`),
    /// чтобы обрабатывать маску. Внешний делегат хранится отдельно, а вызовы
    /// делегата форвардятся в него из `MaskTextFieldWithDelegate`.
    internal weak var externalDelegate: UITextFieldDelegate?

    public override var delegate: UITextFieldDelegate? {
        get { self.externalDelegate }
        set { self.externalDelegate = newValue }
    }

    // MARK: - init

    public init() {
        super.init(frame: .zero)

        // Внутренний делегат — сам `MaskTextField`; пользовательский делегат
        // задаётся через `delegate` и хранится в `externalDelegate`.
        super.delegate = self
        self.commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // Внутренний делегат — сам `MaskTextField`; пользовательский делегат
        // задаётся через `delegate` и хранится в `externalDelegate`.
        super.delegate = self
        self.commonInit()
    }

    private func commonInit() {
        // Dynamic Type: масштабируется шрифт, заданный через `preferredFont`.
        self.font = UIFont.preferredFont(forTextStyle: .body)
        self.adjustsFontForContentSizeCategory = true

        self.updateLayoutDirection()
    }

    // MARK: - layout direction (RTL)

    /// Принудительно выводить значение слева направо (по умолчанию `true`).
    ///
    /// Маскированные значения (телефон, карта, дата) читаются слева направо и в
    /// RTL-интерфейсах. При `.natural`-выравнивании текст в RTL прижимается к правому краю.
    public var forcesLeftToRight: Bool = true {
        didSet {
            self.updateLayoutDirection()
        }
    }

    private var requestedTextAlignment: NSTextAlignment = .natural

    public override var textAlignment: NSTextAlignment {
        get { self.requestedTextAlignment }
        set {
            self.requestedTextAlignment = newValue
            self.applyTextAlignment()
        }
    }

    public override var semanticContentAttribute: UISemanticContentAttribute {
        didSet {
            self.updateCustomClearButton()
        }
    }

    private func updateLayoutDirection() {
        self.semanticContentAttribute = self.forcesLeftToRight ? .forceLeftToRight : .unspecified
        self.applyTextAlignment()
    }

    private func applyTextAlignment() {
        let isRTLInterface = UIView.userInterfaceLayoutDirection(for: .unspecified) == .rightToLeft

        if self.forcesLeftToRight, self.requestedTextAlignment == .natural, isRTLInterface {
            super.textAlignment = .right
        } else {
            super.textAlignment = self.requestedTextAlignment
        }
    }

    // MARK: - content insert

    public var textContainerInset: UIEdgeInsets = .zero {
        didSet {
            self.layoutIfNeeded()
        }
    }

    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        super.textRect(forBounds: bounds).inset(by: self.textContainerInset)
    }

    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        super.editingRect(forBounds: bounds).inset(by: self.textContainerInset)
    }

    override open func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.rightViewRect(forBounds: bounds)
        return rec.offsetBy(dx: -self.textContainerInset.right, dy: 0)
    }

    override open func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.leftViewRect(forBounds: bounds)
        return rec.offsetBy(dx: self.textContainerInset.left, dy: 0)
    }

    /// Системная clear-кнопка стоит на конце строки: слева в RTL, справа в LTR.
    override open func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.clearButtonRect(forBounds: bounds)
        let isRTL = self.effectiveUserInterfaceLayoutDirection == .rightToLeft
        return rec.offsetBy(dx: isRTL ? self.textContainerInset.left : -self.textContainerInset.right, dy: 0)
    }

    // MARK: - accessibility

    /// Озвучивать VoiceOver отклонённые символы и заполнение маски (по умолчанию выключено).
    public var announcesInputEvents: Bool = false

    private var explicitAccessibilityValue: String?

    /// Значение для VoiceOver: без заглушек маски и без скрытых символов.
    /// Явно заданное значение имеет приоритет.
    public override var accessibilityValue: String? {
        get {
            if let explicit = self.explicitAccessibilityValue { return explicit }
            if let mt = self._transformer as? MaskTransformer, mt.onlyEnteredCount > 0 {
                return mt.accessibilityDescription
            }
            return super.accessibilityValue
        }
        set {
            self.explicitAccessibilityValue = newValue
        }
    }

    func announceInputResult(accepted: Bool) {
        guard self.announcesInputEvents else { return }

        let total = self.onlyEnteredCount
        let isComplete = total > 0 && (self.textValue?.count ?? 0) == total

        if !accepted {
            UIAccessibility.post(notification: .announcement, argument: L10n.string("a11y.char_rejected"))
        } else if isComplete {
            UIAccessibility.post(notification: .announcement, argument: L10n.string("a11y.complete"))
        }
    }

    // MARK: - clear text

    public override func deleteBackward() {
        // Удаление обязано идти через трансформер: `super.deleteBackward()`
        // удаляет символ из отображаемого текста напрямую, разсинхронизируя
        // состояние маски (`_maskInfo`).
        let start = self.selectedTextRange?.start ?? self.endOfDocument
        let utf16Offset = self.offset(from: self.beginningOfDocument, to: start)
        guard utf16Offset > 0 else { return }

        self._transformer.onDeleteBackward(at: (self.text ?? "").characterIndex(utf16Offset: utf16Offset))
        self.deleteBackwardPublisher = ()
        self.notification()
    }

    // MARK: - edit menu

    private var editActions: [ResponderStandardEditActions: Bool]?
    private var filterEditActions: [ResponderStandardEditActions: Bool]?

    public func setEditActions(only actions: [ResponderStandardEditActions]) {
        if self.editActions == nil { self.editActions = [:] }
        self.filterEditActions = nil
        actions.forEach { self.editActions?[$0] = true }
    }

    public func addToCurrentEditActions(actions: [ResponderStandardEditActions]) {
        if self.filterEditActions == nil { self.filterEditActions = [:] }
        self.editActions = nil
        actions.forEach { self.filterEditActions?[$0] = true }
    }

    private func filterEditActions(actions: [ResponderStandardEditActions], allowed: Bool) {
        if self.filterEditActions == nil { self.filterEditActions = [:] }
        editActions = nil
        actions.forEach { self.filterEditActions?[$0] = allowed }
    }

    public func filterEditActions(notAllowed: [ResponderStandardEditActions]) {
        filterEditActions(actions: notAllowed, allowed: false)
    }

    public func resetEditActions() {
        editActions = nil
        filterEditActions = nil
    }

    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if let actions = self.editActions {
            for _action in actions where _action.key.selector == action { return _action.value }
            return false
        }

        if let actions = self.filterEditActions {
            for _action in actions where _action.key.selector == action { return _action.value }
        }

        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: - mask

    /// Дополнительные ограничения на вводимые символы.
    public weak var charValidator: CharValidator?

    /// Система преобразования символов.
    internal lazy var _transformer: BaseTransformer = {
        return BaseTransformer(textField: self)
    }()

    /// Создаёт `MaskTransformer` с полным набором текущих настроек маски.
    ///
    /// Нужен, чтобы повторное включение маски (после `maskText = ""`, которое
    /// сбрасывает трансформер в `BaseTransformer`) не теряло `maskChar`,
    /// `veiledMaskChar`, `hideChars`, `maskMode` и `maskLostFocus`.
    private func makeMaskTransformer() -> MaskTransformer {
        MaskTransformer(textField: self) => {
            $0.mask = self.maskText
            $0.maskLostFocus = self.maskLostFocus
            $0.maskChar = self.maskChar
            $0.veiledMaskChar = self.veiledMaskChar
            $0.hideChars = self.hideChars
            $0.maskMode = self.maskMode
            $0.cursorBehavior = self.cursorBehavior
            $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
        }
    }

    /// Применяет настройку к текущему `MaskTransformer`; если трансформер ещё не
    /// маскирующий (например, `maskText` пуст), создаёт его со всеми настройками.
    private func configureMask(_ configure: (MaskTransformer) -> Void) {
        if let transformer = self._transformer as? MaskTransformer {
            configure(transformer)
        } else {
            self._transformer = self.makeMaskTransformer()
        }
    }

    /// Настраиваемая маска (+375 (dd) ddd-dd-dd).
    /// Маска со скрытыми введёнными символами (+375 (^d^d) ^d^d^d-^d^d-^d^d) — при потере фокуса.
    public var maskText: String = "" {
        didSet {
            if !self.maskText.isEmpty {
                self.configureMask { $0.mask = self.maskText }
            } else {
                self._transformer = BaseTransformer(textField: self)
            }
        }
    }

    /// Маска, отображаемая, если поле не в фокусе.
    public var maskLostFocus: String = "" {
        didSet {
            guard !self.maskLostFocus.isEmpty else { return }

            self.configureMask { $0.maskLostFocus = self.maskLostFocus }
        }
    }

    /// Символ маски, на котором происходит ввод (+375 (__) ___-__-__).
    public var maskChar: Character = "_" {
        didSet {
            self.configureMask { $0.maskChar = self.maskChar }
        }
    }

    /// Символ, который при потере фокуса заменяет отредактированные символы в маске (+375 (XX) XXX-XX-XX).
    public var veiledMaskChar: Character = "•" {
        didSet {
            self.configureMask { $0.veiledMaskChar = self.veiledMaskChar }
        }
    }

    /// Включает режим пароля.
    public var hideChars: Bool = false {
        didSet {
            self.configureMask { $0.hideChars = self.hideChars }
        }
    }

    /// Значение без маски.
    public var textValue: String? {
        get {
            self._transformer.text
        }
        set {
            self._transformer.text = newValue
        }
    }

    /// Режим отображения маски.
    public var maskMode: MaskMode = .fullMask {
        didSet {
            self.configureMask { $0.maskMode = self.maskMode }
        }
    }

    /// Поведение курсора: свободное или строго последовательный ввод.
    public var cursorBehavior: CursorBehavior = .free {
        didSet {
            self.configureMask { $0.cursorBehavior = self.cursorBehavior }
        }
    }

    /// Не отображать маску, если значение пустое, когда поле не в фокусе.
    public var hiddenMaskIfEnteredTextEmpty: Bool = false {
        didSet {
            self.configureMask { $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty }
        }
    }

    /// Количество видимых символов.
    public var onlyEnteredCount: Int {
        return self._transformer.onlyEnteredCount
    }

    /// Отображаемая маска.
    public var visibleTextMask: String {
        return (self._transformer as? MaskTransformer)?.visibleTextMask ?? ""
    }

    /// Отображаемая маска после потери фокуса.
    public var visibleTextMaskLostFocus: String {
        return (self._transformer as? MaskTransformer)?.visibleTextMaskLostFocus ?? ""
    }

    public func redrawMaskText() {
        self._transformer.onSelectionChanged()
    }
}
