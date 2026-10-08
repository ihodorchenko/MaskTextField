import Foundation

/// A transformer that applies a mask to the entered text.
///
/// A mask is a string in which special characters define the editable positions:
/// - `d` — a digit `[0-9]`
/// - `a` — a Latin letter `[a-zA-Z]`
/// - `A` — a Latin letter or a digit
/// - `x` — any visible ASCII character except a digit
/// - `X` — any visible ASCII character, digits included
/// - `z` — any character, without validation
/// - `\c` — an escaped character (a literal, even if it matches a special character)
/// - `^c` — an editable position whose value is veiled when the field loses focus
///
/// All other characters are literals and are output as is.
///
/// The mask template (`MaskSlot`) is immutable; entered values and veiling flags
/// are stored separately, in arrays indexed like the mask positions.

@MainActor
public final class MaskTransformer: BaseTransformer {
    public static let hideChar: Character = MaskConfiguration.defaultVeiledMaskChar
    public static let defaultMaskChar: Character = MaskConfiguration.defaultMaskChar

    /// The delay before the last entered character is veiled in `hideChars` mode.
    public static let hideCharDelay: TimeInterval = 1.5

    var slots: [MaskSlot] = []
    var lostFocusSlots: [MaskSlot] = []

    /// Entered values by `slots` index; `nil` means the position is empty (or a literal).
    var entered: [Character?] = []

    /// The "hidden" flag by `slots` index (`hideChars` mode).
    var hidden: [Bool] = []

    /// Owns the hide timer and invalidates it when the transformer is released (a nonisolated
    /// `deinit` cannot touch the main-actor state of the transformer itself).
    private let hideTimerHolder = HideTimerHolder()

    private var hideTimer: Timer? {
        get { self.hideTimerHolder.timer }
        set { self.hideTimerHolder.timer = newValue }
    }

    /// Bumped whenever the timer is restarted or cancelled, so a firing that was already
    /// queued for an outdated timer is ignored.
    private var hideTimerGeneration = 0

    /// The time during which the first selection after gaining focus is treated as the
    /// cursor placed by a tap and is replaced with a jump to the first free position
    /// (`.snapOnFocus`).
    var focusSnapWindow: TimeInterval = 0.5

    /// The moment (`systemUptime`) until which cursor snapping after focus is active.
    private var focusSnapDeadline: TimeInterval?

    private var _isFocus: Bool = false

    /// A flag saying that `setTextAndCursor` is currently changing the text/cursor itself.
    /// Prevents recursion: `setCursorPosition` → `textFieldDidChangeSelection` →
    /// `onSelectionChanged` → `setTextAndCursor` → …
    private var isRendering: Bool = false

    // MARK: - Filter Transformer

    var _capacity: Int = 0

    public override var capacity: Int {
        self._capacity
    }

    /// Whether all editable positions are filled (a mask without editable positions is never complete).
    public override var isComplete: Bool {
        self._capacity > 0
            && self.slots.indices.allSatisfy { !self.slots[$0].canEntered || self.entered[$0] != nil }
    }

