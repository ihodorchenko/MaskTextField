import Foundation

/// Один вариант маски для динамических масок: маска ввода и (необязательно) маска без фокуса.
public struct MaskVariant: Equatable {
    public var mask: String
    public var maskLostFocus: String

    public init(_ mask: String, maskLostFocus: String = "") {
        self.mask = mask
        self.maskLostFocus = maskLostFocus
    }
}

extension MaskVariant {
    /// Строит провайдер масок по ёмкости: выбирается первый вариант, в который помещается
    /// введённое значение; если не помещается ни в один — вариант с наибольшей ёмкостью.
    ///
    /// Варианты стоит перечислять по возрастанию ёмкости, например
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
