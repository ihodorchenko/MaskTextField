import Foundation

/// Готовые маски для типовых случаев с фиксированным форматом.
///
/// Маска задаёт только формат, а не допустимость значения: `dateDMY` примет `99/99/9999`.
/// Форматы, зависящие от страны (телефоны, IBAN), намеренно не включены.
public enum MaskPreset {
    /// Банковская карта из 16 цифр: `1234 5678 9012 3456`.
    public static let card16 = "dddd dddd dddd dddd"

    /// Карта American Express (15 цифр): `3412 345678 12345`.
    public static let cardAmex = "dddd dddddd ddddd"

    /// Дата `дд/мм/гггг` (только формат, без проверки значения).
    public static let dateDMY = "dd/dd/dddd"

    /// Время `чч:мм` (только формат, без проверки значения).
    public static let timeHM = "dd:dd"

    /// Одноразовый код из `length` цифр.
    public static func otp(length: Int) -> String {
        String(repeating: "d", count: max(length, 0))
    }

    /// Провайдер для карт: American Express (начинается с 34 или 37) — 15 цифр, остальные — 16.
    ///
    /// ```swift
    /// field.maskProvider = MaskPreset.cardProvider
    /// ```
    public static let cardProvider: (String) -> MaskVariant = { raw in
        raw.hasPrefix("34") || raw.hasPrefix("37") ? MaskVariant(cardAmex) : MaskVariant(card16)
    }
}
