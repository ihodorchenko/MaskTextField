import Foundation

/// Трансформер, накладывающий маску на вводимый текст.
///
/// Маска описывается строкой, в которой спецсимволы задают вводимые позиции:
/// - `d` — цифра `[0-9]`
/// - `a` — латинская буква `[a-zA-Z]`
/// - `A` — латинская буква или цифра
/// - `x` — любой видимый ASCII-символ, кроме цифр
/// - `X` — любой видимый ASCII-символ, включая цифры
/// - `z` — произвольный символ без проверки
/// - `\c` — экранированный символ (литерал, даже если совпадает со спецсимволом)
/// - `^c` — вводимая позиция, значение которой скрывается при потере фокуса
///
/// Остальные символы — литералы, выводимые как есть.
///
/// Шаблон маски (`MaskSlot`) неизменяем; введённые значения и флаги скрытия
/// хранятся отдельно, в массивах, индексированных так же, как позиции маски.

public final class MaskTransformer: FilterTransformer {
    public static let hideChar: Character = "•"
    public static let defaultMaskChar: Character = "_"

    /// Задержка перед скрытием последнего введённого символа в режиме `hideChars`.
    public static let hideCharDelay: TimeInterval = 1.5

    private var slots: [MaskSlot] = []
    private var lostFocusSlots: [MaskSlot] = []

    /// Введённые значения по индексам `slots`; `nil` — позиция пуста (или литерал).
    private var entered: [Character?] = []

    /// Признак «скрыто» по индексам `slots` (режим `hideChars`).
    private var hidden: [Bool] = []

    private var hideTimer: Timer?

    /// Время ожидания, в течение которого первое выделение после получения фокуса
    /// трактуется как установка курсора тапом и заменяется переходом на первую
    /// свободную позицию (`.snapOnFocus`).
    static var focusSnapWindow: TimeInterval = 0.5

    /// Момент (`systemUptime`), до которого действует привязка курсора после фокуса.
    private var focusSnapDeadline: TimeInterval?

    private var _isFocus: Bool = false

    /// Флаг, показывающий, что `setTextAndCursor` сейчас сам меняет текст/курсор.
    /// Предотвращает рекурсию: `setCursorPosition` → `textFieldDidChangeSelection` →
    /// `onSelectionChanged` → `setTextAndCursor` → …
    private var isRendering: Bool = false

    deinit {
        self.hideTimer?.invalidate()
    }

    // MARK: - Filter Transformer

    private var _onlyEnteredCount: Int = 0

    public override var onlyEnteredCount: Int {
        self._onlyEnteredCount
    }

    /// Заполнены ли все вводимые позиции маски (маска без вводимых позиций не бывает заполненной).
    public override var isComplete: Bool {
        self._onlyEnteredCount > 0
            && self.slots.indices.allSatisfy { !self.slots[$0].canEntered || self.entered[$0] != nil }
    }

    /// Нормализует вставляемую строку: оставляет только символы, допустимые
    /// на вводимых позициях, и обрезает до их количества (при вставке
    /// используются последние символы).
    public override func normalizedValue(from value: String) -> String {
        let enteredSlots = self.slots.filter { $0.canEntered }
        guard !enteredSlots.isEmpty else { return "" }

        let filtered = value.filter { char in
            enteredSlots.contains { self.accepts(char, in: $0) }
        }

        let count = self.onlyEnteredCount
        if filtered.count > count {
            return filtered.substring(start: filtered.count - count, length: count)
        }
        return filtered
    }

    override public var text: String? {
        get {
            String(self.entered.compactMap { $0 })
        }
        set {
            if self.maskProvider != nil {
                self.dynamicSetText(newValue ?? "")
            } else {
                self.fill(with: newValue ?? "")
            }
            self.setTextAndCursor()
        }
    }

