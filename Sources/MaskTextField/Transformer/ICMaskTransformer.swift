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
public class ICMaskTransformer: ICFilterTransformer {
    public static let hideChar: Character = "•"
    public static let defaultMaskChar: Character = "_"

    private var _maskInfo: [CharInfo] = []
    private var _maskLostFocusInfo: [CharInfo] = []

    private var _isFocus: Bool = false

    // MARK: - Filter Transformer

    open override var onlyEnteredCount: Int {
        self._maskInfo.filter { $0.canEntered }.count
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

    open override func onDeleteBackward() {
        self.deleteChar()
        self.setTextAndCursor()
    }

    open override func onTextInput(_ text: String) -> Bool {
        guard let f = text.first else { return false }

        let result = self.enterChar(f)
        self.setTextAndCursor()

        return result
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

    public var veiledMaskChar: Character = ICMaskTransformer.hideChar {
        didSet {
            self._maskInfo.forEach {
                if $0.canEntered {
                    $0.veiledMaskChar = self.veiledMaskChar
                }
            }
            self.setTextAndCursor()
        }
    }

    public var maskChar: Character = ICMaskTransformer.defaultMaskChar {
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

    public var maskMode: ICMaskMode = .fullMask {
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

    private func enterChar(_ char: Character) -> Bool {
        guard let f = self._maskInfo.first(where: { $0.canEntered && $0.enteredChar == CharInfo.nilChar }) else { return false }

        guard f.isValid(char: char) else { return false }

        f.enteredChar = char

        return true
    }

    private func deleteChar() {
        guard let l = self._maskInfo.last(where: { $0.canEntered && $0.enteredChar != CharInfo.nilChar }) else { return }

        l.enteredChar = CharInfo.nilChar
    }

    private func setTextAndCursor() {
        var text: String = ""
        var cursor: Int = 0

        self.getTextAndCursor(&cursor, &text)

        guard let control = self.control else { return }

        if self.hiddenMaskIfEnteredTextEmpty && !self._isFocus && (self.text ?? "").isEmpty {
            control.text = ""
            return
        }

        control.text = text

        control.setCursorPosition(cursor)
    }

    private func getTextAndCursor(_ cursor: inout Int, _ text: inout String) {
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
                ci = CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: false) => {
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
                ci = CharInfo(char: c, masChar: self.maskChar, transformer: self, escaped: false) => {
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

extension ICMaskTransformer {
    class CharInfo {
        public static let nilChar: Character = "\0"
        public static let hideCharDelay: TimeInterval = 1.5

        // MARK: - variable

        private let _escaped: Bool
        private let _char: Character
        private let _maskChar: Character

        private var _timer: Timer? = nil
        private weak var _transformer: ICMaskTransformer? = nil

        private lazy var _regex: NSPredicate? = {
            switch self._char {
            case "d":
                return NSPredicate(format: "SELF MATCHES %@", "[0-9]")
            case "a":
                return NSPredicate(format: "SELF MATCHES %@", "[a-zA-Z]")
            case "A":
                return NSPredicate(format: "SELF MATCHES %@", "[a-zA-Z0-9]")
            case "x":
                return NSPredicate(format: "SELF MATCHES %@", "[a-zA-Z!@#$%^&*()_\\-+={};:<>|./?.]")
            case "X":
                return NSPredicate(format: "SELF MATCHES %@", "[a-zA-Z0-9!@#$%^&*()_\\-+={};:<>|./?.]")
            case "z":
                return nil
            default:
                return nil
            }
        }()

        // MARK: - property

        public var canEntered: Bool {
            return !self._escaped && self.isEntered
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

        init(char: Character, masChar: Character, transformer: ICMaskTransformer, escaped: Bool) {
            self._char = char
            self._maskChar = char
            self._transformer = transformer
            self._escaped = escaped
        }

        // MARK: - initialisation

        private var isEntered: Bool {
            return self._regex != nil
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
            guard let regex = self._regex else { return true }

            return regex.evaluate(with: "\(char)")
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
