# Getting started

Add the package, create a field, set a mask.

## Overview

### Installation

Add the package in Xcode (**File ▸ Add Package Dependencies…**) or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ihodorchenko/MaskTextField.git", from: "1.4.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        "MaskTextField",
        "MaskTextFieldSwiftUI"   // optional: the SwiftUI wrapper
    ])
]
```

Requires iOS 15.0+ and Swift 5.9+; built and tested with Xcode 27. The library builds without
warnings under Swift 6 strict concurrency.

### A masked field

```swift
let field = MaskTextField()
field.maskText = "dd/dd/dddd"
field.keyboardType = .numberPad
```

Read and write the value without the mask through ``MaskTextField/textValue``. Observe changes
with ``MaskTextField/textPublisher``, and use ``MaskTextField/isComplete`` /
``MaskTextField/onComplete`` to react when the mask is filled.

### SwiftUI

```swift
import MaskTextFieldSwiftUI

@State private var phone = ""

MaskedTextField(
    mask: "+375 (dd) ddd-dd-dd",
    keyboardType: .numberPad,
    textValue: $phone
)
```

### Changing many settings at once

Properties apply one by one, so assignment order matters. Use ``MaskConfiguration`` to apply
everything atomically:

```swift
field.configure {
    $0.mask = "dd/dd/dddd"
    $0.maskChar = "#"
    $0.cursorBehavior = .sequential
}
```
