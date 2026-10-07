//
//  ContentView.swift
//  MaskTextFieldExample
//

import SwiftUI
import MaskTextField

struct ContentView: View {
    @State private var phone = ""
    @State private var date = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MaskedTextField(
                        mask: "+375 (dd) ddd-dd-dd",
                        maskLostFocus: "+375 (^d^d) ^d^d^d-^d^d-^d^d",
                        placeholder: "+375 (__) ___-__-__",
                        keyboardType: .numberPad,
                        textValue: $phone
                    )
                    LabeledContent("Значение без маски") {
                        Text(phone.isEmpty ? "—" : phone)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Телефон")
                } footer: {
                    Text("При потере фокуса введённые цифры скрываются символом •.")
                }

                Section {
                    MaskedTextField(
                        mask: "dd/dd/dddd",
                        placeholder: "дд/мм/гггг",
                        keyboardType: .numberPad,
                        textValue: $date
                    )
                    LabeledContent("Значение без маски") {
                        Text(date.isEmpty ? "—" : date)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Дата")
                }
            }
            .navigationTitle("MaskTextField")
        }
    }
}

/// Обёртка над `ICMaskTextField` для использования в SwiftUI.
private struct MaskedTextField: UIViewRepresentable {
    var mask: String
    var maskLostFocus: String = ""
    var maskMode: ICMaskMode = .fullMask
    var maskChar: Character = "_"
    var veiledMaskChar: Character = "•"
    var hideChars: Bool = false
    var placeholder: String? = nil
    var keyboardType: UIKeyboardType = .default

    @Binding var textValue: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ICMaskTextField {
        let field = ICMaskTextField()
        apply(to: field)
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return field
    }

    func updateUIView(_ field: ICMaskTextField, context: Context) {
        apply(to: field)

        // Пишем обратно только при реальном расхождении, чтобы не зациклить обновления.
        if field.textValue != textValue {
            field.textValue = textValue
        }
    }

    private func apply(to field: ICMaskTextField) {
        field.maskText = mask
        field.maskLostFocus = maskLostFocus
        field.maskMode = maskMode
        field.maskChar = maskChar
        field.veiledMaskChar = veiledMaskChar
        field.hideChars = hideChars
        field.placeholder = placeholder
        field.keyboardType = keyboardType
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaskedTextField

        init(_ parent: MaskedTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            guard let field = textField as? ICMaskTextField else { return }
            let value = field.textValue ?? ""
            if parent.textValue != value {
                DispatchQueue.main.async {
                    self.parent.textValue = value
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
