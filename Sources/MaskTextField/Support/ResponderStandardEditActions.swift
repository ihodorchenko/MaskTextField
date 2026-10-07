import UIKit

/// Стандартные действия редактирования, которые можно разрешить или запретить
/// в контекстном меню текстового поля через `MaskTextField.setEditActions(only:)`,
/// `addToCurrentEditActions(actions:)` и `filterEditActions(notAllowed:)`.
public enum ResponderStandardEditActions: Hashable {
    case cut
    case copy
    case paste
    case select
    case selectAll
    case delete
    case makeTextWritingDirectionLeftToRight
    case makeTextWritingDirectionRightToLeft
    case toggleBoldface
    case toggleItalics
    case toggleUnderline
    case increaseSize
    case decreaseSize

    public var selector: Selector {
        switch self {
        case .cut:
            return #selector(UIResponderStandardEditActions.cut(_:))
        case .copy:
            return #selector(UIResponderStandardEditActions.copy(_:))
        case .paste:
            return #selector(UIResponderStandardEditActions.paste(_:))
        case .select:
            return #selector(UIResponderStandardEditActions.select(_:))
        case .selectAll:
            return #selector(UIResponderStandardEditActions.selectAll(_:))
        case .delete:
            return #selector(UIResponderStandardEditActions.delete(_:))
        case .makeTextWritingDirectionLeftToRight:
            return #selector(UIResponderStandardEditActions.makeTextWritingDirectionLeftToRight(_:))
        case .makeTextWritingDirectionRightToLeft:
            return #selector(UIResponderStandardEditActions.makeTextWritingDirectionRightToLeft(_:))
        case .toggleBoldface:
            return #selector(UIResponderStandardEditActions.toggleBoldface(_:))
        case .toggleItalics:
            return #selector(UIResponderStandardEditActions.toggleItalics(_:))
        case .toggleUnderline:
            return #selector(UIResponderStandardEditActions.toggleUnderline(_:))
        case .increaseSize:
            return #selector(UIResponderStandardEditActions.increaseSize(_:))
        case .decreaseSize:
            return #selector(UIResponderStandardEditActions.decreaseSize(_:))
        }
    }
}
