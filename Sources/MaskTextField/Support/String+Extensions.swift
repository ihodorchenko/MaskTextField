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
}
