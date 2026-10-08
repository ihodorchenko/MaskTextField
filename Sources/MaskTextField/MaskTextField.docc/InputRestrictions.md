# Restricting input

Use ``MaskTextField/charValidator`` to restrict which characters can be typed, pasted or set
through ``MaskTextField/textValue``.

## Overview

It works in a plain field (for example, forbidding emoji) and in a masked field, where it is an
extra restriction on top of the mask character types. The field holds the validator strongly,
so it can be created inline:

```swift
field.charValidator = EmojiFreeValidator()
```

Built-in validators: ``EmojiFreeValidator``, ``AllowedCharactersValidator``,
``MaxLengthValidator`` and ``CompositeValidator``. A custom validator overrides only what it
needs, because all ``CharValidator`` methods have default implementations:

```swift
final class NoDigitsValidator: CharValidator {
    func check(char: Character) -> Bool { !char.isNumber }
}
```

### How it is applied

In a plain field typed or pasted characters go through ``CharValidator/check(char:)``, the
remaining string through ``CharValidator/correct(string:)``, and the resulting text through
``CharValidator/check(string:)`` (for example a length limit; a failing change is rejected as a
whole). Input that passes unchanged is handled natively by UIKit; if the filter changed it, the
filtered text is inserted at the selection. During IME composition the field does not
intervene. In a masked field only `check(char:)` and `correct(string:)` are used.

### Keyboard suggestions

Masked fields disable autocorrection and smart substitutions by default
(``MaskTextField/disablesAutocorrection``), so card numbers, PINs and codes do not end up in
keyboard suggestions. For one-time codes set `textContentType = .oneTimeCode`; the autofilled
code arrives as a single replacement and is applied through the paste path.
