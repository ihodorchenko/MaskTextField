import Foundation

/// Режимы отображения маски.
public enum MaskMode {
    /// Маска отображается полностью.
    case fullMask
    /// Маска отображается постепенно, по мере ввода, начиная с первых символов.
    case gradualMask
}
