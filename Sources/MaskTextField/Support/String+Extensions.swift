import Foundation

public extension String {
    /// Доступ к символу по целочисленному индексу.
    ///
    /// Упрощает посимвольный разбор маски. Выход за границы приведёт к крашу,
    /// поэтому вызывающий код обязан гарантировать корректный индекс.
    subscript(offset: Int) -> Character {
        get {
            self[self.index(self.startIndex, offsetBy: offset)]
        }
    }

    /// Возвращает подстроку, начиная с `start`, длиной `length`.
    ///
    /// В отличие от `NSString.substring(with:)`, безопасна: при выходе за границы
    /// возвращается максимально доступная подстрока, а не краш.
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

    /// Индекс символа (grapheme cluster), на который приходится `utf16Offset`.
    ///
    /// Курсор `UITextField` задаётся в UTF-16 единицах, а позиция маски — в
    /// символах. Метод преобразует первое во второе; если смещение попадает
    /// внутрь многобайтового символа, округляет вниз.
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

    /// UTF-16 offset, соответствующий индексу символа (grapheme cluster).
    func utf16Offset(characterIndex: Int) -> Int {
        let index = self.index(
            self.startIndex,
            offsetBy: characterIndex,
            limitedBy: self.endIndex
        ) ?? self.endIndex

        return self[..<index].utf16.count
    }
}
