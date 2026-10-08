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
    .package(url: "https://github.com/ihodorchenko/MaskTextField.git", from: "1.0.0")
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

let field = MaskTextField()

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

## SwiftUI

The `MaskTextFieldSwiftUI` product provides a ready-to-use `MaskedTextField`
view for SwiftUI:

```swift
import SwiftUI
import MaskTextFieldSwiftUI

struct MyView: View {
    @State private var phone = ""

    var body: some View {
        MaskedTextField(
            mask: "+375 (dd) ddd-dd-dd",
            maskLostFocus: "+375 (^d^d) ^d^d^d-^d^d-^d^d",
            keyboardType: .numberPad,
            textValue: $phone
        )
    }
}
```

Optional parameters: `font`, `textColor`, `textAlignment`, `returnKeyType`,
`clearButtonMode`, `isFocused: Binding<Bool>?` (read and drive focus) and
`onCommit` (Return key).

```swift
MaskedTextField(mask: "dd/dd/dddd", isFocused: $isDateFocused, onCommit: { submit() }, textValue: $date)
```

Add the `MaskTextFieldSwiftUI` product to your target in Xcode, or via
`.product(name: "MaskTextFieldSwiftUI", package: "MaskTextField")` in `Package.swift`.

## Mask syntax

A mask is a string where special characters define editable positions and all
other characters are printed as literals.

| Character | Meaning                                               | Accepts                           |
|-----------|-------------------------------------------------------|-----------------------------------|
| `d`       | digit (ASCII)                                         | `[0-9]`                           |
| `a`       | Latin letter                                          | `[a-zA-Z]`                        |
| `A`       | letter or digit                                       | `[a-zA-Z0-9]`                     |
| `x`       | any visible ASCII character except a digit            | letters and punctuation/symbols   |
| `X`       | any visible ASCII character, digits included          | letters, digits, punctuation      |
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

## Key `MaskTextField` properties

| Property | Type | Description |
|----------|------|-------------|
| `maskText` | `String` | Mask used while editing |
| `maskLostFocus` | `String` | Mask used when the field loses focus |
| `maskChar` | `Character` | Placeholder character (`_` by default) |
| `veiledMaskChar` | `Character` | Character that veils entered characters (`•` by default) |
| `maskMode` | `MaskMode` | `.fullMask` or `.gradualMask` |
| `hideChars` | `Bool` | Password mode (characters are veiled after a delay) |
| `hiddenMaskIfEnteredTextEmpty` | `Bool` | Hide the mask when the value is empty and the field is not focused |
| `textValue` | `String?` | Raw value without the mask (read/write) |
| `onlyEnteredCount` | `Int` | Number of editable positions |
| `visibleTextMask` | `String` | The mask being displayed |
| `charValidator` | `CharValidator?` | Additional input restrictions |

Pasting and editing: pasted text is filtered to the characters the mask accepts.
Pasting into the middle of a value keeps the surrounding characters (the tail
shifts right), and typing, pasting or deleting over a selection replaces only the
selected part.

Combine publishers: `textPublisher`, `deleteBackwardPublisher`,
`clearButtonPublisher`.

## Custom character validator

```swift
final class DecimalValidator: CharValidator {
    var culture: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    func check(char: Character) -> Bool { char.isNumber || char == "." || char == "," }
    func check(string: String) -> Bool { true }
    func correct(string: String) -> String { string }
}

let field = MaskTextField()
field.charValidator = DecimalValidator()
field.maskText = "d.dd"
```

## Architecture

Input is processed by a chain of transformers (`BaseTransformer` →
`FilterTransformer` → `MaskTransformer`):

- `BaseTransformer` — a plain, unmasked field;
- `FilterTransformer` — character filtering and decimal separator normalization;
- `MaskTransformer` — mask application, character veiling, display modes.

The mask itself is parsed once into immutable `MaskSlot`s; entered characters and
veiling flags live in the transformer next to them, with a single hide timer for
password mode.

The logic works through the `MaskTextFieldProtocol`, so the transformers can be
tested without a real `UITextField`.

## Example app

A ready-to-run SwiftUI example lives in `Example/MaskTextFieldExample/`. Open
`MaskTextFieldExample.xcodeproj` in Xcode and run the scheme on an iOS simulator.
The project already references the local package (`relativePath = ../..`).

## Tests

Package-level tests (transformer logic and the real `MaskTextField`, no host app needed):

```sh
xcodebuild -scheme MaskTextField-Package \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Snapshot tests (run inside the example app, they use `swift-snapshot-testing`):

```sh
xcodebuild -project Example/MaskTextFieldExample/MaskTextFieldExample.xcodeproj \
  -scheme MaskTextFieldExample \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

CI (`.github/workflows/ci.yml`) runs the package tests on every push and pull request.

Tests cover mask rendering, input/deletion, rejection of invalid characters,
display modes, character veiling on focus loss, and cursor positioning.
