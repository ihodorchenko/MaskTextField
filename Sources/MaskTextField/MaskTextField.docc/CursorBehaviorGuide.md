# Cursor behavior

Choose how the cursor behaves with ``MaskTextField/cursorBehavior``.

## Overview

| Behavior | Description |
|----------|-------------|
| ``CursorBehavior/free`` | The cursor can be placed anywhere; edits happen at the cursor. Typing with no free position to the right fills the first free one on the left. |
| ``CursorBehavior/snapOnFocus`` | The tap that focuses the field puts the cursor on the first free position; afterwards it moves freely. |
| ``CursorBehavior/sequential`` | The cursor always sits on the first free position; input appends and deletion erases from the end. |

In ``CursorBehavior/sequential`` mode a selection is treated as "from its start to the end":
pasting over it drops the value to the right of the selection start.

``CursorBehavior/snapOnFocus`` treats the first selection UIKit applies within a short window
after the field gains focus as the tap placement and replaces it with the first free position.
