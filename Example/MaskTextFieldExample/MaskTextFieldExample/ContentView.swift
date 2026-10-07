//
//  ContentView.swift
//  MaskTextFieldExample
//

import SwiftUI
import MaskTextFieldSwiftUI

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

#Preview {
    ContentView()
}
