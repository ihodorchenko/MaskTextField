import Foundation

public extension DispatchSemaphore {
    /// Выполняет `block` под семафором: захватывает ресурс, выполняет блок
    /// и гарантированно отпускает ресурс даже в случае ошибки.
    func with<T>(_ block: () throws -> T) rethrows -> T {
        self.wait()
        defer { self.signal() }
        return try block()
    }
}
