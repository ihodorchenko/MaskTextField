import Foundation

/// Запрещает эмодзи (включая составные: флаги, семьи, цвета кожи, keycap).
public final class EmojiFreeValidator: CharValidator {
    public init() {}

    public func check(char: Character) -> Bool {
        !char.isEmojiCharacter
    }
}

/// Разрешает только символы из заданного набора.
public final class AllowedCharactersValidator: CharValidator {
    private let allowed: CharacterSet

    public init(allowed: CharacterSet) {
        self.allowed = allowed
    }

    public func check(char: Character) -> Bool {
        char.unicodeScalars.allSatisfy { self.allowed.contains($0) }
    }
}

/// Ограничивает длину текста. Изменение, после которого текст станет длиннее, отклоняется
/// целиком (в том числе вставка).
public final class MaxLengthValidator: CharValidator {
    private let maxLength: Int

    public init(maxLength: Int) {
        self.maxLength = maxLength
    }

    public func check(string: String) -> Bool {
        string.count <= self.maxLength
    }
}

/// Объединяет несколько валидаторов: символ и текст должны пройти все,
/// `correct(string:)` применяется по порядку.
public final class CompositeValidator: CharValidator {
    private let validators: [CharValidator]

    public init(_ validators: [CharValidator]) {
        self.validators = validators
    }

    public func check(char: Character) -> Bool {
        self.validators.allSatisfy { $0.check(char: char) }
    }

    public func check(string: String) -> Bool {
        self.validators.allSatisfy { $0.check(string: string) }
    }

    public func correct(string: String) -> String {
        self.validators.reduce(string) { $1.correct(string: $0) }
    }
}
