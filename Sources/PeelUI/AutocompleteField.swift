import SwiftUI
import AppKit

/// SwiftUI wrapper around `NSComboBox` — a text field with an inline
/// dropdown chevron and type-to-filter completion. Apple's macOS HIG calls
/// this a "combo box"; SwiftUI doesn't have a native equivalent.
///
/// We use it for transaction-ID input so the user can pick a recently-used
/// ID from history without retyping a 16-digit number.
struct AutocompleteField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String?
    let suggestions: [String]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSComboBox {
        let combo = NSComboBox()
        combo.usesDataSource = false
        combo.completes = true
        combo.isButtonBordered = true
        combo.hasVerticalScroller = true
        combo.numberOfVisibleItems = 8
        combo.font = .systemFont(ofSize: NSFont.systemFontSize)
        combo.delegate = context.coordinator
        combo.target = context.coordinator
        combo.action = #selector(Coordinator.editingChanged(_:))
        combo.placeholderString = placeholder
        return combo
    }

    func updateNSView(_ combo: NSComboBox, context: Context) {
        context.coordinator.parent = self
        if combo.stringValue != text {
            combo.stringValue = text
        }
        // Only refresh the popup list if the suggestion set actually changed.
        let current = (0..<combo.numberOfItems).compactMap { combo.itemObjectValue(at: $0) as? String }
        if current != suggestions {
            combo.removeAllItems()
            combo.addItems(withObjectValues: suggestions)
        }
        combo.placeholderString = placeholder
    }

    /// `NSComboBox` only ever calls its delegate on the main thread, but
    /// `NSObject` subclasses aren't main-actor-isolated by default. We mark
    /// the coordinator `@MainActor` explicitly so it can mutate the
    /// `@Binding` parent (also main-actor) without Swift 6 complaining.
    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: AutocompleteField
        init(_ parent: AutocompleteField) { self.parent = parent }

        @objc func editingChanged(_ sender: NSComboBox) {
            parent.text = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            parent.text = combo.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            if let value = combo.objectValueOfSelectedItem as? String {
                parent.text = value
            }
        }
    }
}
