import Foundation

/// Полный набор настроек маски. Применяется к полю разом (`MaskTextField.apply(_:)`,
/// `MaskTextField.configure(_:)`): порядок присваивания не важен, а маска пересоздаётся один раз.
public struct MaskConfiguration {
    public var mask: String = ""
    public var maskLostFocus: String = ""
    public var maskVariants: [MaskVariant] = []

    /// Пользовательский провайдер масок; если задан, имеет приоритет над `maskVariants`.
    public var maskProvider: ((String) -> MaskVariant)?
    public var maskChar: Character = MaskTransformer.defaultMaskChar
    public var veiledMaskChar: Character = MaskTransformer.hideChar
    public var hideChars: Bool = false
    public var maskMode: MaskMode = .fullMask
    public var cursorBehavior: CursorBehavior = .free
    public var hiddenMaskIfEnteredTextEmpty: Bool = false

    public init() {}

    public init(mask: String, maskLostFocus: String = "") {
        self.mask = mask
        self.maskLostFocus = maskLostFocus
    }
}
