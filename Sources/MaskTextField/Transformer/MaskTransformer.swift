import Foundation

/// Трансформер, накладывающий маску на вводимый текст.
///
/// Маска описывается строкой, в которой спецсимволы задают вводимые позиции:
/// - `d` — цифра `[0-9]`
/// - `a` — буква `[a-zA-Z]`
/// - `A` — буква или цифра `[a-zA-Z0-9]`
/// - `x` — произвольный символ
/// - `X` — произвольный символ или цифра
/// - `z` — произвольный символ без проверки
/// - `\c` — экранированный символ (литерал, даже если совпадает со спецсимволом)
/// - `^c` — вводимая позиция, значение которой скрывается при потере фокуса
///
/// Остальные символы — литералы, выводимые как есть.
fileprivate enum MaskCharType {
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

    /// Регулярное выражение для валидации, либо `nil`, если проверка не нужна (`z`).
    var regex: String? {
        switch self {
        case .digit: return "[0-9]"
        case .letter: return "[a-zA-Z]"
        case .letterOrDigit: return "[a-zA-Z0-9]"
        case .anySymbol: return "[a-zA-Z!@#$%^&*()_\\-+={};:<>|./?.]"
        case .anySymbolOrDigit: return "[a-zA-Z0-9!@#$%^&*()_\\-+={};:<>|./?.]"
        case .any: return nil
        }
    }
}

public class MaskTransformer: FilterTransformer {
    public static let hideChar: Character = "•"
    public static let defaultMaskChar: Character = "_"

    private var _maskInfo: [CharInfo] = []
    private var _maskLostFocusInfo: [CharInfo] = []

    private var _isFocus: Bool = false

    // MARK: - Filter Transformer

    private var _onlyEnteredCount: Int = 0

    open override var onlyEnteredCount: Int {
        self._onlyEnteredCount
    }

    /// Нормализует вставляемую строку: оставляет только символы, допустимые
    /// на вводимых позициях, и обрезает до их количества (при вставке
    /// используются последние символы).
    open override func normalizedValue(from value: String) -> String {
        let entered = self._maskInfo.filter { $0.canEntered }
        guard !entered.isEmpty else { return "" }

        let filtered = value.filter { char in
            entered.contains { $0.isValid(char: char) }
        }

        let count = self.onlyEnteredCount
        if filtered.count > count {
            return filtered.substring(start: filtered.count - count, length: count)
        }
        return filtered
    }

    override open var text: String? {
        get {
            self._maskInfo.reduce(into: "") { result, info in
                if info.enteredChar != CharInfo.nilChar {
                    result.append(info.enteredChar)
                }
            }
        }
        set {
            self.distributeRawValue(newValue ?? "")
        }
    }

    /// Раскладывает «сырое» значение (без маски) по вводимым позициям.
    ///
    /// Для каждой позиции берётся следующий подходящий по `isValid` символ;
    /// неподходящие символы пропускаются. Если подходящих символов не осталось,
    /// позиция остаётся пустой.
    private func distributeRawValue(_ value: String) {
        var valueIndex = 0

        for info in self._maskInfo where info.canEntered {
            while valueIndex < value.count, !info.isValid(char: value[valueIndex]) {
                valueIndex += 1
            }

            if valueIndex < value.count {
                info.enteredChar = value[valueIndex]
                valueIndex += 1
            } else {
                info.enteredChar = CharInfo.nilChar
            }
        }

        self.setTextAndCursor()
    }

    open var visibleTextMask: String {
        return self._maskInfo.reduce("", { result, info in result + "\(info.maskChar)" })
    }

    open var visibleTextMaskLostFocus: String {
        return self._maskLostFocusInfo.reduce("", { result, info in result + "\(info.maskChar)" })
    }

    // MARK: - override func

    open override func onDeleteBackward(at offset: Int = Int.max) {
        guard let index = self.removeLastEntered(before: offset) else { return }

        self.setTextAndCursor(cursorPosition: index)
    }

    open override func onTextInput(_ text: String, at offset: Int = 0) -> Bool {
        guard let f = text.first else { return false }

        guard let index = self.insert(char: f, at: offset) else { return false }

        self.setTextAndCursor(cursorPosition: index + 1)

        return true
    }

    open override func onSelectionChanged() {
        self.setTextAndCursor()
    }

    open override func onGotFocus() {
        self._isFocus = true
        self.setTextAndCursor()
    }

    open override func onLostFocus() {
        self._isFocus = false
        self.setTextAndCursor()
    }

    // MARK: - property

    public var veiledMaskChar: Character = MaskTransformer.hideChar {
        didSet {
            self._maskInfo.forEach {
                if $0.canEntered {
                    $0.veiledMaskChar = self.veiledMaskChar
                }
            }
            self.setTextAndCursor()
        }
    }

