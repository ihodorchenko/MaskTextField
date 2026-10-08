# Accessibility, locale and RTL

Make masked fields work well with VoiceOver, Dynamic Type, other locales and right-to-left interfaces.

## Overview

### VoiceOver

``MaskTextField/accessibilityValue`` returns a meaningful value instead of the displayed mask:
"Empty" for an empty field, the entered characters without placeholders (`2 9 1 2 3`), and only
the count (`3 of 9 characters entered`) when characters are hidden (``MaskTextField/hideChars``,
or `^` positions while unfocused). Set it yourself to override. Use the standard
`accessibilityLabel` and `accessibilityHint` for the label and the expected format.

Turn on ``MaskTextField/announcesInputEvents`` to have VoiceOver announce rejected characters
and a completed mask.

### Dynamic Type

The default font is the body text style with automatic content-size adjustment. A custom font
must scale itself.

### Locale

``MaskTextField/locale`` drives decimal and grouping separators when no validator supplies its
own. Masks never depend on the locale: the format is literal.

### Right-to-left

``MaskTextField/forcesLeftToRight`` (default `true`) keeps masked values left to right in
right-to-left interfaces; with `.natural` alignment the text is right-aligned there. Set it to
`false` for a fully mirrored layout. The clear button always sits at the end of the line.

Library strings are localized in English and Russian.
