import Foundation

/// Тип вводимой позиции маски.
///
/// - `d` — цифра `0-9`
/// - `a` — латинская буква `a-zA-Z`
/// - `A` — латинская буква или цифра
/// - `x` — любой видимый ASCII-символ, кроме цифр: буква или знак препинания/символ
/// - `X` — любой видимый ASCII-символ, включая цифры (пробел не входит)
/// - `z` — любой символ без проверки
enum MaskCharType {
    case digit
    case letter
    case letterOrDigit
    case anySymbol
    case anySymbolOrDigit
    case any

    /// Возвращает тип по символу маски, либо `nil` для литерала.
    static func type(for char: Character) -> MaskCharType? {
        switch char {
        case "d": return .digit
        case "a": return .letter
        case "A": return .letterOrDigit
        case "x": return .anySymbol
        case "X": return .anySymbolOrDigit
        case "z": return .any
        default: return nil
        }
    }

    /// Проверяет, допустим ли символ на позиции этого типа.
    func accepts(_ char: Character) -> Bool {
        if self == .any { return true }

        // Все проверки — по ASCII: без регулярных выражений и аллокаций.
        guard let ascii = char.asciiValue else { return false }

        let isDigit = (0x30...0x39).contains(ascii)
        let isLetter = (0x41...0x5A).contains(ascii) || (0x61...0x7A).contains(ascii)
        let isVisible = (0x21...0x7E).contains(ascii)

        switch self {
        case .digit: return isDigit
        case .letter: return isLetter
        case .letterOrDigit: return isLetter || isDigit
        case .anySymbol: return isVisible && !isDigit
        case .anySymbolOrDigit: return isVisible
        case .any: return true
        }
    }
}

/// Неизменяемое описание одной позиции маски: литерал или вводимый символ.
struct MaskSlot {
    /// Символ маски: литерал для вывода либо спецсимвол типа позиции.
    let char: Character

    /// Тип вводимой позиции; `nil` для литерала (в том числе экранированного).
    let type: MaskCharType?

    /// Значение позиции скрывается при потере фокуса (`^c`).
    let veiled: Bool

    var canEntered: Bool {
        type != nil
    }

    func accepts(_ char: Character) -> Bool {
        type?.accepts(char) ?? false
    }

    /// Разбирает строку маски в набор позиций.
    ///
    /// - `\c` — экранированный литерал `c`;
    /// - `^c` — вводимая позиция, скрываемая при потере фокуса;
    /// - остальные символы — спецсимволы типов (`d`, `a`, …) либо литералы.
    static func parse(_ mask: String) -> [MaskSlot] {
        let chars = Array(mask)
        var slots: [MaskSlot] = []
        var index = 0

        while index < chars.count {
            let c = chars[index]
            let hasNext = index + 1 < chars.count

            if c == "\\" && hasNext {
                index += 1
                slots.append(MaskSlot(char: chars[index], type: nil, veiled: false))
            } else if c == "^" && hasNext {
                index += 1
                let next = chars[index]
                slots.append(MaskSlot(char: next, type: MaskCharType.type(for: next), veiled: true))
            } else {
                slots.append(MaskSlot(char: c, type: MaskCharType.type(for: c), veiled: false))
            }

            index += 1
        }

        return slots
    }
}
