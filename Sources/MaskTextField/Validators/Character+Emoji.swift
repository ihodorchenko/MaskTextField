import Foundation

extension Character {
    /// Является ли символ (grapheme cluster) эмодзи.
    ///
    /// Цифры, `#`, `*`, `©`, `™` и «текстовые» символы без селектора эмодзи (`❤` без
    /// `U+FE0F`) эмодзи не считаются. Составные эмодзи (ZWJ-последовательности, флаги,
    /// цвета кожи, keycap) определяются целиком, а не по отдельным скалярам.
    public var isEmojiCharacter: Bool {
        let scalars = self.unicodeScalars

        if scalars.count > 1 {
            return scalars.contains {
                $0.properties.isEmojiPresentation
                    || $0.properties.isEmojiModifier
                    || $0.value == 0xFE0F   // селектор эмодзи
                    || $0.value == 0x200D   // ZWJ
                    || $0.value == 0x20E3   // keycap
            }
        }

        return scalars.first?.properties.isEmojiPresentation ?? false
    }
}
