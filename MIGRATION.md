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
