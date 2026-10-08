# MaskTextField

A maskable `UITextField` for iOS, distributed as a Swift Package.

The library lets you apply an input mask (phone, date, card number, etc.),
read the raw value without the mask, veil entered characters on focus loss,
and customize how the mask is displayed (full or gradual).

## Documentation

API reference and guides (mask syntax, dynamic masks, cursor behavior, input restrictions,
accessibility) are built with DocC and published on GitHub Pages for every release tag:
<https://ihodorchenko.github.io/MaskTextField/documentation/masktextfield/> (the SwiftUI module:
`/swiftui/documentation/masktextfieldswiftui/`).

Build it locally with Xcode: **Product ▸ Build Documentation**, or

```sh
xcodebuild docbuild -scheme MaskTextField-Package \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/docs
```

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 27 (the toolchain the library is built and tested with)

## Platforms

| Platform | Status |
|----------|--------|
| iOS 15+ | Supported: unit tests, snapshot tests and UI tests. |
| Mac Catalyst | Builds (`ios15.0-macabi`) and the package unit tests pass. The SwiftUI wrapper hosting tests are skipped there because the unhosted test process has no `NSApplication`. |
| visionOS | Builds for the visionOS simulator SDK. Not exercised at runtime (no visionOS simulator runtime was available), so treat it as unverified. |

`Package.swift` declares only iOS; SwiftPM builds Mac Catalyst and visionOS with default deployment targets.

## Installation

### Via Xcode

1. `File ▸ Add Package Dependencies…`
2. Paste the repository URL (or pick a local folder via `Add Local…`).
3. Select the `MaskTextField` product.

### Via `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/ihodorchenko/MaskTextField.git", from: "2.0.0")
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
`onCommit` (Return key), `isComplete: Binding<Bool>?`, `onComplete`, `forcesLeftToRight`, `announcesInputEvents`,
`disablesAutocorrection`, `accessibilityLabelText` and `accessibilityHintText`.

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
| `maskProvider` / `maskVariants` | `((String) -> MaskVariant)?` / `[MaskVariant]` | Dynamic masks (see below) |
| `cursorBehavior` | `CursorBehavior` | `.free` (default), `.snapOnFocus` or `.sequential` |
| `hideChars` | `Bool` | Password mode (characters are veiled after a delay) |
| `hiddenMaskIfEnteredTextEmpty` | `Bool` | Hide the mask when the value is empty and the field is not focused |
| `textValue` | `String` | Raw value without the mask (read/write) |
| `capacity` | `Int` | Number of editable positions |
| `isComplete` | `Bool` | All editable positions are filled (always `false` without a mask) |
| `isCompletePublisher` | `AnyPublisher<Bool, Never>` | Current completion state, then changes (no duplicates) |
| `onComplete` | `(() -> Void)?` | Fires once when the **user** fills the mask (not for programmatic values) |
| `visibleTextMask` | `String` | The mask being displayed |
| `charValidator` | `CharValidator?` | Additional input restrictions |

Cursor behavior: with `.free` (default) the cursor can be placed anywhere and
edits happen at the cursor. With `.snapOnFocus` the first tap that gives the field focus
puts the cursor on the first free position (wherever the tap landed); after that the
cursor moves freely as in `.free`. With `.sequential` the cursor always sits on the first
free position, input and deletion go strictly in order (append / erase from the
end) and the cursor cannot be moved. A selection is treated as "from its start to
the end", so pasting over it drops the value after the selection start.

Pasting and editing: pasted text is filtered to the characters the mask accepts.
Pasting into the middle of a value keeps the surrounding characters (the tail
shifts right), and typing, pasting or deleting over a selection replaces only the
selected part.

Combine publishers: `textPublisher`, `deleteBackwardEvents`, `clearButtonEvents`
(the events do not fire on subscription), `isCompletePublisher`.

## Dynamic masks

The mask can follow the value, for example a card number: 15 digits for American Express
(starts with 34/37), 16 otherwise.

```swift
field.maskProvider = MaskPreset.cardProvider        // raw value -> MaskVariant

// or by capacity (list variants in ascending order): the first one the value fits into
field.maskVariants = [MaskVariant("(dd) ddd"), MaskVariant("(dd) ddd-dd")]
```

After every edit the provider picks a mask for the new raw value and the characters are laid
out on its positions in order. Notes:

- The provider must be a pure function; it is called on every change. While it is set,
  `maskText` / `maskLostFocus` are ignored (a `MaskVariant` carries its own `maskLostFocus`).
- Dynamic masks keep the value compact (no gaps between entered characters, unlike a static
  mask in `.free` mode), and the cursor follows the edited character across mask switches.
- Input that fits no mask (or a character invalid for its position) is rejected as a whole.
  Pasting more than the largest mask holds into an empty field keeps the last characters.
- SwiftUI: `MaskedTextField(maskVariants:)`, or `maskProvider:` (applied once at creation;
  recreate the view with `.id(...)` to change it).

## Presets

`MaskPreset` holds fixed-format masks: `card16`, `cardAmex`, `dateDMY`, `timeHM`,
`otp(length:)`, and `cardProvider` for dynamic card masks. A mask only defines a format, not
validity (`dateDMY` accepts `99/99/9999`). Country-dependent formats (phones, IBAN) are
deliberately not included.

## Atomic configuration

Properties apply one by one, so the order of assignment matters (for example `maskChar`
before `maskText`). `MaskConfiguration` applies everything at once and rebuilds the mask once
(entered value is reset, as on any mask change):

