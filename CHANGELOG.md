# Changelog

## Unreleased

### Added
- Dynamic masks: `maskProvider` (raw value -> `MaskVariant`) and `maskVariants` (by capacity).
  The mask is re-picked after every edit and the value is re-laid out on it; input that fits
  no mask is rejected. SwiftUI: `MaskedTextField(maskVariants:)` and `maskProvider:`.
- `MaskPreset`: `card16`, `cardAmex`, `dateDMY`, `timeHM`, `otp(length:)` and `cardProvider`.
- `MaskConfiguration` with `MaskTextField.apply(_:)`, `configure { }` and `configuration`:
  atomic, order-independent configuration.

## 1.2.0

### Added
- `charValidator` now works: it restricts typed, pasted and programmatic input in plain
  fields and acts as an extra restriction in masked fields. Built-in validators:
  `EmojiFreeValidator`, `AllowedCharactersValidator`, `MaxLengthValidator`,
  `CompositeValidator`; `Character.isEmojiCharacter` detects emoji clusters as a whole.
  All `CharValidator` methods have default implementations.
- `isComplete`, `isCompletePublisher` and `onComplete`: the mask is filled. `onComplete`
  fires once when the user fills the mask and not for programmatic values; SwiftUI
  `MaskedTextField` gets `isComplete: Binding<Bool>?` and `onComplete`.
- `CursorBehavior.snapOnFocus`: on focus the cursor snaps to the first free position, then
  can be moved freely.
- `disablesAutocorrection` (also on `MaskedTextField`).
- SwiftUI wrapper test coverage (binding in both directions, focus, Return, completion,
  configuration updates).
- Release workflow: pushing a version tag creates a GitHub Release from this changelog.

### Changed
- Masked fields now disable autocorrection, spell checking and smart quotes/dashes/insert-delete
  by default (`disablesAutocorrection`). Explicitly set traits win; set
  `disablesAutocorrection = false` to restore the old behavior.
- In `.free` (and `.snapOnFocus`) typing at a cursor with no free position to its right now
  fills the first free position on the left, so a mask can be completed by typing at the
  end. Before, such input was rejected.
- `charValidator` is held by a strong reference (it was `weak`, so an inline assignment
  was released immediately).
- Plain (unmasked) fields no longer re-implement typing: edits are native unless a
  validator is set and changes the input. Typing and deleting in the middle of a plain
  field now works at the cursor instead of appending/removing at the end.
- `MaskedTextField` observes `textDidChangeNotification` instead of the control's
  `.editingChanged` target-action, so the binding no longer depends on UIControl event
  delivery (which does not work without a running `UIApplication`).

## 1.1.1

### Fixed
- In password mode (`hideChars`) the cursor no longer jumps to the first free position when
  the hide timer fires after the user moved it (`.free` mode).

### Added
- `deleteBackwardEvents` and `clearButtonEvents`: real event publishers. The existing
  `@Published` properties `deleteBackwardPublisher` / `clearButtonPublisher` emit
  immediately on subscription, which is kept for compatibility but documented.

## 1.1.0

### Added
- `cursorBehavior` (`.free` / `.sequential`): strictly sequential input with a cursor
  pinned to the first free position.
- Accessibility: meaningful `accessibilityValue` (empty / entered characters / count
  when hidden), optional `announcesInputEvents`, labelled clear button, Dynamic Type.
- `locale` for decimal and grouping separators; `forcesLeftToRight` for RTL interfaces;
  the clear button follows the layout direction.
- Range-based editing: pasting into the middle keeps the surrounding value, typing,
  pasting and deleting over a selection replace only the selection.
- `MaskedTextField` (SwiftUI): `font`, `textColor`, `textAlignment`, `returnKeyType`,
  `clearButtonMode`, `isFocused`, `onCommit`, `cursorBehavior`, `forcesLeftToRight`,
  `locale`, `announcesInputEvents`, `accessibilityLabelText`, `accessibilityHintText`.
- English and Russian localization of library strings; CI workflow.

### Changed
- Mask characters are validated by direct ASCII checks instead of regular expressions.
- `x` is now any visible ASCII character except a digit, `X` any visible ASCII
  character including digits (the sets are wider than before: `,`, `'`, `"`, `[`, `]`,
  `\`, `` ` ``, `~` are accepted).
- `MaskTextField` fires `.editingChanged` when the clear button is tapped.
- `MaskedTextField` syncs its binding via `.editingChanged` instead of async selection callbacks.
- `MaskTransformer` is now `final`.
- UIKit field tests moved from the example app into the package tests.
