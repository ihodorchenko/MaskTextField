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

The underlying UIKit field, its mask syntax, dynamic masks and validators are documented in the
`MaskTextField` module.

## Topics

### Views

- ``MaskedTextField``