```swift
field.configure {
    $0.mask = "dd/dd/dddd"
    $0.maskChar = "#"
    $0.cursorBehavior = .sequential
}
// or: field.apply(MaskConfiguration(mask: "dd/dd")), field.configuration (read current)
```

## Accessibility and RTL

- **VoiceOver.** `accessibilityValue` returns a meaningful value instead of the
  displayed mask: `Empty` for an empty field, the entered characters without mask
  placeholders (`2 9 1 2 3`), and only the count (`3 of 9 characters entered`)
  when characters are hidden (`hideChars`, or `^` positions while unfocused).
  Set `accessibilityValue` yourself to override it. Use the standard
  `accessibilityLabel` / `accessibilityHint` (e.g. a hint with the expected format).
- **Announcements.** `announcesInputEvents = true` makes VoiceOver announce rejected
  characters and a completed mask (off by default).
- **Dynamic Type.** The default font is `preferredFont(.body)` with
  `adjustsFontForContentSizeCategory` enabled; a custom font must scale itself.
- **RTL.** `forcesLeftToRight` (default `true`) keeps masked values (phones, cards,
  dates) left-to-right in right-to-left interfaces; with `.natural` alignment the
  text is right-aligned there. Set it to `false` for fully mirrored layout. The
  clear button always sits at the end of the line (left in RTL).
- Library strings are localized in English and Russian.

## Keyboard suggestions and autofill

- `disablesAutocorrection` (default `true`) turns off autocorrection, spell checking and
  smart quotes/dashes/insert-delete for masked fields, so card numbers, PINs and codes do not
  end up in keyboard suggestions. Explicitly set `autocorrectionType`, `spellCheckingType`,
  etc. always win; plain (unmasked) fields keep the system defaults.
- `hideChars` only hides characters on screen. It is **not** `isSecureTextEntry` and does not
  protect against screenshots or screen recording.
- One-time codes: set `textContentType = .oneTimeCode`; the autofilled code arrives as a
  single replacement and is applied through the paste path (covered by a unit test). Autofill
  from a real SMS can only be verified on a device and has not been tested there.

## Restricting input (`charValidator`)

`charValidator` restricts which characters can be typed, pasted or set via `textValue`,
in a plain field (no mask) and in a masked one (as an extra restriction on top of the
mask character types). The field keeps a strong reference to the validator, so it can be
created inline.

```swift
let field = MaskTextField()
field.charValidator = EmojiFreeValidator()          // no emoji (ZWJ sequences, flags, keycaps included)
```

Built-in validators: `EmojiFreeValidator`, `AllowedCharactersValidator(allowed:)`,
`MaxLengthValidator(maxLength:)` and `CompositeValidator([...])`.

A custom validator overrides only what it needs (all methods have defaults):

```swift
final class NoDigitsValidator: CharValidator {
    func check(char: Character) -> Bool { !char.isNumber }
}
```

How the methods are applied in a plain field: typed or pasted characters go through
`check(char:)`, the remaining string through `correct(string:)`, and the resulting
text through `check(string:)` (for example a length limit; a failing change is rejected
as a whole). Input that passes unchanged is handled natively by UIKit; if the filter
changed it, the filtered text is inserted at the selection. While an IME composition is
in progress (marked text) the field does not intervene. In a masked field only
`check(char:)` and `correct(string:)` are used.

## Limitations of masked fields

- **Undo/redo.** A masked field rewrites its text itself and rejects the native change
  (`shouldChangeCharactersIn` returns `false`), so UIKit registers nothing in the undo
  stack: shake-to-undo and the keyboard undo/redo do nothing. Plain fields (no mask) keep
  native undo.
- **IME composition.** In a masked field there is no marked-text handling: composing input
  (Chinese, Japanese, Korean) is not supported; use a plain field with a `charValidator`.
- **Selection.** A non-empty selection is collapsed to a cursor when it changes; editing a
  range goes through the paste path (typing or pasting over a selection works).

## Architecture

Input is processed by a transformer (`BaseTransformer` → `MaskTransformer`), both `@MainActor`:

- `BaseTransformer` — a plain, unmasked field (character restrictions via `charValidator`);
- `MaskTransformer` — mask application, character veiling, display modes, dynamic masks.

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

Snapshot tests and UI tests live in the example app (`Example/MaskTextFieldExample`). The default
scheme runs all of its test targets, so select one:

```sh
# Snapshot tests (swift-snapshot-testing)
xcodebuild -project Example/MaskTextFieldExample/MaskTextFieldExample.xcodeproj \
  -scheme MaskTextFieldExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:MaskTextFieldFieldTests

# UI tests: real keyboard, taps and the UIKit editing cycle (about 2 minutes)
xcodebuild -project Example/MaskTextFieldExample/MaskTextFieldExample.xcodeproj \
  -scheme MaskTextFieldExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:MaskTextFieldUITests \
  -parallel-testing-enabled NO -disable-concurrent-destination-testing
```

The UI tests cover typing and completion, backspace, rejected overflow, the free / sequential /
snap-on-focus cursor behaviors and dynamic card masks. Run them with parallel testing disabled:
Xcode otherwise clones the simulator, which can stall for minutes.

CI (`.github/workflows/ci.yml`) runs the package tests on every push and pull request.
Pushing a version tag (`1.2.0`) triggers `.github/workflows/release.yml`, which creates a GitHub
Release with the matching `CHANGELOG.md` section (or generated notes if there is none).

Tests cover mask rendering, input/deletion, rejection of invalid characters,
display modes, character veiling on focus loss, and cursor positioning.
