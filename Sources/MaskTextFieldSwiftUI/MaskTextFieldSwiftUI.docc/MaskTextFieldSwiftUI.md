# ``MaskTextFieldSwiftUI``

A SwiftUI wrapper around `MaskTextField`.

## Overview

``MaskedTextField`` lets you use masked input in SwiftUI without writing a
`UIViewRepresentable`. The raw value without the mask is bound to SwiftUI state through the
`textValue` binding.

```swift
import SwiftUI
import MaskTextFieldSwiftUI

struct PhoneView: View {
    @State private var phone = ""
    @State private var isComplete = false

    var body: some View {
        MaskedTextField(
            mask: "+375 (dd) ddd-dd-dd",
            maskLostFocus: "+375 (^d^d) ^d^d^d-^d^d-^d^d",
            keyboardType: .numberPad,
            isComplete: $isComplete,
            textValue: $phone
        )
    }
}
```

### Field options

Beyond the mask settings, ``MaskedTextField`` exposes `charValidator`, `textContentType`,
`clearButtonColor`, `textContainerInset`, `font`, `textColor`, `textAlignment` and the accessibility
labels. Accessory views are passed as `leftView` / `rightView` (with `leftViewMode` /
`rightViewMode`); a custom `rightView`, for example a "show password" button, takes the place of the
built-in clear button.

The underlying UIKit field, its mask syntax, dynamic masks and validators are documented in the
`MaskTextField` module.

## Topics

### Views

- ``MaskedTextField``
