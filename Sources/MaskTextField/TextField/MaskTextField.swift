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

    /// Replaces the system clear button with our own (via `rightView`),
    /// so that the private `_clearButton` is not touched and the button can be tinted freely.
    public override var clearButtonMode: UITextField.ViewMode {
        get { self.requestedClearButtonMode }
        set {
            self.requestedClearButtonMode = newValue
            // The system clear button is not shown; our own one (rightView) is used.
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

    /// The clear button sits at the end of the line: on the right in LTR and on the left in RTL.
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
        // Let the external delegate reject clearing (like `textFieldShouldClear`).
        let shouldClear = self.externalDelegate?.textFieldShouldClear?(self) ?? true
        guard shouldClear else { return }

        self.textValue = ""
        self.clearButtonSubject.send()
        self.notification()
    }

    private let deleteBackwardSubject = PassthroughSubject<Void, Never>()
    private let clearButtonSubject = PassthroughSubject<Void, Never>()

    /// Fires on every backward delete; does not fire on subscription.
    public var deleteBackwardEvents: AnyPublisher<Void, Never> {
        self.deleteBackwardSubject.eraseToAnyPublisher()
    }

    /// Fires when the clear button is tapped; does not fire on subscription.
    public var clearButtonEvents: AnyPublisher<Void, Never> {
        self.clearButtonSubject.eraseToAnyPublisher()
    }

    public private(set) lazy var textPublisher: AnyPublisher<String, Never> = NotificationCenter.default
        .publisher(for: UITextField.textDidChangeNotification, object: self)
        .map {
            ($0.object as? UITextField)?.text ?? ""
        }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()

    /// The user's delegate, assigned through `delegate`.
    ///
    /// `MaskTextField` is its own delegate (`super.delegate`) in order to handle the mask.
    /// The external delegate is stored separately, and delegate calls are forwarded to it
    /// from `MaskTextFieldWithDelegate`.
    internal weak var externalDelegate: UITextFieldDelegate?

    public override var delegate: UITextFieldDelegate? {
        get { self.externalDelegate }
        set { self.externalDelegate = newValue }
    }

    // MARK: - init

    public init() {
        super.init(frame: .zero)

        // The internal delegate is the `MaskTextField` itself; a custom delegate
        // is set through `delegate` and stored in `externalDelegate`.
        super.delegate = self
        self.commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // The internal delegate is the `MaskTextField` itself; a custom delegate
        // is set through `delegate` and stored in `externalDelegate`.
        super.delegate = self
        self.commonInit()
    }

    private func commonInit() {
        // Dynamic Type: scales the font set through `preferredFont`.
        self.font = UIFont.preferredFont(forTextStyle: .body)
        self.adjustsFontForContentSizeCategory = true

        self.updateLayoutDirection()
    }

    // MARK: - keyboard suggestions

    /// Disables autocorrection, spell checking and smart substitutions (`true` by default)
    /// for masked fields: card numbers, PINs and codes must not end up in keyboard suggestions.
    /// Explicitly set `autocorrectionType`, `spellCheckingType`, etc. take precedence.
    ///
    /// - Important: this is not `isSecureTextEntry`: `hideChars` only hides characters on screen
    ///   and does not protect against screenshots or screen recording.
    public var disablesAutocorrection: Bool = true {
        didSet {
            if self.isFirstResponder { self.reloadInputViews() }
        }
    }

    private var suppressesSuggestions: Bool {
        self.disablesAutocorrection && !self.maskText.isEmpty
    }

    private var explicitAutocorrectionType: UITextAutocorrectionType?
    private var explicitSpellCheckingType: UITextSpellCheckingType?
    private var explicitSmartQuotesType: UITextSmartQuotesType?
    private var explicitSmartDashesType: UITextSmartDashesType?
    private var explicitSmartInsertDeleteType: UITextSmartInsertDeleteType?

    public override var autocorrectionType: UITextAutocorrectionType {
        get { self.explicitAutocorrectionType ?? (self.suppressesSuggestions ? .no : super.autocorrectionType) }
        set { self.explicitAutocorrectionType = newValue; super.autocorrectionType = newValue }
    }

    public override var spellCheckingType: UITextSpellCheckingType {
        get { self.explicitSpellCheckingType ?? (self.suppressesSuggestions ? .no : super.spellCheckingType) }
        set { self.explicitSpellCheckingType = newValue; super.spellCheckingType = newValue }
    }

    public override var smartQuotesType: UITextSmartQuotesType {
        get { self.explicitSmartQuotesType ?? (self.suppressesSuggestions ? .no : super.smartQuotesType) }
        set { self.explicitSmartQuotesType = newValue; super.smartQuotesType = newValue }
    }

    public override var smartDashesType: UITextSmartDashesType {
        get { self.explicitSmartDashesType ?? (self.suppressesSuggestions ? .no : super.smartDashesType) }
        set { self.explicitSmartDashesType = newValue; super.smartDashesType = newValue }
    }

    public override var smartInsertDeleteType: UITextSmartInsertDeleteType {
        get { self.explicitSmartInsertDeleteType ?? (self.suppressesSuggestions ? .no : super.smartInsertDeleteType) }
        set { self.explicitSmartInsertDeleteType = newValue; super.smartInsertDeleteType = newValue }
    }

    // MARK: - layout direction (RTL)

    /// Forces the value to be laid out left to right (`true` by default).
    ///
    /// Masked values (phone, card, date) read left to right in RTL interfaces too.
    /// With `.natural` alignment the text is pinned to the right edge in RTL.
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

    /// The system clear button sits at the end of the line: left in RTL, right in LTR.
    override open func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rec = super.clearButtonRect(forBounds: bounds)
        let isRTL = self.effectiveUserInterfaceLayoutDirection == .rightToLeft
        return rec.offsetBy(dx: isRTL ? self.textContainerInset.left : -self.textContainerInset.right, dy: 0)
    }

    // MARK: - accessibility

    /// Makes VoiceOver announce rejected characters and a filled mask (off by default).
    public var announcesInputEvents: Bool = false

    private var explicitAccessibilityValue: String?

    /// The VoiceOver value: without mask placeholders and without hidden characters.
    /// An explicitly set value takes precedence.
    public override var accessibilityValue: String? {
        get {
            if let explicit = self.explicitAccessibilityValue { return explicit }
            if let mt = self._transformer as? MaskTransformer, mt.capacity > 0 {
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

        let total = self.capacity
        let isComplete = total > 0 && self.textValue.count == total

        if !accepted {
            UIAccessibility.post(notification: .announcement, argument: L10n.string("a11y.char_rejected"))
        } else if isComplete {
            UIAccessibility.post(notification: .announcement, argument: L10n.string("a11y.complete"))
        }
    }

    // MARK: - clear text

    public override func deleteBackward() {
        // Deletion must go through the transformer: `super.deleteBackward()` removes a
        // character from the displayed text directly and desyncs the mask state.
        let current = self.text ?? ""
        let selection = self.selectedTextRange ?? self.textRange(from: self.endOfDocument, to: self.endOfDocument)
        let start = selection?.start ?? self.endOfDocument
        let end = selection?.end ?? start
        let utf16Offset = self.offset(from: self.beginningOfDocument, to: start)

        if start != end {
            // A selected fragment is deleted as a whole, like in `shouldChangeCharactersIn`.
            let utf16End = self.offset(from: self.beginningOfDocument, to: end)
            let lower = current.characterIndex(utf16Offset: utf16Offset)
            let upper = current.characterIndex(utf16Offset: utf16End)
            self._transformer.onPaste("", in: lower..<max(lower, upper))
        } else {
            guard utf16Offset > 0 else { return }

            self._transformer.onDeleteBackward(at: current.characterIndex(utf16Offset: utf16Offset))
        }
        self.deleteBackwardSubject.send()
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

    /// Additional restrictions on the characters that can be entered.
    ///
    /// Held by a strong reference, so a validator can be created right in the assignment:
    /// `field.charValidator = EmojiFreeValidator()`. A validator must not hold the field strongly.
    public var charValidator: CharValidator?

    /// The character transformation engine.
    internal lazy var _transformer: BaseTransformer = {
        return BaseTransformer(textField: self)
    }()

    /// Creates a `MaskTransformer` with the full set of current mask settings.
    ///
    /// Needed so that re-enabling the mask (after `maskText = ""`, which resets the
    /// transformer to `BaseTransformer`) does not lose `maskChar`, `veiledMaskChar`,
    /// `hideChars`, `maskMode` or `maskLostFocus`.
    private func makeMaskTransformer() -> MaskTransformer {
        MaskTransformer(textField: self) => {
            $0.mask = self.maskText
            $0.maskLostFocus = self.maskLostFocus
            $0.maskChar = self.maskChar
            $0.veiledMaskChar = self.veiledMaskChar
            $0.hideChars = self.hideChars
            $0.maskMode = self.maskMode
            $0.cursorBehavior = self.cursorBehavior
            $0.maskProvider = self.maskProvider
            $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
        }
    }

    /// Applies a setting to the current `MaskTransformer`; if the transformer is not yet
    /// a masking one (for example `maskText` is empty), creates it with all the settings.
    private func configureMask(_ configure: (MaskTransformer) -> Void) {
        guard !self.isApplyingConfiguration else { return }

        if let transformer = self._transformer as? MaskTransformer {
            configure(transformer)
        } else if !self.maskText.isEmpty || self.maskProvider != nil {
            self._transformer = self.makeMaskTransformer()
        }
        // Otherwise there is no mask: the value stays in the field's property and reaches
        // the transformer when the mask is enabled (`makeMaskTransformer`).
    }

    /// The editing mask, e.g. `+375 (dd) ddd-dd-dd`; see <doc:MaskSyntax> for the syntax.
    /// Use `maskLostFocus` for a mask with veiled characters shown when the field loses focus.
    public var maskText: String = "" {
        didSet {
            guard !self.isApplyingConfiguration else { return }

            if !self.maskText.isEmpty {
                self.configureMask { $0.mask = self.maskText }
            } else if self.maskProvider == nil {
                self._transformer = BaseTransformer(textField: self)
            }

            self.refreshCompletion(userInitiated: false)
        }
    }

    /// Dynamic masks: returns a mask variant for the current raw value
    /// (for example a card: 15 or 16 digits). While set, `maskText` and `maskLostFocus` are
    /// ignored. Called on every change, so it must be a pure function.
    public var maskProvider: ((String) -> MaskVariant)? {
        didSet {
            guard !self.isApplyingConfiguration else { return }

            if self.maskProvider != nil {
                self.configureMask { $0.maskProvider = self.maskProvider }
            } else if self.maskText.isEmpty {
                self._transformer = BaseTransformer(textField: self)
            } else {
                self.configureMask { $0.maskProvider = nil }
            }

            self.refreshCompletion(userInitiated: false)
        }
    }

    /// Mask variants by capacity: the first one the value fits into is chosen
    /// (list them in ascending capacity order). A convenience on top of `maskProvider`.
    public var maskVariants: [MaskVariant] = [] {
        didSet {
            self.maskProvider = self.maskVariants.isEmpty
                ? nil
                : MaskVariant.provider(byCapacity: self.maskVariants)
        }
    }

    /// The mask shown while the field is not focused, e.g. `+375 (^d^d) ^d^d^d-^d^d-^d^d`.
    public var maskLostFocus: String = "" {
        didSet {
            self.configureMask { $0.maskLostFocus = self.maskLostFocus }
        }
    }

    /// The placeholder character for editable positions (`+375 (__) ___-__-__`).
    public var maskChar: Character = MaskConfiguration.defaultMaskChar {
        didSet {
            self.configureMask { $0.maskChar = self.maskChar }
        }
    }

    /// The character that replaces entered characters when the field loses focus (`+375 (XX) XXX-XX-XX`).
    public var veiledMaskChar: Character = MaskConfiguration.defaultVeiledMaskChar {
        didSet {
            self.configureMask { $0.veiledMaskChar = self.veiledMaskChar }
        }
    }

    /// Enables password mode: an entered character is veiled after a short delay.
    public var hideChars: Bool = false {
        didSet {
            self.configureMask { $0.hideChars = self.hideChars }
        }
    }

    /// The value without the mask.
    public var textValue: String {
        get {
            self._transformer.text ?? ""
        }
        set {
            self._transformer.text = newValue
            self.refreshCompletion(userInitiated: false)
        }
    }

    // MARK: - configuration

    private var isApplyingConfiguration = false

    /// The current mask settings as a single value.
    public var configuration: MaskConfiguration {
        MaskConfiguration() => {
            $0.mask = self.maskText
            $0.maskLostFocus = self.maskLostFocus
            $0.maskVariants = self.maskVariants
            // A provider built from `maskVariants` is restored from the variants themselves.
            $0.maskProvider = self.maskVariants.isEmpty ? self.maskProvider : nil
            $0.maskChar = self.maskChar
            $0.veiledMaskChar = self.veiledMaskChar
            $0.hideChars = self.hideChars
            $0.maskMode = self.maskMode
            $0.cursorBehavior = self.cursorBehavior
            $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty
        }
    }

    /// Applies all mask settings at once: the order of assignment does not matter and the
    /// transformer is rebuilt once. The entered value is reset (as on any mask change).
    public func apply(_ configuration: MaskConfiguration) {
        self.isApplyingConfiguration = true
        self.maskText = configuration.mask
        self.maskLostFocus = configuration.maskLostFocus
        self.maskChar = configuration.maskChar
        self.veiledMaskChar = configuration.veiledMaskChar
        self.hideChars = configuration.hideChars
        self.maskMode = configuration.maskMode
        self.cursorBehavior = configuration.cursorBehavior
        self.hiddenMaskIfEnteredTextEmpty = configuration.hiddenMaskIfEnteredTextEmpty
        self.maskVariants = configuration.maskVariants
        if let provider = configuration.maskProvider {
            self.maskProvider = provider
        }
        self.isApplyingConfiguration = false

        let isMasked = !configuration.mask.isEmpty || self.maskProvider != nil
        self._transformer = isMasked ? self.makeMaskTransformer() : BaseTransformer(textField: self)
        self.refreshCompletion(userInitiated: false)
    }

    /// Changes the mask settings atomically:
    /// `field.configure { $0.mask = "dd/dd"; $0.maskChar = "#" }`.
    public func configure(_ update: (inout MaskConfiguration) -> Void) {
        var configuration = self.configuration
        update(&configuration)
        self.apply(configuration)
    }

    // MARK: - completion

    /// Whether all editable positions of the mask are filled. Always `false` for a field without a mask.
    public var isComplete: Bool {
        self._transformer.isComplete
    }

    private let isCompleteSubject = CurrentValueSubject<Bool, Never>(false)

    /// The completion state: delivers the current value on subscription, then only changes
    /// (both from user actions and from programmatic changes of the value or the mask).
    public var isCompletePublisher: AnyPublisher<Bool, Never> {
        self.isCompleteSubject.removeDuplicates().eraseToAnyPublisher()
    }

    /// Called when the **user** fills the mask with their input (a "not filled" → "filled"
    /// transition). Not called for programmatic values and not repeated
    /// while the mask stays filled.
    public var onComplete: (() -> Void)?

    func refreshCompletion(userInitiated: Bool) {
        let complete = self.isComplete
        guard complete != self.isCompleteSubject.value else { return }

        self.isCompleteSubject.send(complete)
        if complete && userInitiated {
            self.onComplete?()
        }
    }

    /// The mask display mode.
    public var maskMode: MaskMode = .fullMask {
        didSet {
            self.configureMask { $0.maskMode = self.maskMode }
        }
    }

    /// The cursor behavior: free, snap on focus, or strictly sequential input.
    public var cursorBehavior: CursorBehavior = .free {
        didSet {
            self.configureMask { $0.cursorBehavior = self.cursorBehavior }
        }
    }

    /// Hides the mask when the value is empty and the field is not focused.
    public var hiddenMaskIfEnteredTextEmpty: Bool = false {
        didSet {
            self.configureMask { $0.hiddenMaskIfEnteredTextEmpty = self.hiddenMaskIfEnteredTextEmpty }
        }
    }

    /// The number of editable positions.
    public var capacity: Int {
        return self._transformer.capacity
    }

    /// The displayed mask.
    public var visibleTextMask: String {
        return (self._transformer as? MaskTransformer)?.visibleTextMask ?? ""
    }

    /// The displayed mask while the field is not focused.
    public var visibleTextMaskLostFocus: String {
        return (self._transformer as? MaskTransformer)?.visibleTextMaskLostFocus ?? ""
    }

    public func redrawMaskText() {
        self._transformer.onSelectionChanged()
    }
}
