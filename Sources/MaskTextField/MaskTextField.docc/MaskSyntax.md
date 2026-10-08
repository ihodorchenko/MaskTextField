# Mask syntax

A mask is a string in which special characters define editable positions and all other
characters are printed as literals.

## Overview

### Special characters

| Character | Meaning | Accepts |
|-----------|---------|---------|
| `d` | digit | `0-9` |
| `a` | Latin letter | `a-zA-Z` |
| `A` | Latin letter or digit | `a-zA-Z0-9` |
| `x` | any visible ASCII character except a digit | letters, punctuation, symbols |
| `X` | any visible ASCII character, digits included | letters, digits, punctuation |
| `z` | any character | no validation |
| `\c` | escaped literal (even if `c` is special) | — |
| `^c` | editable position veiled on focus loss | as `c` |

### Examples

| Mask | Input | Display |
|------|-------|---------|
| `+375 (dd) ddd-dd-dd` | `291234567` | `+375 (29) 123-45-67` |
| `dd/dd/dddd` | `07102026` | `07/10/2026` |
| `dddd dddd dddd dddd` | `4111111111111111` | `4111 1111 1111 1111` |
| `\dA` | `X7` | `d7` (`\d` is a literal `d`) |

A mask defines only a format, never validity: `dd/dd/dddd` accepts `99/99/9999`.

### Veiling on focus loss

Mark positions with `^` and set ``MaskTextField/maskLostFocus`` to show a different mask
(typically with the digits veiled) when the field is not focused:

```swift
field.maskText = "+375 (dd) ddd-dd-dd"
field.maskLostFocus = "+375 (^d^d) ^d^d^d-^d^d-^d^d"
// editing:    +375 (29) 123-45-67
// unfocused:  +375 (••) •••-••-••
```

``MaskTextField/hideChars`` provides a password-style mode instead: an entered character is
veiled after a short delay. It hides characters on screen only; it is not secure text entry.