    public var maskChar: Character = MaskTransformer.defaultMaskChar {
        didSet {
            self._maskInfo.forEach {
                if $0.canEntered {
                    $0.maskChar = self.maskChar
                }
            }
            self.setTextAndCursor()
        }
    }

    public var hideChars: Bool = false {
        didSet {
            self.setTextAndCursor()
        }
    }

    public var mask: String = "" {
        didSet {
            self.createMaskInformation()
            self.setTextAndCursor()
        }
    }

    public var maskLostFocus: String = "" {
        didSet {
            self.createMaskLostFocusInformation()
            self.setTextAndCursor()
        }
    }

    public var maskMode: MaskMode = .fullMask {
        didSet {
            self.setTextAndCursor()
        }
    }

    public var hiddenMaskIfEnteredTextEmpty: Bool = false {
        didSet {
            self.setTextAndCursor()
        }
    }

    // MARK: - private func

    private func charStateChanged() {
        self.setTextAndCursor()
    }

    /// Вставляет символ в первую пустую вводимую позицию, начиная с `offset`.
    /// Возвращает индекс позиции либо `nil`, если позиции нет или символ не подходит.
    private func insert(char: Character, at offset: Int) -> Int? {
        let start = min(max(offset, 0), self._maskInfo.count)
        guard start < self._maskInfo.count else { return nil }

        for index in start..<self._maskInfo.count {
            let info = self._maskInfo[index]
            guard info.canEntered, info.isNilChar else { continue }

            guard info.isValid(char: char) else { return nil }
            info.enteredChar = char
            return index
        }

        return nil
    }

    /// Удаляет последнюю заполненную позицию с индексом не больше `offset`.
    /// Возвращает индекс удалённой позиции либо `nil`, если удалять нечего.
    private func removeLastEntered(before offset: Int) -> Int? {
        var index = min(offset, self._maskInfo.count - 1)
        guard index >= 0 else { return nil }

        while index >= 0 {
            let info = self._maskInfo[index]
            if info.canEntered, !info.isNilChar {
                info.enteredChar = CharInfo.nilChar
                return index
            }
            index -= 1
        }

        return nil
    }

    private func setTextAndCursor(cursorPosition: Int? = nil) {
        var text: String = ""
        var cursor: Int = 0

        self.getTextAndCursor(&cursor, &text, cursorPosition: cursorPosition)

        guard let control = self.control else { return }

        if self.hiddenMaskIfEnteredTextEmpty && !self._isFocus && (self.text ?? "").isEmpty {
            control.text = ""
            return
        }

        control.text = text

        control.setCursorPosition(cursor)
    }

    private func getTextAndCursor(_ cursor: inout Int, _ text: inout String, cursorPosition: Int? = nil) {
        if self.hideChars {
            if let lastEnteredChar = self._maskInfo.last(where: { $0.enteredChar != CharInfo.nilChar }) {
                self._maskInfo.forEach {
                    if $0.canEntered && $0 !== lastEnteredChar {
                        $0.hiddenChar = true
                    }
                }
            }
        }

        if self._isFocus || self._maskLostFocusInfo.isEmpty {
            text = self._maskInfo.reduce("", { current, charInfo in
                if charInfo.enteredChar != CharInfo.nilChar {
                    if self.hideChars {
                        return current + "\(charInfo.hiddenChar ? charInfo.veiledMaskChar : charInfo.enteredChar)"
                    } else {
                        return current + "\(!charInfo.veiledChar ? charInfo.enteredChar : self._isFocus ? charInfo.enteredChar : self.veiledMaskChar)"
                    }
                } else {
                    return current + "\(charInfo.maskChar)"
                }
            })
        } else {
            var realText = self._maskInfo.reduce("", { current, charInfo in
                if charInfo.enteredChar != CharInfo.nilChar {
                    if self.hideChars {
                        return current + "\(charInfo.hiddenChar ? charInfo.veiledMaskChar : charInfo.enteredChar)"
                    } else {
                        return current + "\(!charInfo.veiledChar ? charInfo.enteredChar : self._isFocus ? charInfo.enteredChar : self.veiledMaskChar)"
                    }
                }

                return current
            })

            text = self._maskLostFocusInfo.reduce("", { current, charInfo in
                if charInfo.canEntered && !realText.isEmpty {
                    let char = realText.removeFirst()
                    return current + "\(char)"
                } else {
                    return current + "\(charInfo.maskChar)"
                }
            })
        }

        cursor = self._maskInfo.count

        if let last = self._maskInfo.lastIndex(where: { $0.canEntered }) {
            cursor = last + 1
        }

        if let first = self._maskInfo.firstIndex(where: { $0.canEntered && $0.isNilChar }) {
            cursor = first
        }

        // Явная позиция курсора после редактирования (вставка/удаление).
        if let position = cursorPosition {
            cursor = min(max(position, 0), self._maskInfo.count)
        }

        if self.maskMode == .gradualMask {
            text = text.substring(start: 0, length: cursor)
        }
    }

