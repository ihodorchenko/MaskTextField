import Foundation

/// Локализованные строки библиотеки (VoiceOver-описания и подписи).
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func enteredCount(_ entered: Int, of total: Int) -> String {
        String(format: string("a11y.entered_count"), entered, total)
    }
}
