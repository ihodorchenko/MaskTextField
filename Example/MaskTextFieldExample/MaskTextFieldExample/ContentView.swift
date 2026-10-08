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
    @State private var dynamicCard = ""

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
                    .accessibilityIdentifier("phone")
                    LabeledContent("Значение без маски") {
                        Text(phone.isEmpty ? "—" : phone)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("phoneValue")
                    }
                    LabeledContent("Маска заполнена") {
                        Text(phoneComplete ? "да" : "нет")
                            .foregroundStyle(phoneComplete ? .green : .secondary)
                            .accessibilityIdentifier("phoneComplete")
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
                    .accessibilityIdentifier("date")
                    LabeledContent("Значение без маски") {
                        Text(date.isEmpty ? "—" : date)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("dateValue")
                    }
                } header: {
                    Text("Дата")
                }

                Section {
                    MaskedTextField(
                        maskProvider: MaskPreset.cardProvider,
                        placeholder: "0000 0000 0000 0000",
                        keyboardType: .numberPad,
                        textValue: $dynamicCard
                    )
                    .accessibilityIdentifier("dynamicCard")
                    LabeledContent("Значение без маски") {
                        Text(dynamicCard.isEmpty ? "—" : dynamicCard)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("dynamicCardValue")
                    }
                } header: {
                    Text("Динамическая маска")
                } footer: {
                    Text("Маска выбирается по значению: карта, начинающаяся с 34 или 37 (Amex), — 15 цифр, остальные — 16.")
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
                    .accessibilityIdentifier("freeCard")
                    LabeledContent("Значение без маски") {
                        Text(freeCard.isEmpty ? "—" : freeCard)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("freeCardValue")
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
                    .accessibilityIdentifier("snapCard")
                    LabeledContent("Значение без маски") {
                        Text(snapCard.isEmpty ? "—" : snapCard)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("snapCardValue")
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
                    .accessibilityIdentifier("sequentialCard")
                    LabeledContent("Значение без маски") {
                        Text(sequentialCard.isEmpty ? "—" : sequentialCard)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("sequentialCardValue")
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