    /// Normalizes a pasted string: keeps only the characters allowed
    /// at the editable positions and trims to their number (the last characters
    /// are kept on paste).
    public override func normalizedValue(from value: String) -> String {
        let enteredSlots = self.slots.filter { $0.canEntered }
        guard !enteredSlots.isEmpty else { return "" }

        let filtered = value.filter { char in
            enteredSlots.contains { self.accepts(char, in: $0) }
        }

        let count = self.capacity
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

    /// Distributes a raw value (without the mask) over the editable positions.
    ///
    /// Each position takes the next character accepted by `accepts`;
    /// unsuitable characters are skipped. If no suitable characters are left,
    /// the position stays empty. Returns the indices of the filled positions in order.
    @discardableResult
    func fill(with value: String) -> [Int] {
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

    /// The VoiceOver description of the value: without mask placeholders and hidden characters.
    ///
    /// An empty field is described as "Empty"; if characters are hidden (`hideChars`, or `^` while
    /// unfocused), only the number of entered characters is announced.
    public var accessibilityDescription: String {
        let chars = self.entered.compactMap { $0 }
        guard !chars.isEmpty else { return L10n.string("a11y.empty") }

        let hasVeiled = !self._isFocus && zip(self.slots, self.entered).contains { $0.veiled && $1 != nil }
        if self.hideChars || hasVeiled {
            return L10n.enteredCount(chars.count, of: self.capacity)
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

        // The cursor goes to the next empty editable position; literals are skipped.
        let cursor = self.nextEmptyEnteredIndex(after: index) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)

        return true
    }

    /// Replaces the `range` (in mask positions) with the string `text`.
    ///
    /// Characters outside the range are kept and shifted, so pasting into the middle
    /// does not overwrite the rest of the value, and replacing a selection removes the selected part.
    /// The `text` string is normalized first (`normalizedValue(from:)`).
    public override func onPaste(_ text: String, in range: Range<Int>) {
        if self.maskProvider != nil {
            self.dynamicPaste(text, in: range)
            return
        }

        var lower = min(max(range.lowerBound, 0), self.slots.count)
        var upper = min(max(range.upperBound, lower), self.slots.count)

        if self.cursorBehavior == .sequential {
            // Appends only: an empty range is an append, a selection means "to the end".
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
        let combined = String((prefix + pasted + suffix).prefix(self.capacity))
        let filled = self.fill(with: combined)

        // The cursor goes right after the last inserted character (literals are skipped).
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
            // Once: the selection UIKit sets on the tap right after focus.
            self.focusSnapDeadline = nil
            if ProcessInfo.processInfo.systemUptime <= deadline {
                self.setTextAndCursor()
                return
            }
        }

        if self.cursorBehavior == .sequential {
            // An arbitrary cursor is not allowed: return it to the first free position.
            self.setTextAndCursor()
            return
        }

        // Keep the current cursor position (the user may have moved it)
        // instead of bouncing to the first empty editable position.
        self.setTextAndCursor(cursorPosition: self.control?.cursorOffset)
    }

    public override func onGotFocus() {
        self._isFocus = true
        self.focusSnapDeadline = self.cursorBehavior == .snapOnFocus
            ? ProcessInfo.processInfo.systemUptime + self.focusSnapWindow
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

    /// Dynamic masks: returns a mask variant for the current raw value.
    /// While the provider is set, the `mask` and `maskLostFocus` properties are not used.
    /// The provider is called on every change and must be a pure function.
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
                self._capacity = self.slots.filter { $0.canEntered }.count
            }
            self.setTextAndCursor()
        }
    }

    /// The variant currently chosen by the provider (`nil` without dynamic masks).
    var activeVariant: MaskVariant?

