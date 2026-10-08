import Foundation

/// Ready-made masks for typical fixed-format cases.
///
/// A mask defines only a format, not whether a value is valid: `dateDMY` accepts `99/99/9999`.
/// Country-dependent formats (phones, IBAN) are deliberately not included.
public enum MaskPreset {
    /// A bank card of 16 digits: `1234 5678 9012 3456`.
    public static let card16 = "dddd dddd dddd dddd"

    /// An American Express card (15 digits): `3412 345678 12345`.
    public static let cardAmex = "dddd dddddd ddddd"

    /// A date `dd/mm/yyyy` (format only, the value is not validated).
    public static let dateDMY = "dd/dd/dddd"

    /// A time `hh:mm` (format only, the value is not validated).
    public static let timeHM = "dd:dd"

    /// A one-time code of `length` digits.
    public static func otp(length: Int) -> String {
        String(repeating: "d", count: max(length, 0))
    }

    /// A provider for cards: American Express (starts with 34 or 37) is 15 digits, all others are 16.
    ///
    /// ```swift
    /// field.maskProvider = MaskPreset.cardProvider
    /// ```
    public static let cardProvider: @Sendable (String) -> MaskVariant = { raw in
        raw.hasPrefix("34") || raw.hasPrefix("37") ? MaskVariant(cardAmex) : MaskVariant(card16)
    }
}
