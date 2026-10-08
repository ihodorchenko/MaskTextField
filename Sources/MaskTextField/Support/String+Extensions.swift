import Foundation

extension String {
    /// Access to a character by an integer index.
    ///
    /// Simplifies character-by-character parsing of a mask. Out-of-bounds access crashes,
    /// so the caller must guarantee a valid index.
    subscript(offset: Int) -> Character {
        get {
            self[self.index(self.startIndex, offsetBy: offset)]
        }
    }

    /// Returns a substring starting at `start` with the given `length`.
    ///
    /// Unlike `NSString.substring(with:)` it is safe: when out of bounds, the largest
    /// available substring is returned instead of crashing.
    func substring(start: Int, length: Int) -> String {
        guard start >= 0, length >= 0 else { return "" }

        let startIndex = self.index(
            self.startIndex,
            offsetBy: start,
            limitedBy: self.endIndex
        ) ?? self.endIndex

        let endIndex = self.index(
            startIndex,
            offsetBy: length,
            limitedBy: self.endIndex
        ) ?? self.endIndex

        return String(self[startIndex..<endIndex])
    }

    /// The index of the character (grapheme cluster) that `utf16Offset` falls into.
    ///
    /// A `UITextField` cursor is expressed in UTF-16 units, while a mask position is expressed
    /// in characters. This method converts the former to the latter; if the offset falls
    /// inside a multi-unit character, it rounds down.
    func characterIndex(utf16Offset: Int) -> Int {
        guard utf16Offset > 0 else { return 0 }

        var utf16Count = 0
        var characterIndex = 0

        for character in self {
            let width = String(character).utf16.count
            if utf16Count + width > utf16Offset { break }
            utf16Count += width
            characterIndex += 1
        }

        return characterIndex
    }

    /// The UTF-16 offset that corresponds to a character (grapheme cluster) index.
    func utf16Offset(characterIndex: Int) -> Int {
        let index = self.index(
            self.startIndex,
            offsetBy: characterIndex,
            limitedBy: self.endIndex
        ) ?? self.endIndex

        return self[..<index].utf16.count
    }
}