    public var mask: String = "" {
        didSet {
            guard self.maskProvider == nil else { return }

            self.slots = MaskSlot.parse(self.mask)
            self.entered = Array(repeating: nil, count: self.slots.count)
            self.hidden = Array(repeating: false, count: self.slots.count)
            self._capacity = self.slots.filter { $0.canEntered }.count
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

    /// The character fits the position by its type and passes the field's `CharValidator` (if set).
    func accepts(_ char: Character, in slot: MaskSlot) -> Bool {
        slot.accepts(char) && (self.control?.check(char: char) ?? true)
    }

    private func setEntered(_ char: Character?, at index: Int) {
        self.entered[index] = char
        self.hidden[index] = false

        if char != nil && self.hideChars {
            self.restartHideTimer()
        }
    }

    /// Inserts a character into the first empty editable position starting at `offset`; if there
    /// is no free position to the right of `offset`, into the first empty position on the left
    /// (so a mask can be completed by typing at the end). Returns the position index, or `nil`
    /// if there is no position or the character does not fit it.
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

    /// The index of the first empty editable position after `index` (literals are skipped).
    /// Returns `nil` if there is none.
    private func nextEmptyEnteredIndex(after index: Int) -> Int? {
        guard index + 1 < self.slots.count else { return nil }

        return ((index + 1)..<self.slots.count).first {
            self.slots[$0].canEntered && self.entered[$0] == nil
        }
    }

    /// The index of the first editable position starting at `index` (inclusive).
    func firstEnteredIndex(from index: Int) -> Int? {
        guard index < self.slots.count else { return nil }

        return (max(index, 0)..<self.slots.count).first { self.slots[$0].canEntered }
    }

    /// Removes the last filled position with an index not greater than `offset`.
    /// Returns the index of the removed position, or `nil` if there is nothing to remove.
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

        self.hideTimerGeneration += 1
        let generation = self.hideTimerGeneration

        // A target/selector timer calls back synchronously on the main thread (no `@Sendable`
        // block and no hop through the actor executor), and its target holds the transformer weakly.
        let target = HideTimerTarget(self, generation: generation)
        let timer = Timer(
            timeInterval: MaskTransformer.hideCharDelay,
            target: target,
            selector: #selector(HideTimerTarget.fire),
            userInfo: nil,
            repeats: false
        )
        // `.common` so the timer also fires during scrolling/tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.hideTimer = timer
    }

    func cancelHideTimer() {
        self.hideTimerGeneration += 1
        self.hideTimer?.invalidate()
        self.hideTimer = nil
    }

    fileprivate func hideTimerFired(generation: Int) {
        // A firing from an outdated timer (restarted or cancelled since) is ignored.
        guard generation == self.hideTimerGeneration else { return }

        self.hideTimer = nil
        guard self.hideChars else { return }

        var changed = false
        for index in self.slots.indices where self.entered[index] != nil && !self.hidden[index] {
            self.hidden[index] = true
            changed = true
        }

        if changed {
            // Leave the cursor alone: the user may have moved it while the timer ran.
            // In `.sequential` the canonical position is computed anyway.
            let keepCursor = self.cursorBehavior == .sequential ? nil : self.control?.cursorOffset
            self.setTextAndCursor(cursorPosition: keepCursor)
        }
    }

    // MARK: - rendering

    /// The placeholder character for a position: `maskChar` for an editable one, the literal itself otherwise.
    private func placeholder(for slot: MaskSlot) -> Character {
        slot.canEntered ? self.maskChar : slot.char
    }

    /// The character to show at a filled position, or `nil` if it is empty.
    private func displayChar(at index: Int) -> Character? {
        guard let char = self.entered[index] else { return nil }

        if self.hideChars {
            return self.hidden[index] ? self.veiledMaskChar : char
        }

        return (!self.slots[index].veiled || self._isFocus) ? char : self.veiledMaskChar
    }

    /// In password mode, veils all entered characters except the last one.
    private func applyHideCharsPolicy() {
        guard self.hideChars,
              let last = self.entered.lastIndex(where: { $0 != nil }) else { return }

        for index in self.slots.indices where self.slots[index].canEntered && index != last {
            self.hidden[index] = true
        }
    }

    func setTextAndCursor(cursorPosition: Int? = nil) {
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
            // Entered characters are laid out in order over the positions of the lost-focus mask.
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

        // An explicit cursor position after editing (paste/delete).
        if let position = cursorPosition {
            cursor = min(max(position, 0), self.slots.count)
        }

        if self.maskMode == .gradualMask {
            text = text.substring(start: 0, length: cursor)
        }

        return (text, cursor)
    }
}

/// The target of the hide timer: a selector-based callback runs synchronously on the main
/// thread, where the timer is scheduled, and holds the transformer weakly.
@MainActor
private final class HideTimerTarget: NSObject {
    private weak var transformer: MaskTransformer?
    private let generation: Int

    init(_ transformer: MaskTransformer, generation: Int) {
        self.transformer = transformer
        self.generation = generation
    }

    @objc func fire() {
        self.transformer?.hideTimerFired(generation: self.generation)
    }
}

/// Holds the hide timer and invalidates it on release. The timer is scheduled on the main run
/// loop, and transformers are released on the main thread like the fields that own them.
private final class HideTimerHolder: @unchecked Sendable {
    var timer: Timer?

    deinit {
        self.timer?.invalidate()
    }
}
