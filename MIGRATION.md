# Migrating from 2.x to 3.0

3.0 makes the input engine an implementation detail. Nothing about how masks behave changes: if you
only use `MaskTextField`, `MaskedTextField`, `MaskConfiguration`, `MaskVariant`, `MaskPreset` and
the validators, there is nothing to do.

## Removed from the public API

- `BaseTransformer` and `MaskTransformer` (including `MaskTransformer.hideChar`,
  `MaskTransformer.defaultMaskChar` and `MaskTransformer.hideCharDelay`)
- `MaskTextFieldProtocol`

They are `internal` now, so they can change in 3.x minor releases. `MaskTextField` still has
`check(char:)`, `check(string:)`, `correct(string:)`, `setCursorPosition(_:)` and `cursorOffset`.

| 2.x | 3.0 |
|-----|-----|
| `MaskTransformer.defaultMaskChar` | `MaskConfiguration.defaultMaskChar` |
| `MaskTransformer.hideChar` | `MaskConfiguration.defaultVeiledMaskChar` |
| subclassing `BaseTransformer` / `MaskTransformer` | not supported; use `charValidator`, `maskProvider` or `maskVariants` |
| implementing `MaskTextFieldProtocol` to test logic without UIKit | test through `MaskTextField` (it works off-screen, without a window) |

---

# Migrating from 1.x to 2.0

2.0 removes API that did not work or was only kept for compatibility, and tidies up two names.
Nothing here changes how masks behave; each item below is a compile-time change with a one-line
fix.

## Removed

### `locale`, `culture` and `FilterTransformer` (they had no effect)

The decimal-separator normalization they served was never reachable: `MaskTransformer` replaced
the text handling of `FilterTransformer`, so `MaskTextField.locale` and `MaskedTextField(locale:)`
changed nothing. They are removed together with:

- `MaskTextField.locale`
- `MaskedTextField(locale:)` (the SwiftUI initializer parameter and property)
- `CharValidator.culture`
- `MaskTextFieldProtocol.culture`
- `FilterTransformer` (`MaskTransformer` now inherits `BaseTransformer` directly)

| 1.x | 2.0 |
|-----|-----|
| `field.locale = …` | delete the line (it did nothing) |
| `MaskedTextField(…, locale: …)` | delete the argument |
| `var culture: NumberFormatter` in a `CharValidator` | delete it; all `CharValidator` methods have defaults |
| `culture` in a `MaskTextFieldProtocol` implementation | delete it |
| subclassing `FilterTransformer` | subclass `BaseTransformer` |

If you relied on decimal-separator normalization, do it in your own `CharValidator.correct(string:)`.

### `deleteBackwardPublisher` and `clearButtonPublisher`

These `@Published` properties emitted a value immediately on subscription (a phantom "event").
Use the real event publishers, which exist since 1.1.1:

| 1.x | 2.0 |
|-----|-----|
| `field.$deleteBackwardPublisher.sink { … }` | `field.deleteBackwardEvents.sink { … }` |
| `field.$clearButtonPublisher.sink { … }` | `field.clearButtonEvents.sink { … }` |

## Renamed

| 1.x | 2.0 |
|-----|-----|
| `MaskTextField.onlyEnteredCount` | `MaskTextField.capacity` |
| `MaskTransformer.onlyEnteredCount`, `BaseTransformer.onlyEnteredCount` | `capacity` |

## Type changes

### `MaskTextField.textValue` is `String`, not `String?`

It never returned `nil` for a masked field, and the SwiftUI wrapper already used `String`.

| 1.x | 2.0 |
|-----|-----|
| `field.textValue ?? ""` | `field.textValue` |
| `field.textValue!` | `field.textValue` |
| `if let value = field.textValue { … }` | use `field.textValue` directly |
| `field.textValue = nil` | `field.textValue = ""` |

## Already changed in 1.4 (for reference)

`MaskTextFieldProtocol`, `BaseTransformer` and `MaskTransformer` are `@MainActor` since 1.4.0.
