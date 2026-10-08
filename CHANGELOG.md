# Changelog

## Unreleased

### Added
- `CursorBehavior.snapOnFocus`: on focus the cursor snaps to the first free position, then
  can be moved freely. Verified on the iOS simulator with real taps.
- `charValidator` now works: it restricts typed, pasted and programmatic input in plain
  fields and acts as an extra restriction in masked fields. Built-in validators:
  `EmojiFreeValidator`, `AllowedCharactersValidator`, `MaxLengthValidator`,
  `CompositeValidator`; `Character.isEmojiCharacter` detects emoji clusters as a whole.
- All `CharValidator` methods have default implementations.

### Changed
- `charValidator` is held by a strong reference (it was `weak`, so an inline assignment
  was released immediately).
- Plain (unmasked) fields no longer re-implement typing: edits are native unless a
  validator is set and changes the input. Typing and deleting in the middle of a plain
  field now works at the cursor instead of appending/removing at the end.

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
