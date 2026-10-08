import Foundation

/// Mask display modes.
public enum MaskMode: Equatable {
    /// The mask is displayed in full.
    case fullMask
    /// The mask is displayed gradually, as you type, starting from the first characters.
    case gradualMask
}
