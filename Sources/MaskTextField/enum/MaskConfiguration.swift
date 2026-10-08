import Foundation

/// The full set of mask settings. Applied to a field at once (`MaskTextField.apply(_:)`,
/// `MaskTextField.configure(_:)`): the order of assignment does not matter and the mask is rebuilt once.
public struct MaskConfiguration {
    /// The default placeholder for editable positions; the single source of the default.
    public static let defaultMaskChar: Character = "_"
    /// The default character that veils entered characters; the single source of the default.
    public static let defaultVeiledMaskChar: Character = "•"

    public var mask: String = ""
    public var maskLostFocus: String = ""
    public var maskVariants: [MaskVariant] = []

    /// A custom mask provider; if set, it takes precedence over `maskVariants`.
    public var maskProvider: ((String) -> MaskVariant)?
    public var maskChar: Character = MaskConfiguration.defaultMaskChar
    public var veiledMaskChar: Character = MaskConfiguration.defaultVeiledMaskChar
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
