# ``MaskTextField``

A maskable `UITextField` for iOS: input masks, raw values, dynamic masks, cursor behavior,
input restrictions and accessibility.

## Overview

`MaskTextField` applies a mask such as `+375 (dd) ddd-dd-dd` to what the user types, while
giving you the raw value without the mask. The same engine supports dynamic masks (for example
card numbers), password-style veiling, strictly sequential input and character restrictions.

```swift
import MaskTextField

let field = MaskTextField()
field.maskText = "+375 (dd) ddd-dd-dd"
field.maskLostFocus = "+375 (^d^d) ^d^d^d-^d^d-^d^d"   // veils digits when focus is lost

field.textValue = "291234567"
print(field.text!)       // "+375 (29) 123-45-67"
print(field.textValue!)  // "291234567"
```

The SwiftUI wrapper `MaskedTextField` lives in the separate `MaskTextFieldSwiftUI` module.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:MaskSyntax>
- ``MaskTextField/MaskTextField``

### Configuring masks

- ``MaskConfiguration``
- ``MaskPreset``
- ``MaskMode``
- <doc:DynamicMasks>
- ``MaskVariant``

### Editing behavior

- <doc:CursorBehaviorGuide>
- ``CursorBehavior``
- <doc:InputRestrictions>
- ``CharValidator``
- ``EmojiFreeValidator``
- ``AllowedCharactersValidator``
- ``MaxLengthValidator``
- ``CompositeValidator``

### Accessibility and localization

- <doc:Accessibility>

### Transformers

- ``MaskTransformer``
- ``BaseTransformer``
- ``FilterTransformer``
- ``MaskTextFieldProtocol``

### Utilities

- ``ResponderStandardEditActions``
