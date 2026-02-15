import SwiftUI
import UIKit

/// Wraps UIActivityViewController for sharing CloudKit invitation links
/// via iMessage, WhatsApp, email, AirDrop, etc.
struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
