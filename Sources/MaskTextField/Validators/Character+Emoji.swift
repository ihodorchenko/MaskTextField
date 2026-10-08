import Foundation

extension Character {
    /// Whether the character (grapheme cluster) is an emoji.
    ///
    /// Digits, `#`, `*`, `©`, `™` and "text" symbols without an emoji selector (`❤` without
    /// `U+FE0F`) are not considered emoji. Composite emoji (ZWJ sequences, flags,
    /// skin tones, keycaps) are detected as a whole rather than by individual scalars.
    public var isEmojiCharacter: Bool {
        let scalars = self.unicodeScalars

        if scalars.count > 1 {
            return scalars.contains {
                $0.properties.isEmojiPresentation
                    || $0.properties.isEmojiModifier
                    || $0.value == 0xFE0F   // emoji variation selector
                    || $0.value == 0x200D   // ZWJ
                    || $0.value == 0x20E3   // keycap
            }
        }

        return scalars.first?.properties.isEmojiPresentation ?? false
    }
}
