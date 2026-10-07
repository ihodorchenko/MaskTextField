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
        button.addTarget(self, action: #selector(self.clearButtonHandler), for: .touchUpInside)
        return button
    }()

    private func updateCustomClearButton() {
        if self.requestedClearButtonMode == .never {
            self.rightView = nil
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
    }

    @Published
    public internal(set) var deleteBackwardPublisher: Void = ()

    @Published
    public internal(set) var clearButtonPublisher: Void = ()

    /// Кэш `NumberFormatter` по умолчанию (используется, когда `charValidator` не задан).
    lazy var defaultCulture: NumberFormatter = NumberFormatter() => {
        $0.groupingSeparator = Locale.current.groupingSeparator
        $0.decimalSeparator = Locale.current.decimalSeparator
        $0.usesGroupingSeparator = true
        $0.formatterBehavior = .behavior10_4
        $0.numberStyle = .decimal
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
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // Внутренний делегат — сам `MaskTextField`; пользовательский делегат
        // задаётся через `delegate` и хранится в `externalDelegate`.
        super.delegate = self
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
        return CGRect(
            x: rec.minX - self.textContainerInset.right,
            y: rec.minY,
            width: rec.width,
            height: rec.height
        )
    }

    override open func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.clearButtonRect(forBounds: bounds)
        return CGRect(
            x: rec.minX - self.textContainerInset.right,
            y: rec.minY,
            width: rec.width,
            height: rec.height
        )
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
            $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
        }
    }

    /// Настраиваемая маска (+375 (dd) ddd-dd-dd).
    /// Маска со скрытыми введёнными символами (+375 (^d^d) ^d^d^d-^d^d-^d^d) — при потере фокуса.
    public var maskText: String = "" {
        didSet {
            if !self.maskText.isEmpty {
                if let mt = self._transformer as? MaskTransformer {
                    mt.mask = self.maskText
                } else {
                    self._transformer = self.makeMaskTransformer()
                }
            } else {
                self._transformer = BaseTransformer(textField: self)
            }
        }
    }

    /// Маска, отображаемая, если поле не в фокусе.
    public var maskLostFocus: String = "" {
        didSet {
            guard !self.maskLostFocus.isEmpty else { return }

            if let mt = self._transformer as? MaskTransformer {
                mt.maskLostFocus = self.maskLostFocus
            } else {
                self._transformer = self.makeMaskTransformer()
            }
        }
    }

    /// Символ маски, на котором происходит ввод (+375 (__) ___-__-__).
    public var maskChar: Character = "_" {
        didSet {
            if let mt = self._transformer as? MaskTransformer {
                mt.maskChar = self.maskChar
            } else {
                self._transformer = self.makeMaskTransformer()
            }
        }
    }

    /// Символ, который при потере фокуса заменяет отредактированные символы в маске (+375 (XX) XXX-XX-XX).
    public var veiledMaskChar: Character = "•" {
        didSet {
            if let mt = self._transformer as? MaskTransformer {
                mt.veiledMaskChar = self.veiledMaskChar
            } else {
                self._transformer = self.makeMaskTransformer()
            }
        }
    }

    /// Включает режим пароля.
    public var hideChars: Bool = false {
        didSet {
            if let mt = self._transformer as? MaskTransformer {
                mt.hideChars = self.hideChars
            } else {
                self._transformer = self.makeMaskTransformer()
            }
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
            if let mt = self._transformer as? MaskTransformer {
                mt.maskMode = self.maskMode
            } else {
                self._transformer = self.makeMaskTransformer()
            }
        }
    }

    /// Не отображать маску, если значение пустое, когда поле не в фокусе.
    public var hiddenMaskIfEnteredTextEmpty: Bool = false {
        didSet {
            if let mt = self._transformer as? MaskTransformer {
                mt.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
            } else {
                self._transformer = self.makeMaskTransformer()
            }
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
