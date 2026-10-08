import XCTest
import SwiftUI
@testable import MaskTextField
import MaskTextFieldSwiftUI

/// Тесты SwiftUI-обёртки: `MaskedTextField` рендерится внутри `UIHostingController`
/// в реальном окне, поле достаётся из иерархии вью.
@MainActor
final class MaskedTextFieldTests: XCTestCase {

    private final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }

        var binding: Binding<Value> {
            Binding(get: { self.value }, set: { self.value = $0 })
        }
    }

    private var window: UIWindow!
    private var host: UIHostingController<MaskedTextField>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        #if targetEnvironment(macCatalyst)
        // Hosting SwiftUI needs a running application; the unhosted package test process on
        // Mac Catalyst has no NSApplication.
        throw XCTSkip("SwiftUI hosting tests need an application host on Mac Catalyst")
        #endif
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        host = nil
        super.tearDown()
    }

    // MARK: - Привязка значения

    func testInitialBindingValueIsRenderedWithMask() {
        let text = Box("291234567")

        let field = show(MaskedTextField(mask: "+375 (dd) ddd-dd-dd", textValue: text.binding))

        XCTAssertEqual(field.text, "+375 (29) 123-45-67")
        XCTAssertEqual(field.textValue, "291234567")
    }

    func testUserEditUpdatesBindingSynchronously() {
        let text = Box("")
        let field = show(MaskedTextField(mask: "dd-dd", textValue: text.binding))

        typeIntoField(field, "1")
        typeIntoField(field, "2")

        XCTAssertEqual(text.value, "12")
        XCTAssertEqual(field.text, "12-__")
    }

    func testExternalBindingChangeUpdatesField() {
        let text = Box("")
        let field = show(MaskedTextField(mask: "dd-dd", textValue: text.binding))

        text.value = "1234"
        update(MaskedTextField(mask: "dd-dd", textValue: text.binding))

        XCTAssertEqual(field.text, "12-34")
    }

    func testConfigurationChangesAreAppliedToExistingField() {
        let text = Box("")
        let field = show(MaskedTextField(mask: "dd", textValue: text.binding))

        update(MaskedTextField(
            mask: "ddd",
            cursorBehavior: .sequential,
            maskChar: "#",
            textAlignment: .center,
            forcesLeftToRight: false,
            textValue: text.binding
        ))

        XCTAssertEqual(field.visibleTextMask, "###")
        XCTAssertEqual(field.cursorBehavior, .sequential)
        XCTAssertEqual(field.textAlignment, .center)
        XCTAssertFalse(field.forcesLeftToRight)
    }

    func testMaskVariantsDriveDynamicMask() {
        let text = Box("")
        let field = show(MaskedTextField(
            maskVariants: [MaskVariant("dd"), MaskVariant("dd-dd")],
            textValue: text.binding
        ))
        XCTAssertEqual(field.text, "__")

        typeIntoField(field, "1")
        typeIntoField(field, "2")
        typeIntoField(field, "3")

        XCTAssertEqual(field.text, "12-3_")
        XCTAssertEqual(text.value, "123")
    }

    func testMaskProviderIsAppliedOnCreation() {
        let text = Box("")
        let field = show(MaskedTextField(maskProvider: MaskPreset.cardProvider, textValue: text.binding))

        typeIntoField(field, "3")
        typeIntoField(field, "7")

        XCTAssertEqual(field.text, "37__ ______ _____")
        XCTAssertEqual(text.value, "37")
    }

    // MARK: - Return, фокус

    func testReturnKeyCallsOnCommit() {
        var commits = 0
        let field = show(MaskedTextField(
            mask: "dd",
            onCommit: { commits += 1 },
            textValue: Box("").binding
        ))

        _ = field.delegate?.textFieldShouldReturn?(field)

        XCTAssertEqual(commits, 1)
    }

    func testFocusCallbacksUpdateIsFocusedBinding() {
        let focused = Box(false)
        let field = show(MaskedTextField(mask: "dd", isFocused: focused.binding, textValue: Box("").binding))

        field.delegate?.textFieldDidBeginEditing?(field)
        XCTAssertTrue(focused.value)

        field.delegate?.textFieldDidEndEditing?(field, reason: .committed)
        XCTAssertFalse(focused.value)
    }

    // MARK: - Заполненность

    func testOnCompleteAndIsCompleteBinding() {
        var completions = 0
        let complete = Box(false)
        let field = show(MaskedTextField(
            mask: "dd",
            isComplete: complete.binding,
            onComplete: { completions += 1 },
            textValue: Box("").binding
        ))

        typeIntoField(field, "1")
        XCTAssertFalse(complete.value)
        XCTAssertEqual(completions, 0)

        typeIntoField(field, "2")
        XCTAssertTrue(complete.value)
        XCTAssertEqual(completions, 1)
    }

    func testOnCompleteIsNotCalledForExternalValue() {
        var completions = 0
        let text = Box("")
        _ = show(MaskedTextField(mask: "dd", onComplete: { completions += 1 }, textValue: text.binding))

        text.value = "12"
        update(MaskedTextField(mask: "dd", onComplete: { completions += 1 }, textValue: text.binding))

        XCTAssertEqual(completions, 0)
    }

    // MARK: - Helpers

    @discardableResult
    private func show(_ view: MaskedTextField) -> MaskTextField {
        host = UIHostingController(rootView: view)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        return settledField()
    }

    private func update(_ view: MaskedTextField) {
        host.rootView = view
        _ = settledField()
    }

    /// Даёт SwiftUI провести layout и возвращает `MaskTextField` из иерархии.
    private func settledField(file: StaticString = #filePath, line: UInt = #line) -> MaskTextField {
        for _ in 0..<20 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))

            if let field = findField(in: host.view) { return field }
        }

        XCTFail("MaskTextField не найден в иерархии", file: file, line: line)
        return MaskTextField()
    }

    private func findField(in view: UIView) -> MaskTextField? {
        if let field = view as? MaskTextField { return field }
        for subview in view.subviews {
            if let field = findField(in: subview) { return field }
        }
        return nil
    }

    /// Ввод одного символа через делегат поля; уведомление об изменении шлёт `notification()`.
    private func typeIntoField(_ field: MaskTextField, _ string: String) {
        let location = field.cursorOffset
        _ = field.textField(
            field,
            shouldChangeCharactersIn: NSRange(location: location, length: 0),
            replacementString: string
        )
    }
}
