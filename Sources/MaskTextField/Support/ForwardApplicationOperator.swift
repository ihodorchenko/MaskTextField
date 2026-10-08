import Foundation

/// The "object configuration" operator: `object => { $0.property = value }`.
///
/// Returns the same object, which allows using it right in an expression.
precedencegroup ForwardApplication {
    associativity: left
    higherThan: AssignmentPrecedence
}

infix operator =>: ForwardApplication

@discardableResult
func => <T>(_ object: T, _ transform: (inout T) throws -> Void) rethrows -> T {
    var object = object
    try transform(&object)
    return object
}
