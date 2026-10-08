//
//  ContentView.swift
//  MaskTextFieldExample
//

import SwiftUI
import MaskTextField
import MaskTextFieldSwiftUI

struct ContentView: View {
    @State private var phone = ""
    @State private var phoneComplete = false
    @State private var date = ""
    @State private var freeCard = ""
    @State private var sequentialCard = ""
    @State private var snapCard = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MaskedTextField(
                        mask: "+375 (dd) ddd-dd-dd",
                        maskLostFocus: "+375 (^d^d) ^d^d^d-^d^d-^d^d",
                        placeholder: "+375 (__) ___-__-__",
                        keyboardType: .numberPad,
                        isComplete: $phoneComplete,
                        textValue: $phone
                    )
                    LabeledContent("Значение без маски") {
                        Text(phone.isEmpty ? "—" : phone)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Маска заполнена") {
                        Text(phoneComplete ? "да" : "нет")
                            .foregroundStyle(phoneComplete ? .green : .secondary)
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

                Section {
                    MaskedTextField(
                        mask: "dddd dddd dddd dddd",
                        cursorBehavior: .free,
                        placeholder: "0000 0000 0000 0000",
                        keyboardType: .numberPad,
                        clearButtonMode: .whileEditing,
                        textValue: $freeCard
                    )
                    LabeledContent("Значение без маски") {
                        Text(freeCard.isEmpty ? "—" : freeCard)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Курсор: free")
                } footer: {
                    Text("Курсор можно поставить в любое место; ввод и удаление происходят в позиции курсора.")
                }

                Section {
                    MaskedTextField(
                        mask: "dddd dddd dddd dddd",
                        cursorBehavior: .snapOnFocus,
                        placeholder: "0000 0000 0000 0000",
                        keyboardType: .numberPad,
                        clearButtonMode: .whileEditing,
                        textValue: $snapCard
                    )
                    LabeledContent("Значение без маски") {
                        Text(snapCard.isEmpty ? "—" : snapCard)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Курсор: snapOnFocus")
                } footer: {
                    Text("При фокусе курсор встаёт на первую свободную позицию, затем его можно переставить.")
                }

                Section {
                    MaskedTextField(
                        mask: "dddd dddd dddd dddd",
                        cursorBehavior: .sequential,
                        placeholder: "0000 0000 0000 0000",
                        keyboardType: .numberPad,
                        clearButtonMode: .whileEditing,
                        textValue: $sequentialCard
                    )
                    LabeledContent("Значение без маски") {
                        Text(sequentialCard.isEmpty ? "—" : sequentialCard)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Курсор: sequential")
                } footer: {
                    Text("Курсор всегда на первой свободной позиции: ввод и стирание только последовательные, переставить курсор нельзя.")
                }
            }
            .navigationTitle("MaskTextField")
        }
    }
}

#Preview {
    ContentView()
}
