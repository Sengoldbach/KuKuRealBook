import SwiftUI
import UIKit

/// Bridges a SwiftUI view in as a genuine custom iOS keyboard (`UITextField.inputView`)
/// instead of a manually-positioned bottom bar — same slide up/down animation,
/// timing curve, and interactive-dismiss gesture as the system keyboard, all
/// driven by first-responder status exactly like a real keyboard.
///
/// SwiftUI has no direct `inputView` API, so this hosts an invisible,
/// zero-size `UITextField` whose `inputView` is a `UIHostingController`
/// wrapping the real chord-keyboard content. Toggling `isActive` calls
/// `becomeFirstResponder()` / `resignFirstResponder()`, which is what
/// actually triggers the keyboard to appear/disappear.
struct ChordKeyboardHost<Content: View>: UIViewRepresentable {
    @Binding var isActive: Bool
    var height: CGFloat = 250
    @ViewBuilder var content: () -> Content

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.alpha = 0
        field.autocorrectionType = .no
        field.delegate = context.coordinator

        let hosting = UIHostingController(rootView: content())
        hosting.view.backgroundColor = .clear
        hosting.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height)
        hosting.view.autoresizingMask = [.flexibleWidth]
        field.inputView = hosting.view

        context.coordinator.hostingController = hosting
        context.coordinator.onResignExternally = { isActive = false }
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.hostingController?.rootView = content()
        if isActive, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isActive, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var hostingController: UIHostingController<Content>?
        var onResignExternally: (() -> Void)?

        func textFieldDidEndEditing(_ textField: UITextField) {
            onResignExternally?()
        }
    }
}