    /// Раскладывает «сырое» значение (без маски) по вводимым позициям.
    ///
    /// Для каждой позиции берётся следующий подходящий по `accepts` символ;
    /// неподходящие символы пропускаются. Если подходящих символов не осталось,
    /// позиция остаётся пустой. Возвращает индексы заполненных позиций по порядку.
    @discardableResult
    private func fill(with value: String) -> [Int] {
        let chars = Array(value)
        var valueIndex = 0
        var filled: [Int] = []

        for (index, slot) in self.slots.enumerated() where slot.canEntered {
            while valueIndex < chars.count, !self.accepts(chars[valueIndex], in: slot) {
                valueIndex += 1
            }

            if valueIndex < chars.count {
                self.setEntered(chars[valueIndex], at: index)
                filled.append(index)
                valueIndex += 1
            } else {
                self.setEntered(nil, at: index)
            }
        }

        return filled
    }

    public var visibleTextMask: String {
        String(self.slots.map { self.placeholder(for: $0) })
    }

    public var visibleTextMaskLostFocus: String {
        String(self.lostFocusSlots.map { self.placeholder(for: $0) })
    }

    /// Описание значения для VoiceOver: без заглушек маски и без скрытых символов.
    ///
    /// Пустое поле — «Пусто»; если символы скрыты (`hideChars` или `^` без фокуса),
    /// озвучивается только количество введённых символов.
    public var accessibilityDescription: String {
        let chars = self.entered.compactMap { $0 }
        guard !chars.isEmpty else { return L10n.string("a11y.empty") }

        let hasVeiled = !self._isFocus && zip(self.slots, self.entered).contains { $0.veiled && $1 != nil }
        if self.hideChars || hasVeiled {
            return L10n.enteredCount(chars.count, of: self.onlyEnteredCount)
        }

        return chars.map { String($0) }.joined(separator: " ")
    }

    // MARK: - override func

    public override func onDeleteBackward(at offset: Int = Int.max) {
        if self.maskProvider != nil {
            self.dynamicDelete(at: offset)
            return
        }

        let limit = self.cursorBehavior == .sequential ? Int.max : offset
        guard let index = self.removeLastEntered(before: limit) else { return }

        self.setTextAndCursor(cursorPosition: index)
    }

    public override func onTextInput(_ text: String, at offset: Int = 0) -> Bool {
        guard let f = text.first else { return false }

        if self.maskProvider != nil {
            return self.dynamicInsert(f, at: offset)
        }

        let start = self.cursorBehavior == .sequential ? 0 : offset
        guard let index = self.insert(char: f, at: start) else { return false }

        // Курсор — на следующей пустой вводимой позиции, литералы пропускаются.
        let cursor = self.nextEmptyEnteredIndex(after: index) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)

