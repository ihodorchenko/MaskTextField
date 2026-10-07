# Задачи (бэклог рефакторинга)

Нумерация продолжает историю issue/PR (#1–#17). Стиль: одно атомарное
изменение на задачу, коммит `"Summary (#N)"` + merge `"Merge improvement #N"`.

## Блокирующие баги

- [x] **#18 — `CharInfo.init` игнорирует `masChar`.** `_maskChar` присваивается
  `char` вместо переданного `masChar`; параметр (и имя `masChar`) мёртвые.
  Файл: `Transformer/MaskTransformer.swift`.

- [x] **#19 — внешний делегат не может запретить ввод.** Возврат из
  `externalDelegate.textField(_:shouldChangeCharactersIn:...)` игнорируется.
  Файл: `TextField/MaskTextFieldWithDelegate.swift`.

- [x] **#20 — `resetEditActions()` чистит только `editActions`.** `filterEditActions`
  остаётся активным — асимметрия. Файл: `TextField/MaskTextField.swift`.

- [x] **#21 — `deleteBackward()` обходит трансформер.** Дёргает `super` и шлёт
  событие в обход маски; рассинхрон с `_maskInfo`. Теперь удаление идёт через
  трансформер + `notification()`. Файл: `TextField/MaskTextField.swift`,
  `TextField/MaskTextFieldWithDelegate.swift`.

## Логика / UX

- [x] **#22 — курсор отскакивает на первую пустую позицию.** `onSelectionChanged()`
  вызывает `setTextAndCursor()` без позиции. Теперь позиция читается из протокола
  (`cursorOffset`) и сохраняется. Файл: `Transformer/MaskTransformer.swift`,
  `Interface/MaskTextFieldProtocol.swift`.

- [x] **#23 — риск рекурсии курсора.** `textFieldDidChangeSelection` →
  `onSelectionChanged` → `setTextAndCursor` → `setCursorPosition` → … Добавлен
  guard `isRendering`. Файл: `Transformer/MaskTransformer.swift`.

- [x] **#24 — хрупкая переустановка свойств.** `maskText = ""` сбрасывает
  `_transformer` в `BaseTransformer`, теряя настройки. Добавлен `makeMaskTransformer()`
  с полным набором настроек. Файл: `TextField/MaskTextField.swift`.

## App Store / совместимость

- [x] **#25 — приватный `_clearButton` через KVC.** Заменён собственной clear-кнопкой
  через `rightView` (`clearButtonMode` переопределён, `clearButtonColor` красит её).
  Файл: `TextField/MaskTextField.swift`. Snapshot перегенерирован.

- [x] **#26 — `public extension String` засоряет API.** Краш-склонный `subscript`
  и хелперы глобально публичны. Сделать `internal`. Файл: `Support/String+Extensions.swift`.

## Мелочи и стиль

- [x] **#27 — дублирующийся `textFieldDidEndEditing`.** Deprecated-версия (2 арг.)
  удалена; осталась только `reason:`-версия. Файл: `TextField/MaskTextFieldWithDelegate.swift`.

- [x] **#28 — магическая задержка событий.** `asyncAfter(0.01)` убрана — события
  шлются синхронно. Файл: `TextField/MaskTextFieldWithDelegate.swift`.

- [x] **#29 — `NumberFormatter` пересоздаётся на каждый вызов `culture`.** Заменён
  ленивым `defaultCulture`. Файлы: `TextField/MaskTextField.swift`,
  `TextField/MaskTextFieldWithProtocol.swift`.

- [x] **#30 — геометрия `textContainerInset` вычитается дважды.** Убрана двойная
  вычитка — теперь просто `super.textRect(...).inset(by:)`. Файл: `TextField/MaskTextField.swift`.

- [x] **#31 — неконсистентное имя автора.** App-файл приведён к `Ihar Khadorchanka`
  (как в LICENSE). Файл: `MaskTextFieldExampleApp.swift`.

- [x] **#32 — дефолт `veiledMaskChar`.** Был `CharInfo.nilChar` (`"\0"`) — теперь
  `MaskTransformer.hideChar`. Файл: `Transformer/MaskTransformer.swift`.

- [x] **#33 — `=>` оператор не `public` и с родовым именем.** Без изменений: оператор
  `internal`, поэтому не экспортируется потребителям и коллизии быть не может.
  (В истории уже было: замена на `with(_:)` откачена в пользу internal `=>`.)

- [x] **#34 — `Timer` в режиме `.default`.** Таймер скрытия добавлен в `.common`,
  срабатывает и во время скролла. Файл: `Transformer/MaskTransformer.swift`.

- [x] **#35 — `MaskedTextField.swift` не импортирует `UIKit` явно.** Добавлен
  `import UIKit`. Файл: `MaskTextFieldSwiftUI/MaskedTextField.swift`.

## Тесты (покрыть)

- [ ] **#36 — добавить тесты** на #19 (veto), #20 (reset), #24 (порядок свойств),
  вставку с невалидными символами, отмену `hideChars`-таймера при смене маски.
