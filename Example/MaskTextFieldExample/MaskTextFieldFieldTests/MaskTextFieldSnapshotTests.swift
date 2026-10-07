//
//  MaskTextFieldSnapshotTests.swift
//  MaskTextFieldFieldTests
//

import XCTest
import SnapshotTesting
import MaskTextField

/// Snapshot-тесты визуальных аспектов `MaskTextField`: отступы текста
/// (`textContainerInset`) и clear-кнопка.
///
/// Эталонные изображения лежат в `__Snapshots__/`. При первом запуске они
/// записываются автоматически; при изменении рендеринга — тест упадёт, и
/// нужно будет обновить эталон через `SNAPSHOT_TESTING_RECORD=1`.
final class MaskTextFieldSnapshotTests: XCTestCase {

    func testSnapshotWithoutInset() {
        assertSnapshot(of: makeField(), as: .image)
    }

    func testSnapshotWithTextContainerInset() {
        let field = makeField()
        field.textContainerInset = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        field.layoutIfNeeded()

        assertSnapshot(of: field, as: .image)
    }

    func testSnapshotClearButtonColor() {
        let field = makeField()
        field.clearButtonMode = .always
        field.layoutIfNeeded()

        // Кнопка создаётся при layout; цвет применяется после её появления.
        field.clearButtonColor = .systemRed
        field.layoutIfNeeded()

        assertSnapshot(of: field, as: .image)
    }

    // MARK: - Helpers

    /// Детерминированное поле с маской телефона и заполненным значением.
    private func makeField() -> MaskTextField {
        let field = MaskTextField()
        field.maskText = "+375 (dd) ddd-dd-dd"
        field.textValue = "291234567"
        field.backgroundColor = .white
        field.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        field.layoutIfNeeded()
        return field
    }
}
