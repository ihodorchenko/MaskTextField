import Foundation

/// The cursor behavior when editing a masked value.
public enum CursorBehavior {
    /// The cursor can be placed anywhere; input and deletion happen at the cursor position.
    case free

    /// When the field gains focus, the cursor snaps to the first free position (even if the tap
    /// landed elsewhere), after which it can be moved freely, as in `.free`.
    case snapOnFocus

    /// The cursor always sits on the first free input position. Input and erasing are
    /// strictly sequential (append at the end, erase from the end); the cursor
    /// cannot be placed arbitrarily. A selection is treated as "from its start to the end":
    /// pasting over a selection drops the value to the right of it.
    case sequential
}
