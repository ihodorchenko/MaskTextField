import Foundation

/// Оператор "конфигурации объекта": `object => { $0.property = value }`.
///
/// Возвращает тот же объект, что позволяет использовать его прямо в выражении.
precedencegroup ForwardApplication {
    associativity: left
    higherThan: AssignmentPrecedence
}

infix operator =>: ForwardApplication

@discardableResult
public func => <T>(_ object: T, _ transform: (inout T) throws -> Void) rethrows -> T {
    var object = object
    try transform(&object)
    return object
}
