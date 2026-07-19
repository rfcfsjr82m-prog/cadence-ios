import SwiftUI
import UIKit

// MARK: - Dismiss keyboard when tapping outside a text field
//
// Installs a UITapGestureRecognizer on the key UIWindow so it intercepts
// taps anywhere on screen. cancelsTouchesInView = false + simultaneous
// recognition ensures buttons and other controls still fire normally.

extension View {
    /// Tapping anywhere on screen dismisses the keyboard without blocking
    /// buttons or other interactive controls.
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller())
    }
}

// UIViewRepresentable that installs/removes a window-level tap recognizer.
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false   // let touches pass through this view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Install on the window the first time we have one
        context.coordinator.install(in: uiView)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        func install(in view: UIView) {
            guard recognizer == nil else { return }
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let window = view?.window, self.window == nil else { return }
                self.window = window
                let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
                tap.cancelsTouchesInView = false    // buttons etc. still fire
                tap.delegate             = self
                window.addGestureRecognizer(tap)
                self.recognizer = tap
            }
        }

        deinit {
            if let recognizer, let window {
                let r = recognizer
                let w = window
                DispatchQueue.main.async {
                    w.removeGestureRecognizer(r)
                }
            }
        }

        @objc private func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil)
        }

        // Allow our recognizer to fire at the same time as every other recognizer
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        // Don't require other recognizers to fail first
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf other: UIGestureRecognizer
        ) -> Bool { false }
    }
}