        return true
    }

    /// Заменяет диапазон `range` (в позициях маски) строкой `text`.
    ///
    /// Символы вне диапазона сохраняются и сдвигаются, так что вставка в середину
    /// не затирает остальное значение, а замена выделения убирает выделенное.
    /// Строка `text` предварительно нормализуется (`normalizedValue(from:)`).
    public override func onPaste(_ text: String, in range: Range<Int>) {
        if self.maskProvider != nil {
            self.dynamicPaste(text, in: range)
            return
        }

        var lower = min(max(range.lowerBound, 0), self.slots.count)
        var upper = min(max(range.upperBound, lower), self.slots.count)

        if self.cursorBehavior == .sequential {
            // Только в конец: пустой диапазон — добавление, выделение — «до конца».
            lower = range.isEmpty ? self.slots.count : lower
            upper = self.slots.count
        }

        var prefix = ""
        var suffix = ""
        for (index, char) in self.entered.enumerated() {
            guard let char else { continue }
            if index < lower {
                prefix.append(char)
            } else if index >= upper {
                suffix.append(char)
            }
        }

        let pasted = self.normalizedValue(from: text)
        let combined = String((prefix + pasted + suffix).prefix(self.onlyEnteredCount))
        let filled = self.fill(with: combined)

        // Курсор — сразу за последним вставленным символом (литералы пропускаются).
        let insertedCount = prefix.count + pasted.count
        let anchor: Int
        if insertedCount > 0, insertedCount <= filled.count {
            anchor = filled[insertedCount - 1] + 1
        } else {
            anchor = lower
        }

        let cursor = self.firstEnteredIndex(from: anchor) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)
    }

    public override func onSelectionChanged() {
        guard !self.isRendering else { return }

        if self.cursorBehavior == .snapOnFocus, let deadline = self.focusSnapDeadline {
            // Один раз: выделение, которое UIKit ставит по тапу сразу после фокуса.
            self.focusSnapDeadline = nil
            if ProcessInfo.processInfo.systemUptime <= deadline {
                self.setTextAndCursor()
                return
            }
        }

        if self.cursorBehavior == .sequential {
            // Произвольный курсор запрещён: возвращаем его на первую свободную позицию.
            self.setTextAndCursor()
            return
        }

        // Сохраняем текущую позицию курсора (пользователь мог переместить его),
        // а не «отскакиваем» на первую пустую вводимую позицию.
        self.setTextAndCursor(cursorPosition: self.control?.cursorOffset)
    }

    public override func onGotFocus() {
        self._isFocus = true
        self.focusSnapDeadline = self.cursorBehavior == .snapOnFocus
            ? ProcessInfo.processInfo.systemUptime + MaskTransformer.focusSnapWindow
            : nil
        self.setTextAndCursor()
    }

    public override func onLostFocus() {
        self._isFocus = false
        self.focusSnapDeadline = nil
        self.setTextAndCursor()
    }

    // MARK: - property

    public var veiledMaskChar: Character = MaskTransformer.hideChar {
        didSet {
            self.setTextAndCursor()
        }
    }

    public var maskChar: Character = MaskTransformer.defaultMaskChar {
        didSet {
            self.setTextAndCursor()
        }
    }

    public var hideChars: Bool = false {
        didSet {
            if !self.hideChars {
                self.cancelHideTimer()
            }
            self.setTextAndCursor()
        }
    }

    /// Динамические маски: по текущему «сырому» значению возвращает вариант маски.
    /// Пока провайдер задан, свойства `mask` и `maskLostFocus` не используются.
    /// Провайдер вызывается на каждое изменение и должен быть чистой функцией.
    public var maskProvider: ((String) -> MaskVariant)? {
        didSet {
            if self.maskProvider != nil {
                self.activeVariant = nil
                self.dynamicSetText(self.text ?? "")
            } else {
                self.activeVariant = nil
                self.slots = MaskSlot.parse(self.mask)
                self.lostFocusSlots = MaskSlot.parse(self.maskLostFocus)
                self.entered = Array(repeating: nil, count: self.slots.count)
                self.hidden = Array(repeating: false, count: self.slots.count)
                self._onlyEnteredCount = self.slots.filter { $0.canEntered }.count
            }
            self.setTextAndCursor()
        }
    }

    /// Вариант, выбранный провайдером на данный момент (`nil` без динамических масок).
    var activeVariant: MaskVariant?

    public var mask: String = "" {
        didSet {
            guard self.maskProvider == nil else { return }

            self.slots = MaskSlot.parse(self.mask)
            self.entered = Array(repeating: nil, count: self.slots.count)
            self.hidden = Array(repeating: false, count: self.slots.count)
            self._onlyEnteredCount = self.slots.filter { $0.canEntered }.count
            self.cancelHideTimer()
            self.setTextAndCursor()
        }
    }

    public var maskLostFocus: String = "" {
        didSet {
            guard self.maskProvider == nil else { return }

            self.lostFocusSlots = MaskSlot.parse(self.maskLostFocus)
            self.setTextAndCursor()
        }
    }

    public var maskMode: MaskMode = .fullMask {
        didSet {
            self.setTextAndCursor()
        }
    }

    public var cursorBehavior: CursorBehavior = .free {
        didSet {
            self.setTextAndCursor()
        }
    }

    public var hiddenMaskIfEnteredTextEmpty: Bool = false {
        didSet {
            self.setTextAndCursor()
        }
    }

    // MARK: - entered state

    /// Символ подходит позиции по её типу и проходит `CharValidator` поля (если задан).
    private func accepts(_ char: Character, in slot: MaskSlot) -> Bool {
        slot.accepts(char) && (self.control?.check(char: char) ?? true)
    }

    private func setEntered(_ char: Character?, at index: Int) {
        self.entered[index] = char
        self.hidden[index] = false

        if char != nil && self.hideChars {
            self.restartHideTimer()
        }
    }

    /// Вставляет символ в первую пустую вводимую позицию, начиная с `offset`; если справа
    /// от `offset` свободных позиций нет — в первую пустую позицию слева (так маску можно
    /// добить вводом с конца). Возвращает индекс позиции либо `nil`, если позиции нет
    /// или символ ей не подходит.
    private func insert(char: Character, at offset: Int) -> Int? {
        let start = min(max(offset, 0), self.slots.count)

        let target = self.firstFreeIndex(in: start..<self.slots.count)
            ?? self.firstFreeIndex(in: 0..<start)

        guard let index = target, self.accepts(char, in: self.slots[index]) else { return nil }

        self.setEntered(char, at: index)
        return index
    }

    private func firstFreeIndex(in range: Range<Int>) -> Int? {
        range.first { self.slots[$0].canEntered && self.entered[$0] == nil }
    }

    /// Индекс первой пустой вводимой позиции после `index` (литералы пропускаются).
    /// Возвращает `nil`, если таких позиций нет.
    private func nextEmptyEnteredIndex(after index: Int) -> Int? {
        guard index + 1 < self.slots.count else { return nil }

        return ((index + 1)..<self.slots.count).first {
            self.slots[$0].canEntered && self.entered[$0] == nil
        }
    }

    /// Индекс первой вводимой позиции начиная с `index` (включительно).
    private func firstEnteredIndex(from index: Int) -> Int? {
        guard index < self.slots.count else { return nil }

        return (max(index, 0)..<self.slots.count).first { self.slots[$0].canEntered }
    }

    /// Удаляет последнюю заполненную позицию с индексом не больше `offset`.
    /// Возвращает индекс удалённой позиции либо `nil`, если удалять нечего.
    private func removeLastEntered(before offset: Int) -> Int? {
        var index = min(offset, self.slots.count - 1)
        guard index >= 0 else { return nil }

        while index >= 0 {
            if self.slots[index].canEntered, self.entered[index] != nil {
                self.setEntered(nil, at: index)
                return index
            }
            index -= 1
        }

        return nil
    }

    // MARK: - hide timer

    private func restartHideTimer() {
        self.hideTimer?.invalidate()

        let timer = Timer(timeInterval: MaskTransformer.hideCharDelay, repeats: false) { [weak self] _ in
            self?.hideTimerFired()
        }
        // `.common` — чтобы таймер срабатывал и во время скролла/трекинга.
        RunLoop.main.add(timer, forMode: .common)
        self.hideTimer = timer
    }

    private func cancelHideTimer() {
        self.hideTimer?.invalidate()
        self.hideTimer = nil
    }

    private func hideTimerFired() {
        self.hideTimer = nil
        guard self.hideChars else { return }

        var changed = false
        for index in self.slots.indices where self.entered[index] != nil && !self.hidden[index] {
            self.hidden[index] = true
            changed = true
        }

        if changed {
            // Курсор не трогаем: пользователь мог переставить его, пока шёл таймер.
            // В `.sequential` каноническая позиция вычисляется сама.
            let keepCursor = self.cursorBehavior == .sequential ? nil : self.control?.cursorOffset
            self.setTextAndCursor(cursorPosition: keepCursor)
        }
    }

    // MARK: - rendering

    /// Символ-заглушка для позиции: `maskChar` для вводимой, сам литерал — иначе.
    private func placeholder(for slot: MaskSlot) -> Character {
        slot.canEntered ? self.maskChar : slot.char
    }

    /// Символ, который нужно показать на заполненной позиции, либо `nil`, если она пуста.
    private func displayChar(at index: Int) -> Character? {
        guard let char = self.entered[index] else { return nil }

        if self.hideChars {
            return self.hidden[index] ? self.veiledMaskChar : char
        }

        return (!self.slots[index].veiled || self._isFocus) ? char : self.veiledMaskChar
    }

    /// В режиме пароля скрывает все введённые символы, кроме последнего.
    private func applyHideCharsPolicy() {
        guard self.hideChars,
              let last = self.entered.lastIndex(where: { $0 != nil }) else { return }

        for index in self.slots.indices where self.slots[index].canEntered && index != last {
            self.hidden[index] = true
        }
    }

    private func setTextAndCursor(cursorPosition: Int? = nil) {
        let (text, cursor) = self.renderedTextAndCursor(cursorPosition: cursorPosition)

        guard let control = self.control else { return }

        if self.hiddenMaskIfEnteredTextEmpty && !self._isFocus && self.entered.allSatisfy({ $0 == nil }) {
            control.text = ""
            return
        }

        self.isRendering = true
        defer { self.isRendering = false }
        control.text = text
        control.setCursorPosition(cursor)
    }

    private func renderedTextAndCursor(cursorPosition: Int?) -> (text: String, cursor: Int) {
        self.applyHideCharsPolicy()

        var text: String

        if self._isFocus || self.lostFocusSlots.isEmpty {
            text = String(self.slots.indices.map { index in
                self.displayChar(at: index) ?? self.placeholder(for: self.slots[index])
            })
        } else {
            // Введённые символы последовательно раскладываются по позициям маски «без фокуса».
            var enteredChars = self.slots.indices.compactMap { self.displayChar(at: $0) }.makeIterator()

            text = String(self.lostFocusSlots.map { slot in
                if slot.canEntered, let char = enteredChars.next() {
                    return char
                }
                return self.placeholder(for: slot)
            })
        }

        var cursor = self.slots.count

        if let last = self.slots.lastIndex(where: { $0.canEntered }) {
            cursor = last + 1
        }

        if let first = self.slots.indices.first(where: { self.slots[$0].canEntered && self.entered[$0] == nil }) {
            cursor = first
        }

        // Явная позиция курсора после редактирования (вставка/удаление).
        if let position = cursorPosition {
            cursor = min(max(position, 0), self.slots.count)
        }

        if self.maskMode == .gradualMask {
            text = text.substring(start: 0, length: cursor)
        }

        return (text, cursor)
    }
}

