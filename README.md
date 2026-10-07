# MaskTextField

A maskable `UITextField` for iOS, distributed as a Swift Package.

The library lets you apply an input mask (phone, date, card number, etc.),
read the raw value without the mask, veil entered characters on focus loss,
and customize how the mask is displayed (full or gradual).

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Via Xcode

1. `File ▸ Add Package Dependencies…`
2. Paste the repository URL (or pick a local folder via `Add Local…`).
3. Select the `MaskTextField` product.

### Via `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/<your>/MaskTextField.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: ["MaskTextField"]
    )
]
```

For local development you can reference a path:

```swift
.package(path: "../MaskTextField")
```

## Quick start

```swift
import MaskTextField

let field = ICMaskTextField()

// Mask shown while editing
field.maskText = "+375 (dd) ddd-dd-dd"

// Mask shown when the field loses focus (characters are veiled)
field.maskLostFocus = "+375 (^d^d) ^d^d^d-^d^d-^d^d"

// Raw value without the mask (read and write)
field.textValue = "291234567"
print(field.textValue) // "291234567"
```

While editing, the field shows `+375 (29) 123-45-67`; after losing focus it shows
`+375 (••) •••-••-••`.

## Mask syntax

A mask is a string where special characters define editable positions and all
other characters are printed as literals.

| Character | Meaning                                               | Regex                             |
|-----------|-------------------------------------------------------|-----------------------------------|
| `d`       | digit                                                 | `[0-9]`                           |
| `a`       | letter                                                | `[a-zA-Z]`                        |
| `A`       | letter or digit                                       | `[a-zA-Z0-9]`                     |
| `x`       | any character                                         | `[a-zA-Z!@#$%^&*()_\-+={};:<>|./?.]` |
| `X`       | any character or digit                                | `[a-zA-Z0-9!@#$%^&*()_\-+={};:<>|./?.]` |
| `z`       | any character (no validation)                         | —                                 |
| `\c`      | escaped literal (even if `c` is a special character)  | —                                 |
| `^c`      | editable position veiled on focus loss                | —                                 |

Examples:

| Mask                  | Input          | Display            |
|-----------------------|----------------|--------------------|
| `+375 (dd) ddd-dd-dd` | `291234567`    | `+375 (29) 123-45-67` |
| `dd/dd/dddd`          | `07102026`     | `07/10/2026`       |
| `dddd dddd dddd dddd` | `4111111111111111` | `4111 1111 1111 1111` |
| `\dA`                 | `X7`           | `d7` (`\d` is a literal `d`) |

## Key `ICMaskTextField` properties

| Property | Type | Description |
|----------|------|-------------|
| `maskText` | `String` | Mask used while editing |
| `maskLostFocus` | `String` | Mask used when the field loses focus |
| `maskChar` | `Character` | Placeholder character (`_` by default) |
| `veiledMaskChar` | `Character` | Character that veils entered characters (`•` by default) |
| `maskMode` | `ICMaskMode` | `.fullMask` or `.gradualMask` |
| `hideChars` | `Bool` | Password mode (characters are veiled after a delay) |
| `hiddenMaskIfEnteredTextEmpty` | `Bool` | Hide the mask when the value is empty and the field is not focused |
| `textValue` | `String?` | Raw value without the mask (read/write) |
| `onlyEnteredCount` | `Int` | Number of editable positions |
| `visibleTextMask` | `String` | The mask being displayed |
| `charValidator` | `ICCharValidator?` | Additional input restrictions |

Combine publishers: `textPublisher`, `deleteBackwardPublisher`,
`clearButtonPublisher`.

## Custom character validator

```swift
final class DecimalValidator: ICCharValidator {
    var culture: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    func check(char: Character) -> Bool { char.isNumber || char == "." || char == "," }
    func check(string: String) -> Bool { true }
    func correct(string: String) -> String { string }
}

let field = ICMaskTextField()
field.charValidator = DecimalValidator()
field.maskText = "d.dd"
```

## Architecture

Input is processed by a chain of transformers (`ICBaseTransformer` →
`ICFilterTransformer` → `ICMaskTransformer`):

- `ICBaseTransformer` — a plain, unmasked field;
- `ICFilterTransformer` — character filtering and decimal separator normalization;
- `ICMaskTransformer` — mask application, character veiling, display modes.

The logic works through the `ICMaskTextFieldProtocol`, so the transformers can be
tested without a real `UITextField`.

## Example app

A ready-to-run SwiftUI example lives in `Example/MaskTextFieldExample/`. Open
`MaskTextFieldExample.xcodeproj` in Xcode and run the scheme on an iOS simulator.
The project already references the local package (`relativePath = ../..`).

## Tests

```sh
xcodebuild -scheme MaskTextField \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Tests cover mask rendering, input/deletion, rejection of invalid characters,
display modes, and character veiling on focus loss.
