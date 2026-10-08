import Foundation

/// One mask variant for dynamic masks: the input mask and (optionally) the unfocused mask.
public struct MaskVariant: Equatable, Sendable {
    public var mask: String
    public var maskLostFocus: String

    public init(_ mask: String, maskLostFocus: String = "") {
        self.mask = mask
        self.maskLostFocus = maskLostFocus
    }
}

extension MaskVariant {
    /// Builds a mask provider by capacity: the first variant the entered value fits into is
    /// chosen; if it fits none, the variant with the largest capacity is used.
    ///
    /// List the variants in ascending capacity order, for example
    /// `["(dd) ddd-dd", "(dd) ddd-dd-dd"]`.
    public static func provider(byCapacity variants: [MaskVariant]) -> (String) -> MaskVariant {
        let sized = variants.map { variant in
            (variant: variant, capacity: MaskSlot.parse(variant.mask).filter { $0.canEntered }.count)
        }

        return { raw in
            guard !sized.isEmpty else { return MaskVariant("") }

            let count = raw.count
            if let fit = sized.first(where: { $0.capacity >= count }) {
                return fit.variant
            }
            return sized.max { $0.capacity < $1.capacity }!.variant
        }
    }
}