// MARK: - Динамические маски

/// Динамический режим хранит значение как последовательность символов («сырое» значение):
/// после каждой правки провайдер выбирает маску под новое значение, а символы заново
/// раскладываются по её позициям подряд (без пропусков).
extension MaskTransformer {
    private struct Snapshot {
        let slots: [MaskSlot]
        let lostFocusSlots: [MaskSlot]
        let entered: [Character?]
        let hidden: [Bool]
        let onlyEnteredCount: Int
        let variant: MaskVariant?
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            slots: self.slots,
            lostFocusSlots: self.lostFocusSlots,
            entered: self.entered,
            hidden: self.hidden,
            onlyEnteredCount: self._onlyEnteredCount,
            variant: self.activeVariant
        )
    }

    private func restore(_ snapshot: Snapshot) {
        self.slots = snapshot.slots
        self.lostFocusSlots = snapshot.lostFocusSlots
        self.entered = snapshot.entered
        self.hidden = snapshot.hidden
        self._onlyEnteredCount = snapshot.onlyEnteredCount
        self.activeVariant = snapshot.variant
    }

    private var rawChars: [Character] {
        self.entered.compactMap { $0 }
    }

    /// Сколько символов введено в позициях до `slotIndex` (не включая его).
    private func enteredCount(before slotIndex: Int) -> Int {
        self.entered.prefix(max(slotIndex, 0)).reduce(0) { $0 + ($1 == nil ? 0 : 1) }
    }

    /// Выбирает маску под `raw` и раскладывает символы по её позициям. Возвращает индексы
    /// заполненных позиций по порядку (символы, не подошедшие позициям, пропускаются).
    @discardableResult
    private func resolve(_ raw: [Character]) -> [Int] {
        guard let provider = self.maskProvider else { return [] }

        let variant = provider(String(raw))
        if self.activeVariant != variant {
            self.slots = MaskSlot.parse(variant.mask)
            self.lostFocusSlots = MaskSlot.parse(variant.maskLostFocus)
            self.entered = Array(repeating: nil, count: self.slots.count)
            self.hidden = Array(repeating: false, count: self.slots.count)
            self._onlyEnteredCount = self.slots.filter { $0.canEntered }.count
            self.cancelHideTimer()
            self.activeVariant = variant
        }

        return self.fill(with: String(raw))
    }

    /// Символы, которые вместе дают значение, помещающееся в выбранную маску.
    private func acceptedChars(of raw: [Character]) -> [Character] {
        let filled = self.resolve(raw)
        return filled.compactMap { self.entered[$0] }
    }

    func dynamicSetText(_ value: String) {
        // Два прохода: первый выбирает маску по длине, второй — по реально подошедшим символам.
        let accepted = self.acceptedChars(of: Array(value))
        self.resolve(accepted)
    }

    func dynamicInsert(_ char: Character, at offset: Int) -> Bool {
        let before = self.snapshot()
        let raw = self.rawChars

        let rawIndex: Int
        if self.cursorBehavior == .sequential {
            rawIndex = raw.count
        } else {
            rawIndex = self.enteredCount(before: min(max(offset, 0), self.slots.count))
        }

        var newRaw = raw
        newRaw.insert(char, at: rawIndex)

        let filled = self.resolve(newRaw)
        guard filled.count == newRaw.count else {
            self.restore(before)
            return false
        }

        let cursor = self.firstEnteredIndex(from: filled[rawIndex] + 1) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)
        return true
    }

    func dynamicDelete(at offset: Int) {
        let raw = self.rawChars
        guard !raw.isEmpty else { return }

        let rawIndex: Int
        if self.cursorBehavior == .sequential {
            rawIndex = raw.count - 1
        } else {
            var index = min(offset, self.slots.count - 1)
            while index >= 0, self.entered[index] == nil { index -= 1 }
            guard index >= 0 else { return }
            rawIndex = self.enteredCount(before: index)
        }

        var newRaw = raw
        newRaw.remove(at: rawIndex)

        let filled = self.resolve(newRaw)
        let anchor = rawIndex > 0 && rawIndex <= filled.count ? filled[rawIndex - 1] + 1 : 0
        let cursor = self.firstEnteredIndex(from: anchor) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)
    }

    func dynamicPaste(_ text: String, in range: Range<Int>) {
        var lower = min(max(range.lowerBound, 0), self.slots.count)
        var upper = min(max(range.upperBound, lower), self.slots.count)

        if self.cursorBehavior == .sequential {
            lower = range.isEmpty ? self.slots.count : lower
            upper = self.slots.count
        }

        let raw = self.rawChars
        let rawLower = self.enteredCount(before: lower)
        let rawUpper = self.enteredCount(before: upper)
        let prefix = Array(raw[..<rawLower])
        let suffix = Array(raw[rawUpper...])
        let pasted = Array(text)

        // Проход 1: маска под полную длину; из вставки остаются только подходящие символы.
        self.resolve(prefix + pasted + suffix)
        var accepted = pasted.filter { char in
            self.slots.contains { $0.canEntered && self.accepts(char, in: $0) }
        }

        // Как и без динамики: вставка, не помещающаяся в пустое поле, — последние символы.
        if prefix.isEmpty, suffix.isEmpty, accepted.count > self.onlyEnteredCount {
            accepted = Array(accepted.suffix(self.onlyEnteredCount))
        }

        // Проход 2: окончательная маска и раскладка.
        let filled = self.resolve(prefix + accepted + suffix)

        let insertedCount = prefix.count + accepted.count
        let anchor = insertedCount > 0 && insertedCount <= filled.count ? filled[insertedCount - 1] + 1 : 0
        let cursor = self.firstEnteredIndex(from: anchor) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)
    }
}