    private func createMaskInformation() {
        self._maskInfo.removeAll()

        var index: Int = 0
        while index < self.mask.count {
            var c = self.mask[index]

            let ci: CharInfo
            if c == "\\" && index + 1 < self.mask.count {
                index += 1
                c = self.mask[index]
                ci = CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: true)
            } else if c == "^" && index + 1 < self.mask.count {
                index += 1
                c = self.mask[index]
                ci = with(CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: false)) {
                    $0.veiledChar = true
                }
            } else {
                ci = CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: false)
            }

            index += 1

            if ci.canEntered {
                ci.maskChar = self.maskChar
                ci.veiledMaskChar = self.veiledMaskChar
            }

            self._maskInfo.append(ci)
        }

        self._onlyEnteredCount = self._maskInfo.filter { $0.canEntered }.count
    }

    private func createMaskLostFocusInformation() {
        self._maskLostFocusInfo.removeAll()

        var index: Int = 0
        while index < self.maskLostFocus.count {
            var c = self.maskLostFocus[index]

            let ci: CharInfo
            if c == "\\" && index + 1 < self.maskLostFocus.count {
                index += 1
                c = self.maskLostFocus[index]
                ci = CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: true)
            } else if c == "^" && index + 1 < self.maskLostFocus.count {
                index += 1
                c = self.maskLostFocus[index]
                ci = with(CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: false)) {
                    $0.veiledChar = true
                }
            } else {
                ci = CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: false)
            }

            index += 1

            if ci.canEntered {
                ci.maskChar = self.maskChar
                ci.veiledMaskChar = self.veiledMaskChar
            }

            self._maskLostFocusInfo.append(ci)
        }
    }
}

extension MaskTransformer {
    class CharInfo {
        public static let nilChar: Character = "\0"
        public static let hideCharDelay: TimeInterval = 1.5

        // MARK: - variable

        private let _escaped: Bool
        private let _char: Character
        private let _maskChar: Character
        private let _type: MaskCharType?

        private var _timer: Timer? = nil
        private weak var _transformer: MaskTransformer? = nil

        private lazy var _regex: NSPredicate? = {
            guard let pattern = self._type?.regex else { return nil }
            return NSPredicate(format: "SELF MATCHES %@", pattern)
        }()

        // MARK: - property

        public var canEntered: Bool {
            return !self._escaped && self._type != nil
        }

        private var _maskCharValue: Character?
        public var maskChar: Character {
            get {
                self._maskCharValue ?? (self.canEntered ? self._maskChar : self._char)
            }
            set {
                self._maskCharValue = newValue
            }
        }

        public var veiledMaskChar: Character = CharInfo.nilChar
        public var hiddenChar: Bool = false
        public var veiledChar: Bool = false

        // MARK: - init

        init(char: Character, masChar: Character, transformer: MaskTransformer, escaped: Bool) {
            self._char = char
            self._maskChar = char
            self._transformer = transformer
            self._escaped = escaped
            self._type = MaskCharType.type(for: char)
        }

        // MARK: - Entered Char

        public var enteredChar: Character = CharInfo.nilChar {
            didSet {
                if self._transformer?.hideChars ?? false {
                    self.hiddenChar = false
                    if self.enteredChar != CharInfo.nilChar {
                        self.startHideTimer()
                    }
                }
            }
        }

        public var isNilChar: Bool {
            return self.enteredChar == CharInfo.nilChar
        }

        // MARK: - valid

        public func isValid(char: Character) -> Bool {
            if let regex = self._regex {
                return regex.evaluate(with: "\(char)")
            }

            // Нет регулярного выражения: литерал — false, `z` — принимает любой символ.
            return self._type == .any
        }

        // MARK: - timer

        private func startHideTimer() {
            self._timer?.invalidate()
            self._timer = nil

            self._timer = Timer.scheduledTimer(
                withTimeInterval: CharInfo.hideCharDelay,
                repeats: false
            ) { [weak self] _ in
                self?.hideTimerFired()
            }
        }

        private func hideTimerFired() {
            self._timer?.invalidate()
            self._timer = nil

            if self.hiddenChar {
                return
            }

            self.hiddenChar = true
            self._transformer?.charStateChanged()
        }

        deinit {
            self._timer?.invalidate()
        }
    }
}
