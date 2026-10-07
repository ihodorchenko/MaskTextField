import Foundation
import UIKit
import Combine

public class ICMaskTextField: UITextField {

    private var didSetupWhiteTintColorForClearTextFieldButton = false

    // MARK: - property

    public var clearButtonColor: UIColor = UIColor.systemGray {
        didSet {
            self.didSetupWhiteTintColorForClearTextFieldButton = false
            self.setupTintColorForTextFieldClearButtonIfNeeded()
        }
    }

    @Published
    public private(set) var deleteBackwardPublisher: Void = ()

    @Published
    public private(set) var clearButtonPublisher: Void = ()

    public private(set) lazy var textPublisher: AnyPublisher<String, Never> = NotificationCenter.default
        .publisher(for: UITextField.textDidChangeNotification, object: self)
        .map {
            ($0.object as? UITextField)?.text ?? ""
        }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()

    /// Пользовательский делегат, задаваемый через `delegate`.
    ///
    /// `ICMaskTextField` сам является делегатом самого себя (`super.delegate`),
    /// чтобы обрабатывать маску. Внешний делегат хранится отдельно, а вызовы
    /// делегата форвардятся в него из `ICMaskTextFieldWithDelegate`.
    internal weak var externalDelegate: UITextFieldDelegate?

    public override var delegate: UITextFieldDelegate? {
        get { self.externalDelegate }
        set { self.externalDelegate = newValue }
    }

    // MARK: - init

    public init() {
        super.init(frame: .zero)

        // Внутренний делегат — сам `ICMaskTextField`; пользовательский делегат
        // задаётся через `delegate` и хранится в `externalDelegate`.
        super.delegate = self

        self._initView()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // Внутренний делегат — сам `ICMaskTextField`; пользовательский делегат
        // задаётся через `delegate` и хранится в `externalDelegate`.
        super.delegate = self

        self._initView()
    }

    // MARK: - initialisation

    private func _initView() {
        self.addTarget(self, action: #selector(self.begin), for: .allEditingEvents)

        self.setupTintColorForTextFieldClearButtonIfNeeded()
    }

    // MARK: - content insert

    public var textContainerInset: UIEdgeInsets = .zero {
        didSet {
            self.layoutIfNeeded()
        }
    }

    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.textRect(forBounds: bounds).inset(by: self.textContainerInset)

        var width: CGFloat = rec.width
        if self.clearButtonMode == .always || self.clearButtonMode == .unlessEditing {
            width -= self.textContainerInset.right
        }
        if self.rightViewMode == .always || self.rightViewMode == .unlessEditing {
            width -= self.textContainerInset.right
        }
        if self.leftViewMode == .always || self.leftViewMode == .unlessEditing {
            width -= self.textContainerInset.left
        }

        return CGRect(
            x: rec.minX,
            y: rec.minY,
            width: width,
            height: rec.height
        )
    }

    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.editingRect(forBounds: bounds).inset(by: self.textContainerInset)

        var width: CGFloat = rec.width
        if self.clearButtonMode == .always || self.clearButtonMode == .whileEditing {
            width -= self.textContainerInset.right
        }
        if self.rightViewMode == .always || self.rightViewMode == .whileEditing {
            width -= self.textContainerInset.right
        }
        if self.leftViewMode == .always || self.leftViewMode == .whileEditing {
            width -= self.textContainerInset.left
        }

        return CGRect(
            x: rec.minX,
            y: rec.minY,
            width: width,
            height: rec.height
        )
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

    // MARK: - func for change color in clear button

    @objc private func begin() {
        self.setupTintColorForTextFieldClearButtonIfNeeded()
    }

