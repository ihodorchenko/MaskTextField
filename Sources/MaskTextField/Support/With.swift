import Foundation

/// Конфигурация объекта: `with(object) { $0.property = value }`.
///
/// Возвращает тот же объект, что позволяет использовать его прямо в выражении.
@discardableResult
func with<T>(_ object: T, _ configure: (inout T) throws -> Void) rethrows -> T {
    var object = object
    try configure(&object)
    return object
}
