import Foundation

/// Режимы отображения маски.
public enum MaskMode: Equatable {
    /// Маска отображается полностью.
    case fullMask
    /// Маска отображается постепенно, по мере ввода, начиная с первых символов.
    case gradualMask
}
