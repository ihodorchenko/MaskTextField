import Foundation

// MARK: - Dynamic masks

/// The dynamic mode stores the value as a sequence of characters (the "raw" value):
/// after every edit the provider picks a mask for the new value, and the characters
/// are laid out over its positions again, in order (without gaps).
extension MaskTransformer {
    private struct Snapshot {
        let slots: [MaskSlot]
        let lostFocusSlots: [MaskSlot]
        let entered: [Character?]
        let hidden: [Bool]
        let capacity: Int
        let variant: MaskVariant?
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            slots: self.slots,
            lostFocusSlots: self.lostFocusSlots,
            entered: self.entered,
            hidden: self.hidden,
            capacity: self._capacity,
            variant: self.activeVariant
        )
    }

    private func restore(_ snapshot: Snapshot) {
        self.slots = snapshot.slots
        self.lostFocusSlots = snapshot.lostFocusSlots
        self.entered = snapshot.entered
        self.hidden = snapshot.hidden
        self._capacity = snapshot.capacity
        self.activeVariant = snapshot.variant
    }

    private var rawChars: [Character] {
        self.entered.compactMap { $0 }
    }

    /// How many characters are entered in the positions before `slotIndex` (not including it).
    private func enteredCount(before slotIndex: Int) -> Int {
        self.entered.prefix(max(slotIndex, 0)).reduce(0) { $0 + ($1 == nil ? 0 : 1) }
    }

    /// Picks a mask for `raw` and lays the characters out over its positions. Returns the indices
    /// of the filled positions in order (characters that do not fit a position are skipped).
    @discardableResult
    private func resolve(_ raw: [Character]) -> [Int] {
        guard let provider = self.maskProvider else { return [] }

        let variant = provider(String(raw))
        if self.activeVariant != variant {
            self.slots = MaskSlot.parse(variant.mask)
            self.lostFocusSlots = MaskSlot.parse(variant.maskLostFocus)
            self.entered = Array(repeating: nil, count: self.slots.count)
            self.hidden = Array(repeating: false, count: self.slots.count)
            self._capacity = self.slots.filter { $0.canEntered }.count
            self.cancelHideTimer()
            self.activeVariant = variant
        }

        return self.fill(with: String(raw))
    }

    /// The characters that together form a value that fits the chosen mask.
    private func acceptedChars(of raw: [Character]) -> [Character] {
        let filled = self.resolve(raw)
        return filled.compactMap { self.entered[$0] }
    }

    func dynamicSetText(_ value: String) {
        // Two passes: the first picks a mask by length, the second by the characters that actually fit.
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

        // Pass 1: the mask for the full length; only the fitting characters of the paste are kept.
        self.resolve(prefix + pasted + suffix)
        var accepted = pasted.filter { char in
            self.slots.contains { $0.canEntered && self.accepts(char, in: $0) }
        }

        // As without dynamic masks: a paste that does not fit an empty field keeps the last characters.
        if prefix.isEmpty, suffix.isEmpty, accepted.count > self.capacity {
            accepted = Array(accepted.suffix(self.capacity))
        }

        // Pass 2: the final mask and layout.
        let filled = self.resolve(prefix + accepted + suffix)

        let insertedCount = prefix.count + accepted.count
        let anchor = insertedCount > 0 && insertedCount <= filled.count ? filled[insertedCount - 1] + 1 : 0
        let cursor = self.firstEnteredIndex(from: anchor) ?? self.slots.count
        self.setTextAndCursor(cursorPosition: cursor)
    }
}
