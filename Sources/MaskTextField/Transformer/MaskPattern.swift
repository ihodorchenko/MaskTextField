import Foundation

/// The type of an editable mask position.
///
/// - `d` — a digit `0-9`
/// - `a` — a Latin letter `a-zA-Z`
/// - `A` — a Latin letter or a digit
/// - `x` — any visible ASCII character except a digit: a letter or a punctuation mark/symbol
/// - `X` — any visible ASCII character, digits included (a space is not)
/// - `z` — any character, without validation
enum MaskCharType {
    case digit
    case letter
    case letterOrDigit
    case anySymbol
    case anySymbolOrDigit
    case any

    /// Returns the type for a mask character, or `nil` for a literal.
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

    /// Checks whether a character is acceptable at a position of this type.
    func accepts(_ char: Character) -> Bool {
        if self == .any { return true }

        // All checks are ASCII-based: no regular expressions, no allocations.
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

/// An immutable description of one mask position: a literal or an editable character.
struct MaskSlot {
    /// The mask character: a literal to output or a special character of the position type.
    let char: Character

    /// The type of the editable position; `nil` for a literal (including an escaped one).
    let type: MaskCharType?

    /// The position value is veiled when focus is lost (`^c`).
    let veiled: Bool

    var canEntered: Bool {
        type != nil
    }

    func accepts(_ char: Character) -> Bool {
        type?.accepts(char) ?? false
    }

    /// Parses a mask string into a set of positions.
    ///
    /// - `\c` — an escaped literal `c`;
    /// - `^c` — an editable position that is veiled when focus is lost;
    /// - other characters — special type characters (`d`, `a`, …) or literals.
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