    private func setupTintColorForTextFieldClearButtonIfNeeded() {
        if self.didSetupWhiteTintColorForClearTextFieldButton { return }

        guard let button = self.value(forKey: "_clearButton") as? UIButton else { return }
        guard let icon = button.image(for: .normal)?.withRenderingMode(.alwaysTemplate) else { return }

        button.setImage(icon, for: .normal)
        button.tintColor = self.clearButtonColor

        button.addTarget(self, action: #selector(self.clearButtonHandler), for: .touchUpInside)

        self.didSetupWhiteTintColorForClearTextFieldButton = true
    }

    @objc private func clearButtonHandler() {
        self.textValue = ""

        self.clearButtonPublisher = ()
    }

    // MARK: - clear text

    public override func deleteBackward() {
        super.deleteBackward()

        self.deleteBackwardPublisher = ()
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

    public func resetEditActions() { editActions = nil }

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
    public weak var charValidator: ICCharValidator?

    /// Система преобразования символов.
    internal lazy var _transformer: ICBaseTransformer = {
        return ICBaseTransformer(textField: self)
    }()

    /// Настраиваемая маска (+375 (dd) ddd-dd-dd).
    /// Маска со скрытыми введёнными символами (+375 (^d^d) ^d^d^d-^d^d-^d^d) — при потере фокуса.
    public var maskText: String = "" {
        didSet {
            if !self.maskText.isEmpty {
                if let mt = self._transformer as? ICMaskTransformer {
                    mt.mask = self.maskText
                } else {
                    self._transformer = ICMaskTransformer(textField: self) => {
                        $0.mask = self.maskText
                    }
                }
            } else {
                self._transformer = ICBaseTransformer(textField: self)
            }
        }
    }

    /// Маска, отображаемая, если поле не в фокусе.
    public var maskLostFocus: String = "" {
        didSet {
            guard !self.maskLostFocus.isEmpty else { return }

            if let mt = self._transformer as? ICMaskTransformer {
                mt.maskLostFocus = self.maskLostFocus
            } else {
                self._transformer = ICMaskTransformer(textField: self) => {
                    $0.maskLostFocus = self.maskLostFocus
                }
            }
        }
    }

    /// Символ маски, на котором происходит ввод (+375 (__) ___-__-__).
    public var maskChar: Character = "_" {
        didSet {
            if let mt = self._transformer as? ICMaskTransformer {
                mt.maskChar = self.maskChar
            } else {
                self._transformer = ICMaskTransformer(textField: self) => {
                    $0.maskChar = self.maskChar
                }
            }
        }
    }

    /// Символ, который при потере фокуса заменяет отредактированные символы в маске (+375 (XX) XXX-XX-XX).
    public var veiledMaskChar: Character = "•" {
        didSet {
            if let mt = self._transformer as? ICMaskTransformer {
                mt.veiledMaskChar = self.veiledMaskChar
            } else {
                self._transformer = ICMaskTransformer(textField: self) => {
                    $0.veiledMaskChar = self.veiledMaskChar
                }
            }
        }
    }

    /// Включает режим пароля.
    public var hideChars: Bool = false {
        didSet {
            if let mt = self._transformer as? ICMaskTransformer {
                mt.hideChars = self.hideChars
            } else {
                self._transformer = ICMaskTransformer(textField: self) => {
                    $0.hideChars = self.hideChars
                }
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
    public var maskMode: ICMaskMode = .fullMask {
        didSet {
            if let mt = self._transformer as? ICMaskTransformer {
                mt.maskMode = self.maskMode
            } else {
                self._transformer = ICMaskTransformer(textField: self) => {
                    $0.maskMode = self.maskMode
                }
            }
        }
    }

    /// Не отображать маску, если значение пустое, когда поле не в фокусе.
    public var hiddenMaskIfEnteredTextEmpty: Bool = false {
        didSet {
            if let mt = self._transformer as? ICMaskTransformer {
                mt.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
            } else {
                self._transformer = ICMaskTransformer(textField: self) => {
                    $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
                }
            }
        }
    }

    /// Количество видимых символов.
    public var onlyEnteredCount: Int {
        return self._transformer.onlyEnteredCount
    }

    /// Отображаемая маска.
    public var visibleTextMask: String {
        return (self._transformer as? ICMaskTransformer)?.visibleTextMask ?? ""
    }

    /// Отображаемая маска после потери фокуса.
    public var visibleTextMaskLostFocus: String {
        return (self._transformer as? ICMaskTransformer)?.visibleTextMaskLostFocus ?? ""
    }

    public func redrawMaskText() {
        self._transformer.onSelectionChanged()
    }
}
