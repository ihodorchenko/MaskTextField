# Dynamic masks

Let the mask follow the value, for example a card number: 15 digits for American Express
(starts with 34 or 37), 16 otherwise.

## Overview

Set ``MaskTextField/maskProvider`` to a function from the raw value to a ``MaskVariant``:

```swift
field.maskProvider = MaskPreset.cardProvider
```

Or list variants and let the field pick the first one the value fits into
(``MaskTextField/maskVariants``, ascending capacity):

```swift
field.maskVariants = [MaskVariant("(dd) ddd"), MaskVariant("(dd) ddd-dd")]
```

After every edit the provider picks a mask for the new raw value and the characters are laid
out over its positions in order.

### Rules

- The provider must be a pure function; it is called on every change.
- While a provider is set, ``MaskTextField/maskText`` and ``MaskTextField/maskLostFocus`` are
  ignored; a ``MaskVariant`` carries its own unfocused mask.
- The value stays compact: there are no gaps between entered characters, unlike a static mask
  in ``CursorBehavior/free`` mode.
- Input that fits no mask, or a character invalid for its position, is rejected as a whole.
- Pasting more than the largest mask holds into an empty field keeps the last characters.

### SwiftUI

`MaskedTextField(maskVariants:)` takes capacity-ordered variants. `MaskedTextField(maskProvider:)`
takes a provider that is applied once when the field is created; recreate the view with
`.id(...)` to change it.
