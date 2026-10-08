import Foundation

/// Forbids emoji (composite ones included: flags, families, skin tones, keycaps).
public final class EmojiFreeValidator: CharValidator {
    public init() {}

    public func check(char: Character) -> Bool {
        !char.isEmojiCharacter
    }
}

/// Allows only characters from the given set.
public final class AllowedCharactersValidator: CharValidator {
    private let allowed: CharacterSet

    public init(allowed: CharacterSet) {
        self.allowed = allowed
    }

    public func check(char: Character) -> Bool {
        char.unicodeScalars.allSatisfy { self.allowed.contains($0) }
    }
}

/// Limits the text length. A change after which the text would be longer is rejected
/// as a whole (pasting included).
public final class MaxLengthValidator: CharValidator {
    private let maxLength: Int

    public init(maxLength: Int) {
        self.maxLength = maxLength
    }

    public func check(string: String) -> Bool {
        string.count <= self.maxLength
    }
}

/// Combines several validators: a character and a text must pass all of them,
/// `correct(string:)` is applied in order.
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
